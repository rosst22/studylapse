import Foundation

/// Startup timing that actually reaches the console stream.
///
/// `os.Logger` writes to the unified log, which `devicectl --console` does not
/// capture -- only stdout/stderr come through. Debug builds therefore also print,
/// so cold-start latency can be measured on a real device over Wi-Fi.
enum Trace {
    nonisolated(unsafe) private static var origin = CFAbsoluteTimeGetCurrent()

    /// Wall time since the process was created, which is what "how long until the
    /// app is usable" actually means to a user.
    static var sinceProcessStart: Double {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return 0 }
        let start = Double(info.kp_proc.p_starttime.tv_sec)
            + Double(info.kp_proc.p_starttime.tv_usec) / 1e6
        return Date().timeIntervalSince1970 - start
    }

    static func launch(_ label: String) {
        #if DEBUG || TRACE_ENABLED
        emit(String(format: "[launch] %8.1f ms since process start  %@",
                    sinceProcessStart * 1000, label))
        #endif
    }

    static func begin(_ label: String) {
        origin = CFAbsoluteTimeGetCurrent()
        mark("BEGIN \(label)")
    }

    static func mark(_ label: String) {
        #if DEBUG || TRACE_ENABLED
        let ms = (CFAbsoluteTimeGetCurrent() - origin) * 1000
        emit(String(format: "[trace] %8.1f ms  %@", ms, label))
        #endif
    }

    /// Print AND append to a file.
    ///
    /// stdout only survives when the app is launched from `devicectl --console`,
    /// which spawns the process directly and therefore skips whatever iOS does
    /// before a normal icon tap. The file is the only way to see a real launch.
    private static func emit(_ line: String) {
        #if DEBUG || TRACE_ENABLED
        print(line)
        fflush(stdout)
        let stamped = ISO8601DateFormatter().string(from: Date()) + "  " + line + "\n"
        let url = logURL
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            handle.write(Data(stamped.utf8))
        } else {
            try? stamped.write(to: url, atomically: true, encoding: .utf8)
        }
        #endif
    }

    static var logURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("trace.log")
    }
}
