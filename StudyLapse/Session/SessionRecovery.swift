import Foundation
import os

/// A session that was running when the app died.
///
/// The segment files on disk are already playable (each one was finalised before
/// the app suspended), but nothing ties them to a subject, a start time, or a
/// duration. This record is that missing piece: a small JSON file written when
/// recording starts and heartbeated while it runs.
struct ActiveSessionRecord: Codable, Sendable {
    var sessionID: UUID
    var subject: String
    var startedAt: Date
    /// Refreshed every few seconds while recording. On recovery this is how we
    /// know when the app actually died -- wall clock alone would count the hours
    /// the phone sat in a pocket afterwards as study time.
    var lastHeartbeat: Date
    var gaps: [LapseGap]
    var frameCount: Int64

    var recoveredDuration: TimeInterval {
        max(0, lastHeartbeat.timeIntervalSince(startedAt))
    }
}

enum SessionRecovery {

    private static let log = Logger(subsystem: "app.studylapse", category: "recovery")
    private static var url: URL { VideoStore.root.appendingPathComponent("active-session.json") }

    static func write(_ record: ActiveSessionRecord) {
        do {
            let data = try JSONEncoder().encode(record)
            try data.write(to: url, options: .atomic)
        } catch {
            log.error("could not persist active session: \(error.localizedDescription)")
        }
    }

    static func pending() -> ActiveSessionRecord? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ActiveSessionRecord.self, from: data)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }

    /// Rebuild a finished session from whatever survived on disk.
    static func recover(_ record: ActiveSessionRecord) async -> TimeLapseRecorder.Result {
        let segments = VideoStore.segments(for: record.sessionID)
        var videoURL: URL?
        if !segments.isEmpty {
            let destination = VideoStore.finalURL(for: record.sessionID)
            do { videoURL = try await SegmentStitcher.stitch(segments: segments, to: destination) }
            catch { log.error("recovery stitch failed: \(error.localizedDescription)") }
        }
        clear()
        VideoStore.purgeOrphanedSegments()

        let duration = record.recoveredDuration
        let gapTotal = record.gaps.reduce(0) { $0 + $1.duration }
        return TimeLapseRecorder.Result(
            startedAt: record.startedAt,
            duration: duration,
            lapseCoverage: videoURL == nil ? 0 : max(0, duration - gapTotal),
            frameCount: record.frameCount,
            videoURL: videoURL,
            byteSize: videoURL.map(VideoStore.fileSize) ?? 0,
            gaps: record.gaps,
            lapseDisabledReason: videoURL == nil
                ? "StudyLapse closed before any footage was saved." : nil
        )
    }

    static func discard() {
        clear()
        VideoStore.purgeOrphanedSegments()
    }
}
