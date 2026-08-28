#if DEBUG
import Foundation
import SwiftData

/// Drives the app into a known state for App Store screenshots.
///
/// The App Store requires 6.9" images (1320x2868), which no iPhone 15 Pro can
/// produce, so screenshots come from an iPhone 16 Pro Max simulator. The simulator
/// has no camera, so a session has to be staged rather than recorded.
///
/// This is the real UI rendering real view code -- only the data is seeded, which
/// is standard practice and what Apple's own guidelines expect. DEBUG only, so it
/// cannot reach a Release build.
enum ScreenshotMode {

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-screenshotMode")
    }

    /// Which screen to open on launch: "list", "settings", or "session".
    static var screen: String {
        guard let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-uiScreen"),
              index + 1 < ProcessInfo.processInfo.arguments.count
        else { return "list" }
        return ProcessInfo.processInfo.arguments[index + 1]
    }

    /// A plausible fortnight of studying.
    static func seed(into context: ModelContext) {
        UserDefaults.standard.set("Calculus II", forKey: "lastSubject")
        let calendar = Calendar.current
        let now = Date()
        // (subject, days ago, hour, minute, duration, frames)
        let entries: [(String, Int, Int, Int, Double, Int)] = [
            ("Calculus II",          0, 19, 15, 5_820, 1_455),
            ("Statistics",           1,  9, 40, 3_240,   810),
            ("Linear Algebra",       1, 14,  5, 7_140, 1_785),
            ("Calculus II",          2, 20, 30, 2_700,   675),
            ("Financial Accounting", 3, 11, 20, 4_980, 1_245),
            ("Statistics",           4, 16, 45, 6_300, 1_575),
            ("Linear Algebra",       5, 21, 10, 1_920,   480),
            ("Calculus II",          6, 13,  0, 8_400, 2_100),
        ]

        for (subject, daysAgo, hour, minute, duration, frames) in entries {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: now),
                  let start = calendar.date(bySettingHour: hour, minute: minute,
                                            second: 0, of: day) else { continue }
            let session = StudySession(subject: subject, result: .init(
                startedAt: start,
                duration: duration,
                lapseCoverage: duration,
                frameCount: Int64(frames),
                videoURL: nil,
                byteSize: Int64(Double(frames) * 14_800),
                gaps: [],
                lapseDisabledReason: nil
            ))
            context.insert(session)
        }

        // One session with a real interruption, so the recap feature is visible.
        if let day = calendar.date(byAdding: .day, value: -2, to: now),
           let start = calendar.date(bySettingHour: 10, minute: 25, second: 0, of: day) {
            let gapStart = start.addingTimeInterval(1_500)
            let session = StudySession(subject: "Micro Midterm Review", result: .init(
                startedAt: start,
                duration: 6_120,
                lapseCoverage: 5_400,
                frameCount: 1_350,
                videoURL: nil,
                byteSize: 19_980_000,
                gaps: [LapseGap(start: gapStart,
                                end: gapStart.addingTimeInterval(720),
                                reason: .backgrounded)],
                lapseDisabledReason: nil
            ))
            context.insert(session)
        }
        try? context.save()
    }
}
#endif
