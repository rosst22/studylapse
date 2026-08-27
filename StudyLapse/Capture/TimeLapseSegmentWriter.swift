import AVFoundation
import CoreMedia
import CoreVideo
import os

/// Encodes one contiguous stretch of capture straight to a .mov on disk.
///
/// Why "segment": an AVAssetWriter only produces a playable file after
/// `finishWriting()`. If iOS kills us while backgrounded mid-write, the file is
/// garbage. So every time the camera stops (backgrounding, screen lock, a phone
/// call) we finalise the current segment and open a fresh one on resume. At Stop
/// the segments are concatenated. Worst case a crash costs one segment, not the
/// whole session.
///
/// Not thread-safe by itself. `TimeLapseRecorder` confines it to the capture queue.
final class TimeLapseSegmentWriter {

    let url: URL
    private let config: CaptureConfiguration
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let log = Logger(subsystem: "app.studylapse", category: "writer")

    private var frameIndex: Int64 = 0
    private var didStartSession = false

    /// Frames successfully committed to this segment.
    var framesWritten: Int64 { frameIndex }

    /// - Parameter dimensions: post-rotation frame size. Buffers arrive already
    ///   upright from the capture connection, so the track needs no transform.
    init(url: URL, config: CaptureConfiguration, dimensions: CGSize) throws {
        self.url = url
        self.config = config

        try? FileManager.default.removeItem(at: url)
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)

        input = AVAssetWriterInput(mediaType: .video,
                                   outputSettings: config.videoOutputSettings(dimensions: dimensions))
        // The source is a live camera, so appends must never block waiting for
        // the encoder. At 0.25 fps we will never actually saturate it.
        input.expectsMediaDataInRealTime = true

        adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: config.pixelBufferAttributes(dimensions: dimensions)
        )

        guard writer.canAdd(input) else {
            throw CaptureError.writerRejectedInput
        }
        writer.add(input)
    }

    /// Appends one frame. Call synchronously from the capture delegate queue and
    /// do not retain `pixelBuffer` afterwards -- it belongs to the camera's pool.
    @discardableResult
    func append(_ pixelBuffer: CVPixelBuffer) -> Bool {
        if !didStartSession {
            guard writer.startWriting() else {
                log.error("startWriting failed: \(String(describing: self.writer.error))")
                return false
            }
            writer.startSession(atSourceTime: .zero)
            didStartSession = true
        }

        guard writer.status == .writing else { return false }

        // Back-pressure valve. If the encoder is behind we drop this frame
        // rather than queue it -- a missing frame in a 120x lapse is invisible,
        // an unbounded queue is an OOM crash.
        guard input.isReadyForMoreMediaData else {
            log.notice("encoder not ready, dropping frame \(self.frameIndex)")
            return false
        }

        let pts = config.presentationTime(forFrameIndex: frameIndex)
        guard adaptor.append(pixelBuffer, withPresentationTime: pts) else {
            log.error("append failed: \(String(describing: self.writer.error))")
            return false
        }
        frameIndex += 1
        return true
    }

    /// Finalises the segment. Returns nil (and cleans up) if nothing was written.
    func finish() async -> URL? {
        guard didStartSession, frameIndex > 0 else {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        input.markAsFinished()

        // AVAssetWriter predates async/await. This bridges its callback API into
        // a value you can `await` -- a very common Swift pattern worth knowing.
        await withCheckedContinuation { continuation in
            writer.finishWriting { continuation.resume() }
        }

        guard writer.status == .completed else {
            log.error("finishWriting ended \(self.writer.status.rawValue): \(String(describing: self.writer.error))")
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return url
    }

    func cancel() {
        if didStartSession { writer.cancelWriting() }
        try? FileManager.default.removeItem(at: url)
    }
}

enum CaptureError: LocalizedError {
    case noCameraAvailable
    case writerRejectedInput
    case permissionDenied
    case configurationFailed(String)

    var errorDescription: String? {
        switch self {
        case .noCameraAvailable: "No usable camera on this device."
        case .writerRejectedInput: "The video encoder rejected the 720p HEVC settings."
        case .permissionDenied: "StudyLapse needs camera access to build a time lapse."
        case .configurationFailed(let why): "Camera setup failed: \(why)"
        }
    }
}
