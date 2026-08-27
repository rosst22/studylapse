import AVFoundation
import Foundation
import os

/// Joins the per-stretch segments into one lapse file.
///
/// Every segment came out of the same encoder with identical settings, so
/// `passthrough` concatenates them by rewriting containers only -- no re-encode,
/// no quality loss, no size change, and it finishes in well under a second.
enum SegmentStitcher {

    private static let log = Logger(subsystem: "app.studylapse", category: "stitcher")

    static func stitch(segments: [URL], to destination: URL) async throws -> URL {
        guard !segments.isEmpty else { throw CaptureError.configurationFailed("no segments") }

        // One segment: nothing to join, just move it into place.
        if segments.count == 1 {
            VideoStore.delete(destination)
            try FileManager.default.moveItem(at: segments[0], to: destination)
            return destination
        }

        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .video,
                                                      preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw CaptureError.configurationFailed("could not build composition track")
        }

        var cursor = CMTime.zero
        var didSetTransform = false

        for url in segments {
            let asset = AVURLAsset(url: url)
            guard let source = try await asset.loadTracks(withMediaType: .video).first else { continue }
            let duration = try await asset.load(.duration)
            guard duration.isValid, duration > .zero else { continue }
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration),
                                      of: source, at: cursor)
            if !didSetTransform {
                track.preferredTransform = try await source.load(.preferredTransform)
                didSetTransform = true
            }
            cursor = cursor + duration
        }

        VideoStore.delete(destination)

        let preset = AVAssetExportPresetPassthrough
        guard let export = AVAssetExportSession(asset: composition, presetName: preset) else {
            throw CaptureError.configurationFailed("export session unavailable")
        }
        try await export.export(to: destination, as: .mov)
        log.info("stitched \(segments.count) segments -> \(VideoStore.fileSize(at: destination)) bytes")

        segments.forEach { VideoStore.delete($0) }
        return destination
    }
}
