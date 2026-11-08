import MapKit
import RunCore
import SwiftUI

/// Finish screen and history detail. Leads with how the run went and what
/// it noticed; the capture stats, exports and delete fold under Details.
/// Reads the run from the store by id, so an annotation shows immediately.
struct RunDetailView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    let run: Run
    let isFresh: Bool

    @State private var gpxURL: URL?
    @State private var confirmDelete = false
    @State private var showDetails = false

    /// The stored copy, which carries any annotation made since this view opened.
    private var current: Run { services.store.run(run.id) ?? run }

    private var coords: [CLLocationCoordinate2D] {
        current.geoPoints.compactMap { p in
            guard let lat = p.lat, let lng = p.lng else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }

    var body: some View {
        let run = current
        let style = StyleClassifier.classify(run)
        let moment = RunInsights.songHighlight(in: run)

        List {
            Section {
                hero(run)
            }

            Section {
                StyleRow(result: style)
            } header: {
                Text("This time")
            } footer: {
                Text("One run is weak evidence. A style is a tendency, and the label only firms up when it recurs across runs.")
            }

            if let moment {
                Section {
                    SongMomentRow(moment: moment)
                } footer: {
                    Text(moment.kind == .pickup
                         ? "An observation from the trace, not a cause. The minute after the song came on, against the minute before."
                         : "The best rolling minute of the run, and what was playing.")
                }
            }

            Section {
                FeelPicker(selected: run.annotations.currentFeel) { value in
                    services.store.annotate(run.id) { $0.recordFeel(value, at: Date()) }
                }
            } header: {
                Text("How did that feel?")
            } footer: {
                Text("Kept with the run as your own answer, never mixed with what was measured. Change it any time.")
            }

            Section {
                if coords.count >= 2 {
                    Map {
                        MapPolyline(coordinates: coords).stroke(.orange, lineWidth: 4)
                        Marker("Start", systemImage: "flag", coordinate: coords.first!).tint(.green)
                        Marker("Finish", systemImage: "flag.checkered", coordinate: coords.last!).tint(.red)
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .frame(height: 240)
                    .listRowInsets(EdgeInsets())
                } else {
                    Label("No map: this run had no GPS positions.", systemImage: "map")
                        .foregroundStyle(.secondary)
                }
            }

            if !run.music.isEmpty {
                Section("Music") {
                    ForEach(Array(run.music.enumerated()), id: \.offset) { _, entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.title)
                                Text([entry.artist, entry.genre, entry.bpm.map { "\(Int($0.rounded())) BPM" }]
                                        .compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(PaceFormat.elapsed(ms: entry.t))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                DisclosureGroup("Details", isExpanded: $showDetails) {
                    details(run)
                }
            }
        }
        .navigationTitle(isFresh ? "Run saved" : run.startedAt.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isFresh {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { services.recorder.reset() }
                }
            }
        }
        .navigationBarBackButtonHidden(isFresh)
        .task { gpxURL = try? services.store.gpxURL(for: current) }
        .confirmationDialog("Delete this run?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                services.store.delete(current)
                dismiss()
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    // MARK: Pieces

    private func hero(_ run: Run) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(PaceFormat.kilometres(run.summary.distanceM))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("km").font(.title3).foregroundStyle(.secondary)
                Spacer()
                if let intent = run.annotations.currentIntent {
                    Text(intent.label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                        .accessibilityLabel("You marked this as \(intent.label)")
                }
            }
            HStack(spacing: 18) {
                Label { Text(PaceFormat.elapsed(ms: run.durationMs)) } icon: {
                    Image(systemName: "clock").foregroundStyle(.secondary)
                }
                Label { Text("\(PaceFormat.minPerKm(speedMps: run.summary.avgSpeedMps)) /km") } icon: {
                    Image(systemName: "speedometer").foregroundStyle(.secondary)
                }
            }
            .font(.callout.monospacedDigit())
            Text(run.startedAt.formatted(date: .complete, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func details(_ run: Run) -> some View {
        LabeledContent("Moving time", value: PaceFormat.elapsed(ms: run.summary.movingTimeMs))
        LabeledContent("Max speed", value: String(format: "%.1f m/s", run.summary.maxSpeedMps))
        if let armed = run.armedAt {
            LabeledContent("Waited for GPS", value: PaceFormat.elapsed(ms: Int(run.startedAt.timeIntervalSince(armed) * 1000)))
        }
        let gps = run.points.filter { $0.source == .gps }.count
        let ped = run.points.filter { $0.source == .pedometer }.count
        // Fixes from before the clock started (while waiting for GPS) are not rejections.
        let rawFixes = run.rawStreams["gps_fixes"]?.samples.filter { ($0.first ?? nil).map { $0 >= 0 } ?? true }.count ?? 0
        LabeledContent("GPS points (measured)", value: "\(gps)")
        LabeledContent("Step points (proxy)", value: "\(ped)")
        LabeledContent("GPS fixes rejected", value: "\(max(0, rawFixes - gps))")
        LabeledContent("Raw streams", value: run.rawStreams.keys.sorted().joined(separator: ", ").ifEmpty("none"))
        LabeledContent("Schema", value: "v\(run.schemaVersion)")
        ShareLink(item: services.store.jsonURL(for: run)) {
            Label("Export JSON (Run object)", systemImage: "doc.text")
        }
        if let gpxURL {
            ShareLink(item: gpxURL) {
                Label("Export GPX", systemImage: "map")
            }
        }
        if !isFresh {
            Button("Delete run", role: .destructive) { confirmDelete = true }
        }
    }
}

extension RunIntent {
    var label: String {
        switch self {
        case .walk: return "Walk"
        case .easy: return "Easy"
        case .push: return "Push"
        }
    }
}

/// Five taps from rough to great. Each answer is appended, never overwritten.
struct FeelPicker: View {
    let selected: Int?
    let onPick: (Int) -> Void

    private let words = [1: "Rough", 2: "Hard", 3: "Okay", 4: "Good", 5: "Great"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onPick(value)
                } label: {
                    VStack(spacing: 4) {
                        Text("\(value)")
                            .font(.headline)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(value == selected ? Color.orange : Color.secondary.opacity(0.12)))
                            .foregroundStyle(value == selected ? Color.white : Color.primary)
                        Text(words[value] ?? "")
                            .font(.caption2)
                            .foregroundStyle(value == selected ? Color.primary : Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(words[value] ?? ""), \(value) of 5")
                .accessibilityAddTraits(value == selected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}

/// "You picked up when X came on" / "Your fastest minute came during X".
/// Phrased as an observation; the footer under it says so.
struct SongMomentRow: View {
    let moment: RunInsights.SongMoment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: moment.kind == .pickup ? "music.note" : "bolt.fill")
                .frame(width: 24)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var headline: AttributedString {
        var title = AttributedString(moment.song.title)
        title.font = .body.bold()
        switch moment.kind {
        case .pickup:
            return AttributedString("You picked up when ") + title + AttributedString(" came on.")
        case .fastestStretch:
            return AttributedString("Your fastest minute came during ") + title + AttributedString(".")
        }
    }

    private var detail: String {
        let pace = PaceFormat.minPerKm(speedMps: moment.speedMps)
        let proxy = moment.fidelity == .proxy ? " · pace from steps (proxy)" : ""
        switch moment.kind {
        case .pickup:
            let before = PaceFormat.minPerKm(speedMps: moment.beforeSpeedMps ?? 0)
            let pct = Int(((moment.deltaFraction ?? 0) * 100).rounded())
            return "\(before) /km → \(pace) /km, +\(pct)% · \(moment.song.artist) · at \(PaceFormat.elapsed(ms: moment.atMs))\(proxy)"
        case .fastestStretch:
            return "\(pace) /km · \(moment.song.artist) · ending at \(PaceFormat.elapsed(ms: moment.atMs))\(proxy)"
        }
    }
}

/// "You ran like a Late Surger this time", or an explained refusal, with the
/// four quarter bars so the shape is visible rather than asserted.
struct StyleRow: View {
    let result: StyleClassifier.Result

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: result.style == nil ? "questionmark.circle" : "figure.run")
                .frame(width: 24)
                .foregroundStyle(result.style == nil ? Color.secondary : .orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if result.quarterRatios.count == 4 {
                    QuarterBars(ratios: result.quarterRatios)
                        .padding(.top, 2)
                }
            }
        }
    }

    private var headline: AttributedString {
        switch result.outcome {
        case .style(let s):
            var name = AttributedString(s.englishName)
            name.font = .body.bold()
            let article = "AEIOU".contains(s.englishName.first!) ? "an " : "a "
            return AttributedString("You ran like \(article)") + name + AttributedString(" this time.")
        case .unclassified:
            return AttributedString("No style call this time.")
        }
    }

    private var detail: String {
        let adjusted = result.gradeAdjusted ? " Grade-adjusted for the hills." : ""
        switch result.outcome {
        case .style(let s):
            let r = result.quarterRatios
            let pct = { (x: Double) in "\(x >= 0 ? "+" : "")\(Int((x * 100).rounded()))%" }
            let shape: String
            switch s {
            case .frontRunner: shape = "First quarter \(pct(r[0] - 1)) against your average, last quarter \(pct(r[3] - 1))."
            case .paceChaser: shape = "Every quarter within \(Int((r.map { abs($0 - 1) }.max()! * 100).rounded()))% of your average."
            case .lateSurger: shape = "Third quarter \(pct(r[2] - 1)) against your average."
            case .endCloser: shape = "Last quarter \(pct(r[3] - 1)) against your average."
            }
            return "\(s.japaneseName) · \(shape)\(adjusted)"
        case .unclassified(let why):
            switch why {
            case .tooShort: return "Too short to read a shape. It needs about four minutes of clean running."
            case .flat: return "Every quarter sat within 1.5% of your average: even, but too flat to call.\(adjusted)"
            case .treadmill: return "Style needs a run where you set your own pace. A treadmill belt sets it for you."
            case .noDistance: return "No distance was recorded, so there are no quarters to compare."
            case .walk: return "You marked this as a walk. Style calls are for runs."
            case .sprint: return "This run holds a sprint, which gets its own call above."
            }
        }
    }
}

/// Four bars, one per distance quarter, around the run's own average.
private struct QuarterBars: View {
    let ratios: [Double]

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(ratios.enumerated()), id: \.offset) { i, r in
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(r >= 1 ? Color.orange : Color.secondary.opacity(0.35))
                        .frame(width: 22, height: max(4, CGFloat(12 + (r - 0.85) * 100)))
                    Text("Q\(i + 1)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(height: 44, alignment: .bottom)
        .accessibilityLabel("Quarter speeds relative to average: " + ratios.map { String(format: "%.0f%%", $0 * 100) }.joined(separator: ", "))
    }
}
