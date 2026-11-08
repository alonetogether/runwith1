import SwiftUI

@main
struct RunWithApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(services)
        }
    }
}

/// One container for the long-lived services so views can reach them through
/// the environment. Each service is itself `@Observable`.
@MainActor
@Observable
final class AppServices {
    let location = LocationService()
    let pedometer = PedometerService()
    let music = MusicLogger()
    let spotify = SpotifyService()
    let store = RunStore()
    let recorder = RunRecorder()
}

struct ContentView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        NavigationStack {
            switch services.recorder.state {
            case .idle where !hasSeenWelcome:
                WelcomeView { hasSeenWelcome = true }
            case .idle:
                GearCheckView()
            case .running:
                RunningView()
            case .finished(let run):
                RunDetailView(run: run, isFresh: true)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // iOS gives no warning before killing a backgrounded app; save on the way out.
            if phase == .background { services.recorder.checkpointNow() }
        }
    }
}
