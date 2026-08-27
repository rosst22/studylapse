import SwiftData
import SwiftUI

struct SessionListView: View {
    let sessions: [StudySession]
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No sessions yet",
                    systemImage: "book.closed",
                    description: Text("Prop your phone up, hit Start, and get to work.")
                )
            }
            ForEach(sessions) { session in
                NavigationLink(value: session.id) {
                    row(session)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationDestination(for: UUID.self) { id in
            if let session = sessions.first(where: { $0.id == id }) {
                SessionDetailView(session: session)
            }
        }
    }

    private func row(_ session: StudySession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.subject).font(.headline)
                Spacer()
                Text(session.duration.studyDurationLabel)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.green)
            }
            HStack(spacing: 8) {
                Text(session.startedAt, format: .dateTime.weekday().month().day().hour().minute())
                if !session.hasCompleteLapse {
                    Label("\(session.gaps.count) gap\(session.gaps.count == 1 ? "" : "s")",
                          systemImage: "scissors")
                }
                Spacer()
                Text(session.byteSize.byteLabel)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let session = sessions[index]
            VideoStore.delete(session.videoURL)   // never orphan the .mov
            context.delete(session)
        }
    }
}
