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

            Button(role: .destructive) {
                confirmEnd = true
            } label: {
                Text("End Run")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .confirmationDialog("End this run?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End Run", role: .destructive) {
                services.recorder.stop(location: services.location,
                                       pedometer: services.pedometer,
                                       music: services.music,
                                       spotify: services.spotify,
                                       store: services.store)
            }
            Button("Keep running", role: .cancel) {}
        }
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
