import RunCore
import SwiftUI

/// "12.8 s" under a minute, "1:04.3" above: race time to the tenth.
func raceTime(ms: Int) -> String {
    let tenths = Int((Double(ms) / 100).rounded())
    let s = tenths / 10, t = tenths % 10
    return s < 60 ? "\(s).\(t) s" : "\(s / 60):\(String(format: "%02d", s % 60)).\(t)"
}

// MARK: - Setup

/// Before a sprint: choose the distance, stand on the start line and mark it,
/// choose how the finish is found, then Ready. Lines are marked by standing
/// on them because GPS distance on a track is off by 5–10%; a marked line is
/// only position noise.
struct SprintSetupView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @AppStorage("sprintTargetM") private var targetM: Double = 400
    @AppStorage("indoorMode") private var indoor = false
    @State private var startLine: LinePoint?
    @State private var finishLine: LinePoint?
    @State private var finishMode: FinishMode = .lap

    enum FinishMode: String, CaseIterable, Identifiable {
        case lap, separate, manual
        var id: String { rawValue }
        var label: String {
            switch self {
            case .lap: return "Same as start (a lap of a track)"
            case .separate: return "A separate finish line"
            case .manual: return "I'll tap Finish myself"
            }
        }
    }

    private let distances: [Double] = [100, 200, 400, 600, 800, 1000, 1200]

    private var fix: LocationFix? { services.location.latestFix }
    private var canMark: Bool { services.location.hasFix }

    private var canGo: Bool {
        guard startLine != nil, services.location.isAuthorized, !indoor else { return false }
        return finishMode != .separate || finishLine != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Distance", selection: $targetM) {
                        ForEach(distances, id: \.self) { d in Text("\(Int(d)) m").tag(d) }
                    }
                } header: {
                    Text("Distance")
                } footer: {
                    Text(targetM < 200
                         ? "100 m measures top speed only. Style calls start at 200 m."
                         : "Style calls compare you with your own sprints at this distance, once you have three.")
                }

                Section {
                    lineRow(title: "Start line", point: startLine)
                    Button(startLine == nil ? "Mark start here" : "Mark start again") { startLine = currentPoint() }
                        .disabled(!canMark)
                } header: {
                    Text("Start")
                } footer: {
                    Text("Stand on the start line and let the GPS settle, then tap. \(accuracyNote)")
                }

                Section {
                    Picker("Finish", selection: $finishMode) {
                        ForEach(FinishMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    if finishMode == .separate {
                        lineRow(title: "Finish line", point: finishLine)
                        Button(finishLine == nil ? "Mark finish here" : "Mark finish again") { finishLine = currentPoint() }
                            .disabled(!canMark)
                        if let a = startLine, let b = finishLine {
                            let apart = Geo.haversineM(lat1: a.lat, lng1: a.lng, lat2: b.lat, lng2: b.lng)
                            Text("The marked lines are \(Int(apart.rounded())) m apart.")
                                .font(.callout)
                                .foregroundStyle(abs(apart - targetM) > targetM * 0.1 ? Color.orange : Color.secondary)
                        }
                    }
                } header: {
                    Text("Finish")
                } footer: {
                    Text(finishFooter)
                }

                Section {
                    Button {
                        go()
                    } label: {
                        Text("Ready")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canGo)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } footer: {
                    Text(indoor
                         ? "Turn off Indoor mode first: a sprint is timed between GPS-marked lines."
                         : "Go to the start line first. Recording starts there, then a spoken three, two, one, go. The clock runs from go.")
                }
            }
            .navigationTitle("Sprint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var accuracyNote: String {
        guard let f = fix, f.horizontalAccuracyM >= 0 else { return "No GPS signal yet." }
        // Never present an old position as where you are standing now.
        guard services.location.hasFix else { return "Waiting for a fresh GPS fix (last was ±\(Int(f.horizontalAccuracyM.rounded())) m)." }
        return "GPS is ±\(Int(f.horizontalAccuracyM.rounded())) m right now."
    }

    private var finishFooter: String {
        switch finishMode {
        case .lap: return "For a lap of a track: the finish is detected when you come back across the start line."
        case .separate: return "Walk to the finish line, mark it, then walk back to the start."
        case .manual: return "No marked finish: tap Finish on screen as you cross the line."
        }
    }

    private func lineRow(title: String, point: LinePoint?) -> some View {
        LabeledContent(title) {
            if let p = point {
                Label("Marked · ±\(Int(p.accuracyM.rounded())) m", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Text("Not marked").foregroundStyle(.secondary)
            }
        }
    }

    private func currentPoint() -> LinePoint? {
        guard let f = fix else { return nil }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return LinePoint(lat: f.lat, lng: f.lng, accuracyM: f.horizontalAccuracyM)
    }

    private func go() {
        guard let start = startLine else { return }
        let plan = SprintPlan(targetM: targetM, startLine: start,
                              finishLine: finishMode == .separate ? finishLine : nil,
                              lap: finishMode == .lap)
        dismiss()
        services.recorder.tapStart(indoor: indoor, intent: .push, sprint: plan,
                                   location: services.location, pedometer: services.pedometer,
                                   music: services.music, spotify: services.spotify, store: services.store)
    }
}

// MARK: - During the race

/// Replaces the running screen's numbers while a sprint is set up: the
/// countdown, then the race clock from the gate, then the result.
struct SprintRaceView: View {
    @Environment(AppServices.self) private var services
    let phase: RunRecorder.SprintPhase

    var body: some View {
        let r = services.recorder
        VStack(spacing: 18) {
            if let plan = r.sprintPlan {
                Text("Sprint · \(Int(plan.targetM)) m")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            switch phase {
            case .countdown(let n):
                Text("\(n)")
                    .font(.system(size: 140, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text("Get set").font(.title2)
            case .racing:
                TimelineView(.periodic(from: .now, by: 0.1)) { ctx in
                    Text(raceTime(ms: Int((ctx.date.timeIntervalSince(r.sprintGateDate ?? ctx.date)) * 1000)))
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                if let plan = r.sprintPlan {
                    Text("About \(Int(max(0, plan.targetM - r.sprintDistanceM).rounded())) m to go")
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(plan.finishLine != nil || plan.lap
                         ? "The finish is detected at the marked line."
                         : "Tap Finish as you cross the line.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    r.finishSprintManually()
                } label: {
                    Text("Finish")
                        .font(.title.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            case .finished(let ms, let method):
                Text(raceTime(ms: ms))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Label(method == "marked_line" ? "Crossed the marked line" : "Finish tapped",
                      systemImage: "flag.checkered")
                Text("Cool down as long as you like, then hold to end.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }
}

// MARK: - After the race

/// The sprint on the finish screen: time, 100 m splits, top speed, opening,
/// fade from the peak split, and the style call once there is own history.
struct SprintResultSection: View {
    let run: Run
    let history: [SprintAnalysis.Result]

    var body: some View {
        let target = Int(run.effort?.target.value ?? 0)
        Section {
            switch SprintAnalysis.analyze(run) {
            case .refused(let why):
                Label(refusalText(why), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            case .result(let res):
                resultRows(res, target: target)
            }
        } header: {
            Text("Sprint · \(target) m")
        } footer: {
            Text(footer)
        }
    }

    @ViewBuilder
    private func resultRows(_ res: SprintAnalysis.Result, target: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(raceTime(ms: res.timeMs))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
            Spacer()
            Text("\(target) m").foregroundStyle(.secondary)
        }
        if res.mode == .splits {
            SplitBars(splits: res.splits, peak: res.peakSplitIndex)
        }
        LabeledContent("Top speed",
                       value: String(format: "%.1f m/s · %.0f km/h", res.peakSampleSpeedMps, res.peakSampleSpeedMps * 3.6))
        if let o = res.openingMs {
            // Whole seconds only: at one fix per second, finer would be false precision.
            LabeledContent("Opening", value: o < 1000 ? "90% of top speed in under a second"
                                                       : "90% of top speed by \(Int((Double(o) / 1000).rounded())) s")
        }
        if let fade = res.fade {
            Text("Your last 100 m held \(Int((fade * 100).rounded()))% of your fastest 100 m.")
                .font(.callout)
        }
        styleRow(res, target: target)
    }

    @ViewBuilder
    private func styleRow(_ res: SprintAnalysis.Result, target: Int) -> some View {
        switch SprintStyle.call(res, history: history) {
        case .peakOnly:
            Text("100 m measures top speed. Style calls start at 200 m.")
                .font(.callout).foregroundStyle(.secondary)
        case .needsHistory(let have, let need):
            VStack(alignment: .leading, spacing: 4) {
                Text("No style call yet").font(.headline)
                Text("Sprint style is judged against your own \(target) m sprints, never against other runners. You have \(have) earlier; calls start at \(need).")
                    .font(.callout).foregroundStyle(.secondary)
            }
        case .style(let s, let usual, _):
            VStack(alignment: .leading, spacing: 4) {
                let article = "AEIOU".contains(s.englishName.first!) ? "an" : "a"
                (Text("You ran like \(article) ") + Text(s.englishName).bold() + Text(" this time."))
                Text("\(s.japaneseName) · Held \(Int(((res.fade ?? 0) * 100).rounded()))% of your peak; your usual is \(Int((usual * 100).rounded()))%.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var footer: String {
        let method = run.effort?.finish?.method
        let finish = method == "marked_line" ? "Finish detected at the marked line." : (method == "manual_tap" ? "Finish tapped by hand." : "")
        return "\(finish) The clock runs from the spoken go. Opening is ±1 s at one GPS fix per second."
    }

    private func refusalText(_ r: SprintAnalysis.Refusal) -> String {
        switch r {
        case .noEffort: return "No sprint in this run."
        case .noFinish: return "The sprint has no finish: the run ended before the line was crossed or Finish was tapped."
        case .tooShort: return "Too short to measure."
        case .notMultipleOf100: return "Splits need a distance in whole hundreds of metres."
        case .gpsGap(let s): return "GPS dropped for \(s) s during the sprint, so splits would be guesses."
        case .tooFewSamples: return "Too few GPS fixes during the sprint to measure it."
        case .noDoppler: return "The phone didn't report a reliable speed during the sprint."
        }
    }
}

/// One bar per 100 m, the fastest in orange, with each split's time.
private struct SplitBars: View {
    let splits: [SprintAnalysis.Split]
    let peak: Int

    var body: some View {
        let fastest = splits.map(\.speedMps).max() ?? 1
        let slowest = splits.map(\.speedMps).min() ?? 0
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(splits, id: \.index) { split in
                VStack(spacing: 4) {
                    Text(raceTime(ms: split.timeMs))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(split.index == peak ? Color.orange : Color.secondary.opacity(0.35))
                        .frame(height: barHeight(split.speedMps, fastest: fastest, slowest: slowest))
                    Text("\((split.index + 1) * 100)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 96, alignment: .bottom)
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Splits: " + splits.map { "\(($0.index + 1) * 100) metres in \(raceTime(ms: $0.timeMs))" }.joined(separator: ", "))
    }

    private func barHeight(_ v: Double, fastest: Double, slowest: Double) -> CGFloat {
        // Bars start from 80% of the slowest split so differences of a few
        // percent stay visible without pretending the floor is zero.
        let floor = slowest * 0.8
        guard fastest > floor else { return 40 }
        return CGFloat(16 + (v - floor) / (fastest - floor) * 44)
    }
}
