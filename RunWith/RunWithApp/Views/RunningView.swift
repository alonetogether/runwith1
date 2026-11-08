import MapKit
import RunCore
import SwiftUI

/// Minimal, dark, glanceable. Elapsed time is the biggest thing on screen.
struct RunningView: View {
    @Environment(AppServices.self) private var services
    @State private var confirmEnd = false
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        let r = services.recorder
        VStack(spacing: 20) {
            Text(PaceFormat.elapsed(ms: r.elapsedMs))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
                .padding(.top, 8)

            HStack(spacing: 0) {
                Metric(value: PaceFormat.kilometres(r.distanceM), unit: "km")
                Metric(value: PaceFormat.minPerKm(speedMps: r.speedMps), unit: "min/km")
                Metric(value: r.cadenceSpm.map { "\(Int($0.rounded()))" } ?? "–", unit: "spm")
            }

            sourceChip

            Map(position: $camera) {
                if r.trace.count >= 2 {
                    MapPolyline(coordinates: r.trace)
                        .stroke(.orange, lineWidth: 4)
                }
                UserAnnotation()
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer(minLength: 0)

            HoldToEndButton {
                endRun()
            } onAccessibilityEnd: {
                confirmEnd = true
            }
        }
        .padding()
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .confirmationDialog("End this run?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End Run", role: .destructive) { endRun() }
            Button("Keep running", role: .cancel) {}
        }
    }

    private func endRun() {
        services.recorder.stop(location: services.location,
                               pedometer: services.pedometer,
                               music: services.music,
                               spotify: services.spotify,
                               store: services.store)
    }

    private var sourceChip: some View {
        let r = services.recorder
        let text: String
        let tint: Color
        switch r.liveSource {
        case .gps:
            let acc = services.location.latestFix.map { " · ±\(Int($0.horizontalAccuracyM.rounded())) m" } ?? ""
            text = "GPS\(acc) · \(r.acceptedPoints) pts"
            tint = .green
        case .pedometer:
            text = "Steps (proxy) · \(r.acceptedPoints) pts"
            tint = .orange
        case .fused:
            text = "Fused · \(r.acceptedPoints) pts"
            tint = .green
        case nil:
            text = "No signal · waiting"
            tint = .secondary
        }
        return HStack(spacing: 8) {
            Circle().fill(tint).frame(width: 8, height: 8)
            Text(text)
            if r.rejectedFixes > 0 {
                Text("· \(r.rejectedFixes) rejected")
                    .foregroundStyle(.secondary)
            }
            if r.musicCount > 0 {
                Image(systemName: "music.note")
                Text("\(r.musicCount)")
            }
        }
        .font(.footnote.monospacedDigit())
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }
}

private struct Metric: View {
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Press and hold to end. The screen stays awake during a run, so it is live
/// in a pocket; a hold cannot happen by accident and the filling ring explains
/// itself. A short tap only shows the hint. VoiceOver gets an "End run" action
/// that still goes through a confirmation.
struct HoldToEndButton: View {
    let onEnd: () -> Void
    let onAccessibilityEnd: () -> Void

    static let holdSeconds = 1.2
    @State private var progress: CGFloat = 0
    @State private var showHint = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Capsule().fill(Color.white.opacity(0.1))
                GeometryReader { geo in
                    Capsule()
                        .fill(Color.red.opacity(0.85))
                        .frame(width: max(0, geo.size.width * progress))
                }
                Text(progress > 0 ? "Keep holding" : "Hold to end")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            .frame(height: 58)
            .clipShape(Capsule())
            .contentShape(Capsule())
            .onLongPressGesture(minimumDuration: Self.holdSeconds, maximumDistance: 40) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onEnd()
            } onPressingChanged: { pressing in
                if pressing {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.linear(duration: Self.holdSeconds)) { progress = 1 }
                } else {
                    if progress < 1 { flashHint() }
                    withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
                }
            }
            Text("Press and hold for a second to end the run")
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(showHint ? 1 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("End run")
        .accessibilityHint("Asks for confirmation.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onAccessibilityEnd() }
    }

    private func flashHint() {
        withAnimation { showHint = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showHint = false }
        }
    }
}
