import RunCore
import SwiftUI

/// Start was tapped before GPS had a fix. Recording begins by itself on the
/// first fix that passes, with a sound, so the phone can already be pocketed.
/// Shows elapsed time and current accuracy so the wait is never silent.
struct ArmingView: View {
    @Environment(AppServices.self) private var services
    @State private var snoozedUntil: TimeInterval = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(now: context.date)
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let since: Date = {
            if case .arming(let s) = services.recorder.state { return s }
            return now
        }()
        let waited = now.timeIntervalSince(since)
        let fallback = waited >= snoozedUntil
            ? ArmingPolicy.fallback(waited: waited, pedometerReady: services.pedometer.isReady)
            : .none

        VStack(spacing: 22) {
            Spacer(minLength: 12)
            ZStack {
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: min(1, waited / ArmingPolicy.fallbackAfter))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    Text("Finding GPS").font(.title3.bold())
                    Text(PaceFormat.elapsed(ms: Int(waited * 1000)))
                        .font(.system(.title2, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 200, height: 200)
            .accessibilityElement(children: .combine)

            Text(accuracyLine)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)

            Text("Recording starts by itself, with a sound.\nYou can put the phone away now.")
                .multilineTextAlignment(.center)

            if fallback != .none {
                fallbackCard(fallback, waited: waited)
            }

            Spacer()

            Button(role: .cancel) {
                services.recorder.cancelArming()
            } label: {
                Text("Cancel")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
    }

    private var accuracyLine: String {
        guard let acc = services.recorder.armingAccuracyM, acc >= 0 else { return "No signal yet" }
        return "Signal ±\(Int(acc.rounded())) m · needs ±\(Int(LocationService.usableAccuracyM)) m or better"
    }

    private func fallbackCard(_ fallback: ArmingPolicy.Fallback, waited: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Still searching after \(PaceFormat.elapsed(ms: Int(waited * 1000)))")
                .font(.headline)
            Text("Tall buildings and roofs block GPS. A few steps into open sky usually helps.")
                .font(.callout)
                .foregroundStyle(.secondary)
            if fallback == .offerSteps {
                Button {
                    services.recorder.startOnStepsWhileArming()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start on steps now").bold()
                        Text("GPS joins the run when it finds you.").font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Keep waiting") { snoozedUntil = waited + ArmingPolicy.fallbackAfter }
                .buttonStyle(.bordered)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}
