import SwiftUI

/// First launch only (diagnostic doc §6, first-run flow): a short welcome
/// before the gear check. It explains, it asks for nothing; every permission
/// is primed later, in context, on the gear check itself.
struct WelcomeView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Run With")
                .font(.largeTitle.bold())
            Text("Records your route, your pace and the music that played, and keeps it on this phone. Your first runs are the baseline everything later is built on, so there is no test to pass. Just run.")
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                Label("Phone-only is fine. Location is all a run needs.", systemImage: "iphone")
                Label("Permissions are asked one at a time, when they are needed.", systemImage: "hand.raised")
                Label("Start unlocks once GPS has a fix, so no run is lost to a silent failure.", systemImage: "location.viewfinder")
            }
            .font(.callout)
            .labelStyle(WelcomeLabelStyle())

            Spacer()
            Button(action: onContinue) {
                Text("Set up my gear")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .navigationBarHidden(true)
    }
}

private struct WelcomeLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            configuration.icon
                .frame(width: 22)
                .foregroundStyle(.tint)
            configuration.title
        }
    }
}
