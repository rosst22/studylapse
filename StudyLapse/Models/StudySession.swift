import Foundation
import SwiftData

@Model
final class StudySession {
    var id: UUID = UUID()
    var subject: String = ""
    var startedAt: Date = Date()

    /// Total study time in seconds, gaps included.
    var duration: TimeInterval = 0
    /// Seconds the camera was actually rolling.
    var lapseCoverage: TimeInterval = 0

    var frameCount: Int = 0
    var byteSize: Int = 0
    var notes: String = ""

    /// Filename only. Absolute URLs break when iOS re-homes the container after
    /// an app update or restore -- a classic iOS bug. Rebuild the URL on read.
    var videoFilename: String?

    /// Set when a session produced no lapse at all (camera off, denied, busy) so
    /// the recap can explain itself instead of showing an empty player.
    var lapseDisabledReason: String?

    /// SwiftData persists Codable value types directly, so gaps ride along with
    /// the session without a second @Model.
    var gaps: [LapseGap] = []

    init(subject: String, result: TimeLapseRecorder.Result) {
        self.id = UUID()
        self.subject = subject
        self.startedAt = result.startedAt
        self.duration = result.duration
        self.lapseCoverage = result.lapseCoverage
        self.frameCount = Int(result.frameCount)
        self.byteSize = Int(result.byteSize)
        self.gaps = result.gaps
        self.videoFilename = result.videoURL?.lastPathComponent
        self.lapseDisabledReason = result.lapseDisabledReason
    }

    var videoURL: URL? {
        videoFilename.map { VideoStore.root.appendingPathComponent($0) }
    }

    var hasCompleteLapse: Bool { gaps.isEmpty }

    var coverageFraction: Double {
        duration > 0 ? min(1, lapseCoverage / duration) : 0
    }
}

extension TimeInterval {
    /// "1h 42m" / "8m 12s"
    var studyDurationLabel: String {
        let total = Int(self)
        let (h, m, s) = (total / 3600, (total % 3600) / 60, total % 60)
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    /// "00:42:07" for the live timer.
    var clockLabel: String {
        let total = Int(self)
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}

extension Int {
    var byteLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file)
    }
}
