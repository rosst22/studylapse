import SwiftData
import SwiftUI

@main
struct StudyLapseApp: App {
    @State private var recorder = TimeLapseRecorder()
    private let container: ModelContainer = {
        #if DEBUG
        if ScreenshotMode.isActive {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: StudySession.self, configurations: config)
            ScreenshotMode.seed(into: ModelContext(container))
            return container
        }
        #endif
        return try! ModelContainer(for: StudySession.self)
    }()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Trace.launch("App.init")
        // Segments left on disk mean a previous run was killed mid-session. Only
        // bin them if there is no recovery record pointing at them -- otherwise
        // we would be deleting the very footage we are about to offer back.
        if SessionRecovery.pending() == nil {
            VideoStore.purgeOrphanedSegments()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear { Trace.launch("RootView appeared - app usable") }
                .environment(recorder)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            recorder.handleScenePhase(phase)
        }
    }
}

/// Reads the live interface orientation so the lapse gets the right video
/// transform. `UIDevice.orientation` is unreliable (it reports face-up on a desk),
/// which is exactly the situation this app is built for.
enum InterfaceOrientation {
    @MainActor static var current: UIInterfaceOrientation {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .interfaceOrientation ?? .portrait
    }
}
