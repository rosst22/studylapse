import AVFoundation
import Foundation

/// Why the camera stopped. Persisted with the session so the detail view can
/// explain gaps in the lapse instead of silently swallowing them.
enum LapseInterruption: String, Codable, Sendable, CaseIterable {
    case backgrounded
    case screenLocked
    case cameraTakenByAnotherApp
    case multitasking
    case systemPressure
    case unknown

    init(reason: AVCaptureSession.InterruptionReason?) {
        switch reason {
        case .videoDeviceNotAvailableInBackground: self = .backgrounded
        case .videoDeviceInUseByAnotherClient, .audioDeviceInUseByAnotherClient:
            self = .cameraTakenByAnotherApp
        case .videoDeviceNotAvailableWithMultipleForegroundApps: self = .multitasking
        case .videoDeviceNotAvailableDueToSystemPressure: self = .systemPressure
        default: self = .unknown
        }
    }

    /// Shown live on the session screen and again in the recap.
    var explanation: String {
        switch self {
        case .backgrounded:
            "The lapse paused when StudyLapse left the screen -- you switched apps or the screen locked. iOS only allows camera access in the foreground. Your study time kept counting."
        case .screenLocked:
            "The lapse paused when the screen locked. Your study time kept counting."
        case .cameraTakenByAnotherApp:
            "Another app took the camera. The lapse will resume when it lets go."
        case .multitasking:
            "iPad Split View turned the camera off. Run StudyLapse full screen to keep the lapse going."
        case .systemPressure:
            "The phone got too hot and shut the camera down. The lapse resumes once it cools."
        case .unknown:
            "The camera stopped unexpectedly. Your study time is still counting."
        }
    }

    var shortLabel: String {
        switch self {
        case .backgrounded:            "Left the app"
        case .screenLocked:            "Screen locked"
        case .cameraTakenByAnotherApp: "Camera in use"
        case .multitasking:            "Split View"
        case .systemPressure:          "Overheating"
        case .unknown:                 "Camera stopped"
        }
    }
}

/// A stretch of a session where the clock kept running but no frames were captured.
struct LapseGap: Codable, Sendable, Hashable, Identifiable {
    var id = UUID()
    var start: Date
    var end: Date?
    var reason: LapseInterruption

    var duration: TimeInterval { (end ?? Date()).timeIntervalSince(start) }
}
