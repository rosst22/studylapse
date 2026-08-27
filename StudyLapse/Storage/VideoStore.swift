import Foundation
import os

/// Where lapse videos live on disk.
///
/// Application Support, not Documents (which the Files app can expose) and not
/// Caches (which iOS may purge without warning -- that would silently delete a
/// user's sessions). Excluded from iCloud backup: ~26 MB per session would
/// balloon a heavy user's backup. v2 syncs to Supabase instead.
enum VideoStore {

    private static let log = Logger(subsystem: "app.studylapse", category: "store")

    static let root: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        var dir = base.appendingPathComponent("Lapses", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        return dir
    }()

    /// Scratch space for in-progress segments, cleared on launch.
    static let segmentsRoot: URL = {
        let dir = root.appendingPathComponent("segments", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func finalURL(for sessionID: UUID) -> URL {
        root.appendingPathComponent("\(sessionID.uuidString).mov")
    }

    static func segmentURL(for sessionID: UUID, index: Int) -> URL {
        segmentsRoot.appendingPathComponent("\(sessionID.uuidString)-\(index).mov")
    }

    static func fileSize(at url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap(Int64.init) ?? 0
    }

    static func delete(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Segment files belonging to one session, in capture order.
    static func segments(for sessionID: UUID) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: segmentsRoot, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.lastPathComponent.hasPrefix(sessionID.uuidString) }
            .sorted { a, b in index(of: a) < index(of: b) }
    }

    private static func index(of url: URL) -> Int {
        Int(url.deletingPathExtension().lastPathComponent.split(separator: "-").last ?? "0") ?? 0
    }

    /// Only safe once any recoverable session has been dealt with.
    static func purgeOrphanedSegments() {
        let files = (try? FileManager.default.contentsOfDirectory(at: segmentsRoot,
                                                                  includingPropertiesForKeys: nil)) ?? []
        for file in files { try? FileManager.default.removeItem(at: file) }
        if !files.isEmpty { log.notice("purged \(files.count) orphaned segments") }
    }
}
