import RunCore
import SwiftUI

/// Pre-run readiness screen (diagnostic doc §6, capture brief §8): prime each
/// permission in context, confirm every source is live, state honestly what
/// this run will capture, and only then enable Start.
///
/// Two modes. Before the first saved run it educates: every source as a row
/// with what it adds and its own Enable button. Once a run exists it is one
/// invitation: a line about the last run, the intent chips, a large Start and
/// readiness as one live line that opens the full rows. It never re-explains.
struct GearCheckView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("indoorMode") private var indoor = false
    /// The last declared intent, remembered between runs; empty means none.
    @AppStorage("lastIntent") private var lastIntentRaw = ""
    @State private var showDetails = false
    @State private var confirmDiscard = false
    @State private var showSprintSetup = false

    /// Returning once a run has been saved: the baseline is earned by running,
    /// not by passing a setup.
    private var isReturning: Bool { !services.store.runs.isEmpty }
    private var expanded: Bool { !isReturning || showDetails }

    var body: some View {
        // No blanket timer: LocationService flips `hasFix` when GPS is gained or
        // goes stale, and that alone re-renders the readiness line.
        content
            .navigationTitle("Run With")
        .onAppear {
            services.location.startWarmup()
            services.music.beginObserving()
            services.spotify.beginObserving()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { services.location.startWarmup() }
        }
    }

    private var content: some View {
        List {
            if let rec = services.recorder.recovery {
                recoverySection(rec)
            }

            if expanded {
                detailSection
                startSection
            } else {
                invitationSection
            }

            if isReturning {
                Section("Recent runs") {
                    ForEach(services.store.runs.prefix(5)) { run in
                        NavigationLink(value: run.id) {
                            RunRow(run: run)
                        }
                    }
                }
            }
        }
        .animation(.default, value: expanded)
        .sheet(isPresented: $showSprintSetup) {
            SprintSetupView()
        }
        .navigationDestination(for: UUID.self) { id in
            if let run = services.store.runs.first(where: { $0.id == id }) {
                RunDetailView(run: run, isFresh: false)
            }
        }
    }

    // MARK: Sections

    /// A run the app did not get to finish: continue it, keep it, or let it go.
    private func recoverySection(_ rec: RunCheckpoint.Recovered) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("A run didn't finish saving").font(.headline)
                Text("Started \(rec.startedAt.formatted(date: .omitted, time: .shortened)) · \(PaceFormat.kilometres(rec.distanceM)) km recorded · last saved \(rec.savedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if rec.canContinue {
                Button("Continue this run") {
                    services.recorder.resumeRecovered(location: services.location, pedometer: services.pedometer,
                                                      music: services.music, spotify: services.spotify)
                }
                .bold()
            }
            Button("Save what was recorded") { services.recorder.saveRecovered(store: services.store) }
            Button("Discard", role: .destructive) { confirmDiscard = true }
        } footer: {
            Text("The app closed during a run. Everything up to its last save, at most 30 seconds before it closed, is kept.")
        }
        .confirmationDialog("Discard the unfinished run?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard run", role: .destructive) { services.recorder.discardRecovery() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }

    /// First run, or a returning runner who asked for details.
    private var detailSection: some View {
        Section {
            StatusRow(status: locationStatus)
            StatusRow(status: stepsStatus)
            StatusRow(status: musicStatus)
            if services.spotify.isConfigured || isReturning == false {
                StatusRow(status: spotifyStatus)
            }
            indoorToggle(withCaption: true)
            if isReturning {
                Button("Back to a glance") { showDetails = false }
                    .font(.callout)
            }
        } header: {
            Text("Gear check")
        } footer: {
            if !isReturning {
                Text("Here is what you have got. Phone-only is fine: Location is all a run needs. Steps add cadence, and distance on a treadmill. Music notes what was playing.")
            }
        }
    }

    private var intent: RunIntent? { RunIntent(rawValue: lastIntentRaw) }

    private var startButton: some View {
        Button {
            services.recorder.tapStart(indoor: indoor, intent: intent,
                                       location: services.location, pedometer: services.pedometer,
                                       music: services.music, spotify: services.spotify,
                                       store: services.store)
        } label: {
            Text("Start")
                .font(.title.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canStart)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    @ViewBuilder
    private var startNoteRow: some View {
        if let startNote {
            Text(startNote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Sprint is a protocol, not an intent: its own row, opening setup.
    private var sprintRow: some View {
        Button { showSprintSetup = true } label: {
            HStack {
                Label("Sprint: time a race between marked lines", systemImage: "stopwatch")
                    .font(.callout)
                    .foregroundStyle(.orange)
                Spacer()
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
        }
        .tint(.orange)
    }

    /// First launch: the capture line, the intent chips and Start under the educating rows.
    private var startSection: some View {
        Section {
            Text(captureSummary)
                .font(.callout)
                .foregroundStyle(.secondary)
            IntentChips(raw: $lastIntentRaw)
            sprintRow
            startButton
            startNoteRow
        }
    }

    /// Returning: one invitation. Descriptive, never graded (Idea Capture §23),
    /// and the readiness line stays live so a searching GPS is never hidden.
    private var invitationSection: some View {
        Section {
            if let last = services.store.runs.first {
                Text("Last time: \(last.startedAt.formatted(.dateTime.weekday(.wide))) · \(PaceFormat.kilometres(last.summary.distanceM)) km in \(PaceFormat.elapsed(ms: last.durationMs))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            IntentChips(raw: $lastIntentRaw)
            sprintRow
            startButton
            startNoteRow
            Button { showDetails = true } label: {
                HStack {
                    Text(readinessLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityHint("Shows each source in detail.")
            indoorToggle(withCaption: false)
        }
    }

    /// Every source in one line, e.g. "GPS ✓ · Steps off · Music … · Spotify ✓".
    private var readinessLine: String {
        var statuses = [locationStatus, stepsStatus, musicStatus]
        if services.spotify.isConfigured { statuses.append(spotifyStatus) }
        return statuses.map { st in
            switch st.state {
            case .ok: return "\(st.title) ✓"
            case .pending: return st.title == "GPS" ? "GPS searching" : "\(st.title) …"
            case .off: return "\(st.title) off"
            }
        }.joined(separator: " · ")
    }

    private func indoorToggle(withCaption: Bool) -> some View {
        Toggle(isOn: $indoor) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Indoor / treadmill")
                if withCaption {
                    Text("Distance from steps instead of GPS (proxy)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Status

    private var locationStatus: GearStatus {
        let loc = services.location
        if loc.isDenied {
            return GearStatus(icon: "location.slash", title: "Location", detail: "Denied. Allow it in Settings to track your route.",
                              state: .off, actionTitle: "Settings", action: openSettings)
        } else if !loc.isAuthorized {
            return GearStatus(icon: "location", title: "Location", detail: "Needed for route and pace.",
                              state: .off, actionTitle: "Enable", action: loc.requestPermission)
        } else if loc.hasFix, let fix = loc.latestFix {
            return GearStatus(icon: "location.fill", title: "GPS",
                              detail: "Fix acquired · ±\(Int(fix.horizontalAccuracyM.rounded())) m", state: .ok)
        } else {
            return GearStatus(icon: "location", title: "GPS",
                              detail: loc.lastError.map { "Searching… \($0)." } ?? "Searching for a fix…", state: .pending)
        }
    }

    private var stepsStatus: GearStatus {
        let ped = services.pedometer
        if !ped.isAvailable {
            return GearStatus(icon: "figure.walk", title: "Steps", detail: "Not available on this device.", state: .off)
        } else if ped.isDenied {
            return GearStatus(icon: "figure.walk", title: "Steps", detail: "Denied. Allow Motion in Settings for cadence.",
                              state: .off, actionTitle: "Settings", action: openSettings)
        } else if !ped.isAuthorized {
            return GearStatus(icon: "figure.walk", title: "Steps", detail: "Cadence, and distance indoors.",
                              state: .off, actionTitle: "Enable", action: ped.requestPermission)
        } else {
            return GearStatus(icon: "figure.run", title: "Steps", detail: "Step source ready.", state: .ok)
        }
    }

    private var musicStatus: GearStatus {
        let music = services.music
        if music.isDenied {
            return GearStatus(icon: "music.note", title: "Music", detail: "Not connected.", state: .off,
                              actionTitle: "Settings", action: openSettings)
        } else if !music.isAuthorized {
            return GearStatus(icon: "music.note", title: "Music", detail: "Logs title and artist only, from Apple Music.",
                              state: .off, actionTitle: "Connect", action: music.requestPermission)
        } else if let np = music.nowPlaying {
            return GearStatus(icon: "music.note", title: "Music",
                              detail: "\(music.isPlaying ? "Now playing" : "Paused"): \(np.title) — \(np.artist)", state: .ok)
        } else {
            return GearStatus(icon: "music.note", title: "Music", detail: "Connected · nothing playing.", state: .pending)
        }
    }

    private var spotifyStatus: GearStatus {
        let sp = services.spotify
        if !sp.isConfigured {
            return GearStatus(icon: "music.note.list", title: "Spotify",
                              detail: "Not in this build: it needs a Spotify client ID (see README).", state: .off)
        } else if sp.isConnecting {
            return GearStatus(icon: "music.note.list", title: "Spotify", detail: "Signing in…", state: .pending)
        } else if !sp.isConnected {
            return GearStatus(icon: "music.note.list", title: "Spotify",
                              detail: sp.lastError ?? "Logs title and artist of what Spotify plays, on any device.",
                              state: .off, actionTitle: "Connect", action: sp.connect)
        } else if let np = sp.nowPlaying {
            return GearStatus(icon: "music.note.list", title: "Spotify",
                              detail: "\(sp.isPlaying ? "Now playing" : "Paused"): \(np.title) — \(np.artist)", state: .ok)
        } else {
            return GearStatus(icon: "music.note.list", title: "Spotify",
                              detail: sp.lastError ?? "Connected · nothing playing.", state: .pending)
        }
    }

    // MARK: Logic

    private var startDecision: ArmingPolicy.Decision {
        ArmingPolicy.decide(indoor: indoor, locationAuthorized: services.location.isAuthorized,
                            pedometerReady: services.pedometer.isReady, hasFix: services.location.hasFix)
    }

    private var canStart: Bool {
        if case .blocked = startDecision { return false }
        return true
    }

    /// The one line under Start: why it is blocked, or what tapping it will do.
    private var startNote: String? {
        switch startDecision {
        case .blocked(.stepsUnavailable):
            return services.pedometer.isAvailable
                ? "Indoor mode needs the step source. Enable Steps above."
                : "Indoor mode needs a step counter, which this device does not have."
        case .blocked(.locationNotAuthorized):
            return "Enable Location to start."
        case .blocked(.sprintNeedsGPS):
            return "A sprint is timed between GPS-marked lines, so it can't run in Indoor mode."
        case .arm:
            return "GPS is still searching. Tap Start anyway: recording begins by itself when it locks."
        case .startNow, .startOnSteps:
            return nil
        }
    }

    private var captureSummary: String {
        var parts: [String] = []
        if services.location.isAuthorized { parts.append(indoor ? "pace (steps, proxy)" : "route and pace") }
        else if indoor && services.pedometer.isReady { parts.append("pace (steps, proxy)") }
        if services.pedometer.isReady { parts.append("cadence") }
        if services.music.isAuthorized || services.spotify.isConnected { parts.append("music") }
        if parts.isEmpty { return "Nothing is set up yet. Phone-only is fine: just enable Location." }
        let line = "This run captures: " + parts.joined(separator: ", ") + "."
        return (!isReturning && canStart) ? "You are set. " + line : line
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Pieces

/// Walk · Easy · Push, optional and remembered. A declaration stored with
/// the run as a self-report; tapping the selected chip clears it.
struct IntentChips: View {
    @Binding var raw: String

    var body: some View {
        HStack(spacing: 8) {
            Text("Today")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(RunIntent.allCases, id: \.self) { intent in
                let on = raw == intent.rawValue
                Button {
                    raw = on ? "" : intent.rawValue
                } label: {
                    Text(intent.label)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(on ? Color.orange : Color.orange.opacity(0.12), in: Capsule())
                        .foregroundStyle(on ? Color.white : Color.orange)
                }
                .buttonStyle(.borderless)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
    }
}

/// One source's readiness, shared by the detailed row and the glance chip.
struct GearStatus {
    enum State { case ok, pending, off }

    let icon: String
    let title: String
    let detail: String
    let state: State
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var tint: Color {
        switch state {
        case .ok: return .green
        case .pending: return .orange
        case .off: return .secondary
        }
    }

    var markIcon: String {
        switch state {
        case .ok: return "checkmark.circle.fill"
        case .pending: return "circle.dotted"
        case .off: return "circle"
        }
    }
}

struct StatusRow: View {
    let status: GearStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.icon)
                .frame(width: 24)
                .foregroundStyle(status.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.title).font(.body)
                Text(status.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let actionTitle = status.actionTitle, let action = status.action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Image(systemName: status.markIcon)
                    .foregroundStyle(status.tint)
            }
        }
    }
}

/// `GPS ✓` in a capsule, for the returning glance.
struct StatusChip: View {
    let status: GearStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
            Text(status.title)
            Image(systemName: status.markIcon)
                .font(.caption2)
        }
        .font(.caption.weight(.medium))
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(status.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(status.tint.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.title): \(status.detail)")
    }
}

struct RunRow: View {
    let run: Run

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(run.startedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
            HStack(spacing: 12) {
                Text("\(PaceFormat.kilometres(run.summary.distanceM)) km")
                Text(PaceFormat.elapsed(ms: run.durationMs))
                Text("\(PaceFormat.minPerKm(speedMps: run.summary.avgSpeedMps)) /km")
                if run.geoPoints.isEmpty { Text("indoor") }
                if let e = run.effort { Text("sprint \(Int(e.target.value)) m").foregroundStyle(.orange) }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
