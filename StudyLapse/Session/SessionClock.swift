import Foundation

/// Elapsed study time that survives backgrounding, screen lock, and time-zone
/// changes.
///
/// Three iOS clocks, and only one is correct here:
///   * `Date()` -- wall clock. Jumps when NTP corrects or the user edits the time.
///   * `SuspendingClock` / `ProcessInfo.systemUptime` -- monotonic, but *stops*
///     while the device sleeps. A locked phone would under-count.
///   * `ContinuousClock` -- monotonic AND keeps ticking through sleep. This one.
///
/// `startedAt` (a wall-clock `Date`) is stored only so a session can be recovered
/// after the app is terminated, and for display.
struct SessionClock: Sendable {

    let startedAt: Date
    private let clock = ContinuousClock()
    private let origin: ContinuousClock.Instant
    private var pausedAt: ContinuousClock.Instant?
    private var pausedTotal: Duration = .zero

    init(startedAt: Date = Date()) {
        self.startedAt = startedAt
        self.origin = ContinuousClock.now
    }

    var isPaused: Bool { pausedAt != nil }

    /// Seconds of study time. Interruptions do NOT stop this -- backgrounding
    /// kills the camera, not the study session.
    var elapsed: TimeInterval {
        let raw = origin.duration(to: pausedAt ?? ContinuousClock.now) - pausedTotal
        return max(0, raw.seconds)
    }

    /// Only for an explicit user pause, not for camera interruptions.
    mutating func pause() {
        guard pausedAt == nil else { return }
        pausedAt = ContinuousClock.now
    }

    mutating func resume() {
        guard let pausedAt else { return }
        pausedTotal += pausedAt.duration(to: ContinuousClock.now)
        self.pausedAt = nil
    }

    /// Fallback when the app was terminated and relaunched mid-session: the
    /// in-memory origin is gone, so fall back to the wall clock.
    static func recoveredElapsed(since startedAt: Date) -> TimeInterval {
        max(0, Date().timeIntervalSince(startedAt))
    }
}

extension Duration {
    var seconds: TimeInterval {
        let (s, attos) = components
        return TimeInterval(s) + TimeInterval(attos) / 1e18
    }
}
