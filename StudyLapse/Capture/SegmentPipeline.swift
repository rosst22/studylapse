import AVFoundation
import CoreVideo
import Foundation
import os

/// Owns the current segment writer and the list of finished ones.
///
/// Every method runs on the capture queue it is handed at init -- the same queue
/// the sample-buffer delegate fires on. That single-queue rule is what makes
/// `ingest` safe to call synchronously from the delegate with no locks.
final class SegmentPipeline: @unchecked Sendable {

    private let queue: DispatchQueue
    private let config: CaptureConfiguration
    private let sessionID: UUID
    private let log = Logger(subsystem: "app.studylapse", category: "pipeline")

    private var writer: TimeLapseSegmentWriter?
    private var finishedSegments: [URL] = []
    private var segmentIndex = 0
    private var frameTotal: Int64 = 0

    /// Fired on the main queue after each successful frame, for the live counter.
    var onFrameWritten: ((Int64) -> Void)?

    init(sessionID: UUID, config: CaptureConfiguration, queue: DispatchQueue) {
        self.sessionID = sessionID
        self.config = config
        self.queue = queue
    }

    // MARK: - Called on the capture queue by the delegate

    func ingest(_ pixelBuffer: CVPixelBuffer) {
        guard let writer else { return }   // between segments: silently drop
        if writer.append(pixelBuffer) {
            frameTotal += 1
            let total = frameTotal
            DispatchQueue.main.async { self.onFrameWritten?(total) }
        }
    }

    // MARK: - Called from the main actor

    func openSegment(transform: CGAffineTransform) {
        queue.async {
            guard self.writer == nil else { return }
            let url = VideoStore.segmentURL(for: self.sessionID, index: self.segmentIndex)
            do {
                self.writer = try TimeLapseSegmentWriter(url: url, config: self.config,
                                                         transform: transform)
                self.segmentIndex += 1
                self.log.info("opened segment \(self.segmentIndex - 1)")
            } catch {
                self.log.error("segment open failed: \(error.localizedDescription)")
            }
        }
    }

    /// Finalises the open segment. Awaiting this before the app suspends is what
    /// keeps a backgrounded session's footage playable.
    func closeSegment() async {
        let writer: TimeLapseSegmentWriter? = await withCheckedContinuation { c in
            queue.async {
                let w = self.writer
                self.writer = nil
                c.resume(returning: w)
            }
        }
        guard let writer else { return }
        if let url = await writer.finish() {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                queue.async { self.finishedSegments.append(url); c.resume() }
            }
            log.info("closed segment, \(writer.framesWritten) frames")
        }
    }

    func allSegments() async -> [URL] {
        await withCheckedContinuation { c in
            queue.async { c.resume(returning: self.finishedSegments) }
        }
    }

    func discardEverything() {
        queue.async {
            self.writer?.cancel()
            self.writer = nil
            self.finishedSegments.forEach { VideoStore.delete($0) }
            self.finishedSegments.removeAll()
        }
    }
}
