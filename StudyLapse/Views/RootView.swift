import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(TimeLapseRecorder.self) private var recorder
    @Environment(\.modelContext) private var context
    @Query(sort: \StudySession.startedAt, order: .reverse) private var sessions: [StudySession]
    @State private var showingSession = false
    @State private var showingSettings = false
    @State private var pendingRecovery: ActiveSessionRecord?
    @State private var recovering = false

    var body: some View {
        NavigationStack {
            SessionListView(sessions: sessions)
                .navigationTitle("StudyLapse")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Button {
                        Trace.begin("tap Start session (list)")
                        showingSession = true
                    } label: {
                        Label("Start session", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .padding()
                    .background(.bar)
                }
        }
        .fullScreenCover(isPresented: $showingSession) {
            ActiveSessionView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .task { pendingRecovery = SessionRecovery.pending() }
        #if DEBUG
        .onAppear {
            guard ScreenshotMode.isActive else { return }
            switch ScreenshotMode.screen {
            case "settings": showingSettings = true
            case "session":
                recorder.enterDemoState(elapsed: 4_517, frames: 1_129)
                showingSession = true
            default: break
            }
        }
        #endif
        .alert("Unfinished session", isPresented: .constant(pendingRecovery != nil && !recovering),
               presenting: pendingRecovery) { record in
            Button("Save it") {
                recovering = true
                Task {
                    let result = await SessionRecovery.recover(record)
                    context.insert(StudySession(subject: record.subject, result: result))
                    pendingRecovery = nil
                    recovering = false
                }
            }
            Button("Discard", role: .destructive) {
                SessionRecovery.discard()
                pendingRecovery = nil
            }
        } message: { record in
            Text("StudyLapse closed during “\(record.subject)” on "
                 + record.startedAt.formatted(date: .abbreviated, time: .shortened)
                 + ". It ran for \(record.recoveredDuration.studyDurationLabel) and captured "
                 + "\(record.frameCount) frames. Save what survived?")
        }
    }
}
