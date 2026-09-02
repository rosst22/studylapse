import AVFoundation
import Observation
import SwiftUI
import UIKit
import os

/// The object the UI talks to. Ties together the clock, the camera, the segment
/// pipeline, and iOS lifecycle events.
///
/// Design rule that matters for App Review and for the product: **the session is
/// the timer; the lapse is a bonus.** If the user refuses camera access, or the
/// camera is busy, or the phone overheats, the study session still runs and still
/// saves. Nothing here is allowed to dead-end.
@MainActor
@Observable
final class TimeLapseRecorder {

    enum State: Equatable {
        case idle
        case preparing
        case ready          // camera framing, clock not started
        case recording
        case interrupted(LapseInterruption)
        case finishing
    }

    /// Whether a lapse is being produced at all, and why not.
    enum LapseMode: Equatable {
        case enabled
        case cameraDenied
        case unavailable(String)

        var isEnabled: Bool { self == .enabled }

        var reason: String? {
            switch self {
            case .enabled: nil
            case .cameraDenied:
                "Camera access is off, so this session records time only. Turn it on in Settings to get a time lapse."
            case .unavailable(let why): why
            }
        }
    }

    struct Result: Sendable {
        var startedAt: Date
        var duration: TimeInterval      // study time, including gaps
        var lapseCoverage: TimeInterval // time the camera was actually rolling
        var frameCount: Int64
        var videoURL: URL?
        var byteSize: Int64
        var gaps: [LapseGap]
        var lapseDisabledReason: String?
    }

    private(set) var state: State = .idle
    private(set) var mode: LapseMode = .enabled
    private(set) var elapsed: TimeInterval = 0
    private(set) var frameCount: Int64 = 0
    private(set) var gaps: [LapseGap] = []
    /// False until the camera has actually produced a frame. The preview is a
    /// black rectangle before that, so the UI shows "Starting camera" instead.
    private(set) var previewLive = false

    /// Settable only while idle; the session screen writes the user's saved
    /// preferences in before preparing.
    var config = CaptureConfiguration()

    /// Live size estimate, so the UI can show "~12 MB so far".
    var estimatedBytes: Int64 {
        Int64(Double(frameCount) * Double(config.averageBitRate)
              / Double(config.playbackFrameRate) / 8.0)
    }

    var lapseCoverage: TimeInterval {
        max(0, elapsed - gaps.reduce(0) { $0 + $1.duration })
    }

    /// The shared preview layer. Nil until the camera has been configured.
    var previewLayer: AVCaptureVideoPreviewLayer? { capture?.previewLayer }

    private let log = Logger(subsystem: "app.studylapse", category: "recorder")
    private var capture: CaptureController?
    private var pipeline: SegmentPipeline?
    private var clock: SessionClock?
    private var sessionID = UUID()
    private var ticker: Timer?
    private var subject = ""
    private var lastHeartbeat = Date.distantPast
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    // MARK: - Prepare (framing, before the clock starts)

    func prepare(interfaceOrientation: UIInterfaceOrientation = .portrait) async {
        guard state == .idle else { return }
        Trace.mark("prepare() begin")
        state = .preparing

        sessionID = UUID()
        frameCount = 0
        gaps = []
        elapsed = 0
        previewLive = false
        mode = .enabled

        Trace.mark("requesting camera access")
        guard await CaptureController.requestAccess() else {
            mode = .cameraDenied
            state = .ready          // timer-only session, never a dead end
            return
        }

        Trace.mark("access granted")
        let capture = CaptureController(config: config)
        let pipeline = SegmentPipeline(sessionID: sessionID, config: config,
                                       queue: capture.captureQueue)

        pipeline.onFrameWritten = { [weak self] total in self?.frameCount = total }
        capture.onFrame = { [weak pipeline] buffer in pipeline?.ingest(buffer) }
        capture.onInterrupted = { [weak self] reason in
            Task { @MainActor in await self?.handleInterruption(reason) }
        }
        capture.onResumed = { [weak self] in
            Task { @MainActor in self?.handleResume() }
        }
        capture.onFirstFrame = { [weak self] in
            Trace.mark("FIRST FRAME - preview live")
            self?.previewLive = true
        }

        Trace.mark("calling configure()")
        do {
            try await capture.configure(interfaceOrientation: interfaceOrientation)
        } catch {
            mode = .unavailable(error.localizedDescription)
            state = .ready
            return
        }

        self.capture = capture
        self.pipeline = pipeline
        Trace.mark("configure() returned, state = .ready")
        state = .ready
    }

    // MARK: - Record

    func beginRecording(subject: String) {
        guard state == .ready else { return }
        self.subject = subject
        clock = SessionClock()
        if mode.isEnabled, let capture, let pipeline {
            pipeline.openSegment(dimensions: capture.outputDimensions)
        }
        state = .recording
        Trace.mark("beginRecording: state = .recording")

        // Keep the screen awake so the common case never hits an interruption at
        // all. The session view goes near-black to make this cheap on OLED.
        UIApplication.shared.isIdleTimerDisabled = true
        persistRecoveryRecord()
        startTicker()
    }

    /// Written at start, heartbeated every 15 s, and updated whenever a gap opens
    /// or closes. If the app is killed, this is the only thing that can tie the
    /// orphaned segment files back to a real session.
    private func persistRecoveryRecord() {
        guard let clock, state != .idle, state != .finishing else { return }
        lastHeartbeat = Date()
        SessionRecovery.write(ActiveSessionRecord(
            sessionID: sessionID,
            subject: subject,
            startedAt: clock.startedAt,
            lastHeartbeat: lastHeartbeat,
            gaps: gaps,
            frameCount: frameCount
        ))
    }

    /// Called by the session view when the preview appears or disappears. While
    /// anyone can see the viewfinder the sensor runs at 30 fps so it looks live;
    /// once the screen dims it drops to ~1 fps and the battery saving kicks in.
    func setPreviewVisible(_ visible: Bool) {
        capture?.setFrameRateMode(visible ? .smoothPreview : .lowPower)
    }

    // MARK: - Stop

    func stop() async -> Result? {
        guard state != .idle else { return nil }
        // Cancelled from the framing screen: nothing to save.
        guard let clock else { await discard(); return nil }

        state = .finishing
        stopTicker()
        elapsed = clock.elapsed
        closeOpenGap()

        capture?.stop()
        await pipeline?.closeSegment()

        var videoURL: URL?
        if let pipeline {
            let segments = await pipeline.allSegments()
            if !segments.isEmpty {
                let destination = VideoStore.finalURL(for: sessionID)
                do { videoURL = try await SegmentStitcher.stitch(segments: segments, to: destination) }
                catch { log.error("stitch failed: \(error.localizedDescription)") }
            }
        }

        SessionRecovery.clear()

        let result = Result(
            startedAt: clock.startedAt,
            duration: elapsed,
            lapseCoverage: videoURL == nil ? 0 : lapseCoverage,
            frameCount: frameCount,
            videoURL: videoURL,
            byteSize: videoURL.map(VideoStore.fileSize) ?? 0,
            gaps: gaps,
            lapseDisabledReason: videoURL == nil ? (mode.reason ?? "No frames were captured.") : nil
        )

        teardown()
        return result
    }

    func discard() async {
        SessionRecovery.clear()
        stopTicker()
        capture?.stop()
        await pipeline?.closeSegment()
        pipeline?.discardEverything()
        teardown()
    }

    private func teardown() {
        capture?.tearDown()
        capture = nil
        pipeline = nil
        clock = nil
        UIApplication.shared.isIdleTimerDisabled = false
        state = .idle
    }

    #if DEBUG
    /// Stage the recording screen for App Store screenshots. The views are the
    /// real ones; only the state is supplied. DEBUG only.
    func enterDemoState(elapsed: TimeInterval, frames: Int64) {
        self.elapsed = elapsed
        self.frameCount = frames
        self.mode = .enabled
        self.state = .recording
    }
    #endif

    // MARK: - iOS lifecycle

    /// Wire this to SwiftUI's `.onChange(of: scenePhase)`.
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            Task { await suspendForBackground() }
        case .active:
            // Coming back from Settings after granting access: retry the camera.
            if state == .ready, mode == .cameraDenied,
               CaptureController.authorizationStatus == .authorized {
                Task { state = .idle; await prepare(interfaceOrientation: InterfaceOrientation.current) }
                return
            }
            if case .interrupted = state { handleResume() }
            capture?.start()
        default:
            break
        }
    }

    /// iOS gives a backgrounding app only a few seconds before it is frozen.
    /// `beginBackgroundTask` buys ~30 s of wall time -- enough for
    /// `finishWriting()` to close the .mov header so the segment stays playable.
    private func suspendForBackground() async {
        guard state == .recording || isInterrupted else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "close-lapse-segment") {
            // Expiration handler: iOS is out of patience.
            Task { @MainActor in self.endBackgroundTask() }
        }
        await pipeline?.closeSegment()
        endBackgroundTask()
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    // MARK: - Interruptions

    private var isInterrupted: Bool { if case .interrupted = state { true } else { false } }

    private func handleInterruption(_ reason: LapseInterruption) async {
        guard state == .recording else { return }
        state = .interrupted(reason)
        // The clock deliberately keeps running: losing the camera does not mean
        // the user stopped studying.
        gaps.append(LapseGap(start: Date(), end: nil, reason: reason))
        persistRecoveryRecord()
        await pipeline?.closeSegment()
        log.notice("lapse interrupted: \(reason.rawValue)")
    }

    private func handleResume() {
        guard isInterrupted, let capture, let pipeline else { return }
        closeOpenGap()
        persistRecoveryRecord()
        pipeline.openSegment(dimensions: capture.outputDimensions)
        capture.start()
        state = .recording
        log.notice("lapse resumed")
    }

    private func closeOpenGap() {
        guard let index = gaps.lastIndex(where: { $0.end == nil }) else { return }
        gaps[index].end = Date()
    }

    // MARK: - Ticker

    private func startTicker() {
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let clock = self.clock else { return }
                self.elapsed = clock.elapsed
                if Date().timeIntervalSince(self.lastHeartbeat) >= 15 {
                    self.persistRecoveryRecord()
                }
            }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
}
