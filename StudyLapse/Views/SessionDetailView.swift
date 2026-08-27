import AVKit
import SwiftData
import SwiftUI

struct SessionDetailView: View {
    let session: StudySession
    @State private var player: AVPlayer?

    private var videoURL: URL? {
        guard let url = session.videoURL,
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                lapse

                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                    stat("Studied", session.duration.studyDurationLabel)
                    if videoURL != nil {
                        stat("Lapse covers", session.lapseCoverage.studyDurationLabel)
                        stat("Frames", "\(session.frameCount)")
                        stat("Size", session.byteSize.byteLabel)
                    }
                    stat("Started", session.startedAt.formatted(date: .abbreviated, time: .shortened))
                }

                if !session.gaps.isEmpty { gapsCard }
            }
            .padding()
        }
        .navigationTitle(session.subject)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url = videoURL {
                ToolbarItem(placement: .topBarTrailing) {
                    // The system share sheet can save to Photos or send the file
                    // onward without the app itself needing photo-library access.
                    ShareLink(item: url,
                              preview: SharePreview("\(session.subject) time lapse"))
                }
            }
        }
        .onDisappear { player?.pause() }
    }

    @ViewBuilder private var lapse: some View {
        if let url = videoURL {
            VideoPlayer(player: player ?? AVPlayer(url: url))
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onAppear { if player == nil { player = AVPlayer(url: url) } }
        } else {
            ContentUnavailableView {
                Label("No time lapse", systemImage: "video.slash")
            } description: {
                Text(session.lapseDisabledReason ?? "This session recorded time only.")
            }
        }
    }

    private var gapsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Why the lapse has jumps").font(.headline)
            ForEach(session.gaps) { gap in
                VStack(alignment: .leading, spacing: 2) {
                    Label("\(gap.reason.shortLabel) — \(gap.duration.studyDurationLabel)",
                          systemImage: "exclamationmark.triangle")
                        .font(.subheadline.weight(.medium))
                    Text(gap.reason.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).font(.body.monospacedDigit().weight(.medium))
        }
    }
}
