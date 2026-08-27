import AVFoundation
import CoreMedia
import CoreVideo
import UIKit
import os

/// Owns the AVCaptureSession and hands out one pixel buffer every
/// `config.frameInterval` seconds.
///
/// Battery strategy, in order of impact:
///  1. Pin the camera to its slowest supported frame rate (usually 1 fps) so the
///     sensor and ISP are barely working. This is the big win.
///  2. Decimate what is left in the delegate to reach the 4 s interval.
///  3. `alwaysDiscardsLateVideoFrames` so the buffer pool never backs up.
///
/// We do NOT stop/start the session between frames: `startRunning()` costs
/// ~0.5 s and a power spike each time, which is worse than idling at 1 fps.
///
/// `@unchecked Sendable`: AVFoundation is not actor-aware, so this class hand-rolls
/// its isolation by confining all mutable state to `captureQueue`.
final class CaptureController: NSObject, @unchecked Sendable {

    private let config: CaptureConfiguration
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let log = Logger(subsystem: "app.studylapse", category: "capture")

    /// The one serial queue everything downstream of the camera runs on: the
    /// sample-buffer delegate AND the asset writer. One queue means no locks and
    /// no chance of appending to a writer that is being torn down.
    let captureQueue = DispatchQueue(label: "app.studylapse.capture", qos: .userInitiated)

    /// Handed to the SwiftUI preview layer so the user can frame the shot.
    var previewSession: AVCaptureSession { session }

    /// Called on `captureQueue` for every frame we decide to keep. The buffer is
    /// only valid for the duration of this call.
    var onFrame: ((CVPixelBuffer) -> Void)?
    /// Called on the main queue when the camera is taken away / handed back.
    var onInterrupted: ((LapseInterruption) -> Void)?
    var onResumed: (() -> Void)?
    /// Fires on the main queue when the very first buffer lands, i.e. when the
    /// preview actually has something to show. Everything before this is a black
    /// rectangle, so the UI waits for it rather than looking frozen.
    var onFirstFrame: (() -> Void)?

    private var device: AVCaptureDevice?
    /// Sensor rate follows whether anyone is actually looking at the preview.
    private var rateMode: FrameRateMode = .smoothPreview

    enum FrameRateMode {
        /// ~30 fps. Used whenever the preview is on screen. Costs battery, but a
        /// lit display already dwarfs the sensor, so it is free in practice.
        case smoothPreview
        /// Slowest rate the format allows (~1 fps). Used once the screen dims.
        case lowPower
    }
    private var lastKeptTimestamp: CMTime?
    private var sawFirstFrame = false
    private var startedConfiguringAt = CFAbsoluteTimeGetCurrent()
    private var observers: [NSObjectProtocol] = []

    /// Dimensions the encoder should expect, AFTER rotation. Portrait capture
    /// yields 720x1280, landscape 1280x720.
    private(set) var outputDimensions = CGSize(width: 1280, height: 720)

    /// Kept alive for the life of the session; it publishes the correct rotation
    /// angle for the current physical device orientation.
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?

    init(config: CaptureConfiguration) {
        self.config = config
        super.init()
    }

    // MARK: - Permission

    static var authorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    /// Returns false for both "user said no" and "user has never been asked and
    /// said no just now". The caller distinguishes via `authorizationStatus`.
    static func requestAccess() async -> Bool {
        switch authorizationStatus {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    // MARK: - Lifecycle

    func configure(interfaceOrientation: UIInterfaceOrientation) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            captureQueue.async {
                do {
                    self.startedConfiguringAt = CFAbsoluteTimeGetCurrent()
                    Trace.mark("configureLocked() start")
                    try self.configureLocked()
                    self.log.info("configure took \(CFAbsoluteTimeGetCurrent() - self.startedConfiguringAt, format: .fixed(precision: 3))s")
                    // Start inside the same queue block: one hop instead of two,
                    // and startRunning is the slow part so it should begin ASAP.
                    Trace.mark("configureLocked() done -> startRunning()")
                    self.session.startRunning()
                    Trace.mark("startRunning() returned")
                    self.applySensorRate()
                    Trace.mark("applySensorRate() done")
                    self.log.info("startRunning done at \(CFAbsoluteTimeGetCurrent() - self.startedConfiguringAt, format: .fixed(precision: 3))s")
                    c.resume()
                } catch {
                    c.resume(throwing: error)
                }
            }
        }
    }

    private func configureLocked() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        Trace.mark("  setting preset")
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: config.cameraPosition
        ) ?? AVCaptureDevice.default(for: .video) else {
            throw CaptureError.noCameraAvailable
        }
        self.device = device

        Trace.mark("  got device, creating input")
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw CaptureError.configurationFailed("camera input rejected")
        }
        session.addInput(input)

        Trace.mark("  input added, adding output")
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        guard session.canAddOutput(videoOutput) else {
            throw CaptureError.configurationFailed("video output rejected")
        }
        session.addOutput(videoOutput)

        // Rotate the buffers themselves rather than tagging the track with a
        // transform. Deriving that transform by hand is where the "upside down on
        // playback" bug came from: the mapping has to account for the sensor's
        // native orientation AND front-camera mirroring, and the two interact.
        //
        // RotationCoordinator exists to answer exactly this question, so let it.
        // At one frame every four seconds the rotation cost is irrelevant.
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        rotationCoordinator = coordinator

        if let connection = videoOutput.connection(with: .video) {
            let angle = coordinator.videoRotationAngleForHorizonLevelCapture
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            // Mirroring a front-camera lapse looks natural, like a selfie.
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = (config.cameraPosition == .front)
            }

            // A 90 or 270 degree rotation swaps the buffer's width and height, and
            // the encoder must be told the post-rotation size or every frame is
            // rejected.
            let rotated = angle == 90 || angle == 270
            outputDimensions = rotated
                ? CGSize(width: config.height, height: config.width)
                : CGSize(width: config.width, height: config.height)
            log.info("rotation \(angle, format: .fixed(precision: 0))deg, output \(self.outputDimensions.width, format: .fixed(precision: 0))x\(self.outputDimensions.height, format: .fixed(precision: 0))")
        }

        installObservers()
    }

    /// Switch the sensor between a smooth viewfinder and the 1 fps battery mode.
    ///
    /// Decimation is timestamp-based, so the lapse still gets exactly one frame
    /// every `frameInterval` seconds no matter which mode the sensor is in. The
    /// only thing that changes is how many frames we throw away.
    func setFrameRateMode(_ mode: FrameRateMode) {
        captureQueue.async {
            guard self.rateMode != mode else { return }
            self.rateMode = mode
            self.applySensorRate()
        }
    }

    /// Pin the sensor's frame duration.
    ///
    /// `minFrameDuration` is the *fastest* rate, `maxFrameDuration` the slowest;
    /// setting both to the same value locks the sensor there.
    ///
    /// Deliberately applied AFTER `commitConfiguration` and again after every
    /// `startRunning`: changing the session preset resets the device's frame
    /// duration, so setting it inside a configuration block gets silently undone.
    private func applySensorRate() {
        guard let device,
              let range = device.activeFormat.videoSupportedFrameRateRanges
                .min(by: { $0.minFrameRate < $1.minFrameRate }) else { return }

        let duration: CMTime
        switch rateMode {
        case .lowPower:
            duration = range.maxFrameDuration
        case .smoothPreview:
            // Clamp 30 fps into whatever the active format actually supports.
            let target = CMTime(value: 1, timescale: 30)
            duration = CMTimeClampToRange(
                target, range: CMTimeRange(start: range.minFrameDuration,
                                           end: range.maxFrameDuration))
        }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            let fps = 1.0 / CMTimeGetSeconds(duration)
            log.info("sensor at \(fps, format: .fixed(precision: 2)) fps (\(String(describing: self.rateMode)))")
        } catch {
            log.error("could not set sensor rate: \(error.localizedDescription)")
        }
    }

    func start() {
        captureQueue.async {
            self.lastKeptTimestamp = nil
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            // Resuming after an interruption can restore the default frame rate.
            self.applySensorRate()
        }
    }

    func stop() {
        captureQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func tearDown() {
        stop()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        onFrame = nil
        onInterrupted = nil
        onResumed = nil
    }

    // MARK: - Interruptions

    private func installObservers() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: session, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int
            let reason = raw.flatMap(AVCaptureSession.InterruptionReason.init(rawValue:))
            self?.onInterrupted?(LapseInterruption(reason: reason))
        })

        observers.append(center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: session, queue: .main
        ) { [weak self] _ in
            self?.onResumed?()
        })

        observers.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session, queue: .main
        ) { [weak self] note in
            let error = note.userInfo?[AVCaptureSessionErrorKey] as? NSError
            self?.log.error("runtime error: \(String(describing: error))")
            self?.onInterrupted?(LapseInterruption(reason: nil))
        })
    }

}

// MARK: - Frame decimation

extension CaptureController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Decimate against the capture clock, not a wall clock or a counter.
        // The capture clock does not drift and does not jump if the user changes
        // their time zone mid-session.
        if let last = lastKeptTimestamp {
            let elapsed = CMTimeGetSeconds(CMTimeSubtract(timestamp, last))
            // 0.9 fudge: a 1 fps sensor lands frames at 0.98-1.02 s, and a strict
            // >= 4.0 test would silently stretch the real interval to 5 s.
            guard elapsed >= config.frameInterval * 0.9 else { return }
        }

        if !sawFirstFrame {
            sawFirstFrame = true
            let elapsed = CFAbsoluteTimeGetCurrent() - startedConfiguringAt
            log.info("first frame at \(elapsed, format: .fixed(precision: 3))s")
            DispatchQueue.main.async { self.onFirstFrame?() }
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastKeptTimestamp = timestamp
        onFrame?(pixelBuffer)   // synchronous: the buffer dies when we return
    }
}
