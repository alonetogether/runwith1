import AudioToolbox
import CoreLocation
import Observation
import RunCore
import UIKit

/// Owns one run session end to end: wires the sensor services into a
/// `RunBuilder`, exposes live numbers for the running screen, and saves the
/// finished `Run`.
@MainActor
@Observable
final class RunRecorder {
    enum State {
        case idle
        /// Start was tapped without a fix: waiting for the first one that
        /// passes. No point and no clock exist yet (Diagnostic §6.3).
        case arming(since: Date)
        case running
        /// The saved run's id. Views read the run from the store, so an
        /// annotation made on the finish screen is never shown stale.
        case finished(UUID)
    }

    private(set) var state: State = .idle
    private(set) var elapsedMs = 0
    private(set) var distanceM = 0.0
    private(set) var speedMps = 0.0
    private(set) var cadenceSpm: Double?
    private(set) var liveSource: PointSource?
    private(set) var acceptedPoints = 0
    private(set) var rejectedFixes = 0
    private(set) var lastRejectReason: RejectReason?
    private(set) var musicCount = 0
    private(set) var trace: [CLLocationCoordinate2D] = []

    /// An unfinished run left behind by a crash or a force-quit, offered on the gear check.
    private(set) var recovery: RunCheckpoint.Recovered?

    /// Accuracy of the latest fix while arming, so the wait is never a silent state.
    private(set) var armingAccuracyM: Double?

    // MARK: Sprint (line-to-line effort) state

    enum SprintPhase: Equatable {
        case countdown(Int)
        case racing
        case finished(timeMs: Int, method: String)
    }

    private(set) var sprintPhase: SprintPhase?
    private(set) var sprintPlan: SprintPlan?
    private(set) var sprintGateDate: Date?
    /// Distance since the gate from Doppler speed: approximate, for the
    /// "to go" cue only. The finish is the marked line.
    private(set) var sprintDistanceM: Double = 0
    private var pendingSprint: SprintPlan?
    private var countdownTimer: Timer?
    private var lastSprintT: Int?
    private var said100ToGo = false
    private var lapNotBeforeMs: Int?
    private var lapDirection: Double?
    private let announcer = Announcer()

    private var builder: RunBuilder?
    private var timer: Timer?
    private var armedAt: Date?
    private var pendingIntent: Reported<RunIntent>?
    private var preStartFixes: [LocationFix] = []
    private var sources: (location: LocationService, pedometer: PedometerService, music: MusicLogger, spotify: SpotifyService)?
    private let checkpoint = RunCheckpoint()
    private var lastCheckpointAt = Date.distantPast
    private static let checkpointEvery: TimeInterval = 30

    init() {
        recovery = checkpoint.loadLeftover()
    }

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    /// What Start does, decided by `ArmingPolicy`: record now, arm and wait
    /// for a fix, record on the step source, or nothing if blocked.
    func tapStart(indoor: Bool, intent: RunIntent?, sprint: SprintPlan? = nil, location: LocationService,
                  pedometer: PedometerService, music: MusicLogger, spotify: SpotifyService, store: RunStore) {
        guard case .idle = state else { return }
        let decision = ArmingPolicy.decide(indoor: indoor, locationAuthorized: location.isAuthorized,
                                           pedometerReady: pedometer.isReady, hasFix: location.hasFix,
                                           sprint: sprint != nil)
        pendingSprint = sprint
        if case .blocked = decision { return }
        // A leftover still pending: keep it as its own run before anything else
        // can write a checkpoint over it.
        if recovery != nil { keepRecovered(store: store) }
        let now = Date()
        pendingIntent = intent.map { Reported($0, at: now) }
        sources = (location, pedometer, music, spotify)
        switch decision {
        case .startNow, .startOnSteps:
            armedAt = nil
            begin(RunBuilder(startedAt: now, intent: pendingIntent),
                  location: location, pedometer: pedometer, music: music, spotify: spotify)
        case .arm:
            arm(location: location, at: now)
        case .blocked:
            break
        }
    }

    private func arm(location: LocationService, at now: Date) {
        armedAt = now
        preStartFixes = []
        armingAccuracyM = nil
        location.onFix = { [weak self] fix in self?.armingFix(fix) }
        // Run mode at the tap, not at the fix: a phone pocketed while searching
        // must keep receiving fixes with the screen off.
        location.startRun()
        UIApplication.shared.isIdleTimerDisabled = true
        state = .arming(since: now)
    }

    private func armingFix(_ fix: LocationFix) {
        guard case .arming = state, let src = sources else { return }
        armingAccuracyM = fix.horizontalAccuracyM
        guard fix.horizontalAccuracyM >= 0, fix.horizontalAccuracyM <= LocationService.usableAccuracyM else {
            preStartFixes.append(fix)
            return
        }
        // The clock starts at the first passing fix, which becomes point 0.
        var b = RunBuilder(startedAt: fix.timestamp, armedAt: armedAt, intent: pendingIntent)
        for f in preStartFixes { b.recordPreStartFix(f) }
        b.addFix(fix)
        begin(b, location: src.location, pedometer: src.pedometer, music: src.music, spotify: src.spotify)
    }

    /// The long-wait fallback: record on the step source now and let GPS take
    /// over when a fix arrives. Not Indoor, which would tag an outdoor run as proxy.
    func startOnStepsWhileArming() {
        guard case .arming = state, let src = sources else { return }
        var b = RunBuilder(startedAt: Date(), armedAt: armedAt, intent: pendingIntent)
        for f in preStartFixes { b.recordPreStartFix(f) }
        begin(b, location: src.location, pedometer: src.pedometer, music: src.music, spotify: src.spotify)
    }

    func cancelArming() {
        guard case .arming = state else { return }
        pendingSprint = nil
        sources?.location.onFix = nil
        sources?.location.stopRun()
        sources?.location.startWarmup()
        UIApplication.shared.isIdleTimerDisabled = false
        armedAt = nil
        pendingIntent = nil
        preStartFixes = []
        armingAccuracyM = nil
        state = .idle
    }

    /// Picks the unfinished run back up. GPS starts a fresh segment, so the
    /// time the app was closed is a gap in the trace, not an invented line.
    func resumeRecovered(location: LocationService, pedometer: PedometerService, music: MusicLogger, spotify: SpotifyService) {
        guard case .idle = state, var b = recovery?.builder else { return }
        b.resumeAfterGap()
        recovery = nil
        begin(b, location: location, pedometer: pedometer, music: music, spotify: spotify)
    }

    /// Keeps the unfinished run as it was at its last checkpoint and shows it.
    func saveRecovered(store: RunStore) {
        guard case .idle = state, let run = keepRecovered(store: store) else { return }
        state = .finished(run.id)
    }

    @discardableResult
    private func keepRecovered(store: RunStore) -> Run? {
        guard let rec = recovery else { return nil }
        let run = rec.builder.finish(at: rec.savedAt)
        store.save(run)
        checkpoint.close()
        recovery = nil
        return run
    }

    func discardRecovery() {
        checkpoint.close()
        recovery = nil
    }

    /// Writes the in-progress run now, e.g. when the app is about to go to the background.
    func checkpointNow() {
        guard isRunning, let b = builder else { return }
        checkpoint.save(b)
        lastCheckpointAt = Date()
    }

    private func begin(_ b: RunBuilder, location: LocationService, pedometer: PedometerService,
                       music: MusicLogger, spotify: SpotifyService) {
        builder = b
        trace = b.points.compactMap { p in
            guard let lat = p.lat, let lng = p.lng else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }

        location.onFix = { [weak self] fix in self?.ingest(fix) }
        pedometer.onSample = { [weak self] sample in self?.ingest(sample) }
        music.onTrack = { [weak self] track, date in
            self?.builder?.addMusic(track, source: MusicLogger.sourceName, at: date)
            self?.musicCount = self?.builder?.music.count ?? 0
        }
        spotify.onTrack = { [weak self] track, date in
            self?.builder?.addMusic(track, source: SpotifyService.sourceName, at: date)
            self?.musicCount = self?.builder?.music.count ?? 0
        }

        location.startRun()
        // Cumulative from the run's own start, so a resumed run keeps the steps taken during the gap.
        pedometer.start(from: b.startedAt)
        music.startLogging()
        spotify.startLogging()

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        UIApplication.shared.isIdleTimerDisabled = true
        state = .running
        preStartFixes = []
        armingAccuracyM = nil
        if let plan = pendingSprint, builder?.effort == nil {
            pendingSprint = nil
            startSprint(plan)
        }
        checkpoint.open()
        checkpointNow()
        refreshLive()
        announceRecording()
    }

    // MARK: Sprint

    /// Recording is running at the start line: attach the effort and count down.
    private func startSprint(_ plan: SprintPlan) {
        sprintPlan = plan
        let marked = { (p: LinePoint) in Sourced(p, source: "gps", fidelity: .measured, method: "user_marked") }
        builder?.effort = Effort(targetM: plan.targetM, startLine: marked(plan.startLine),
                                 finishLine: plan.finishLine.map(marked), lap: plan.lap)
        sprintDistanceM = 0
        said100ToGo = false
        lapNotBeforeMs = nil
        lapDirection = nil
        var remaining = 3
        sprintPhase = .countdown(remaining)
        announcer.say("Three")
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            Task { @MainActor in
                guard let self else { t.invalidate(); return }
                remaining -= 1
                if remaining > 0 {
                    self.sprintPhase = .countdown(remaining)
                    self.announcer.say(remaining == 2 ? "Two" : "One")
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } else {
                    t.invalidate()
                    self.openGate()
                }
            }
        }
    }

    private func runTimeMs(_ date: Date = Date()) -> Int {
        guard let b = builder else { return 0 }
        return Int((date.timeIntervalSince(b.startedAt) * 1000).rounded())
    }

    /// Gun time: the moment the app sounds the gate.
    private func openGate() {
        let now = Date()
        let t = runTimeMs(now)
        announcer.say("Go")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        builder?.effort?.gate = Sourced(t, source: "app", fidelity: .measured, method: "gate_sound")
        builder?.effort?.events.append(EffortEvent("gate_open", tMs: t))
        sprintGateDate = now
        lastSprintT = t
        sprintPhase = .racing
        checkpointNow()
    }

    /// Called for every accepted GPS point while racing.
    private func sprintIngest(_ p: RunPoint) {
        guard sprintPhase == .racing, let plan = sprintPlan, let gate = builder?.effort?.gate?.value else { return }
        if let last = lastSprintT, p.t > last {
            sprintDistanceM += (p.rawSpeedMps ?? p.speedMps) * Double(p.t - last) / 1000
        }
        lastSprintT = p.t

        if plan.targetM >= 200, !said100ToGo, sprintDistanceM >= plan.targetM - 100 {
            said100ToGo = true
            builder?.effort?.events.append(EffortEvent("to_go_100", tMs: p.t))
            announcer.say("One hundred to go")
        }

        // Finish on crossing the marked line; never on accumulated GPS distance.
        guard let points = builder?.points else { return }
        if plan.lap {
            if lapDirection == nil { lapDirection = LineCrossing.courseBearing(points, fromMs: gate) }
            // Only look for the finish once more than half the lap is behind.
            if lapNotBeforeMs == nil, sprintDistanceM >= plan.targetM / 2 { lapNotBeforeMs = p.t }
            if let dir = lapDirection, let notBefore = lapNotBeforeMs,
               let t = LineCrossing.crossingTime(points, line: plan.startLine, direction: dir, notBeforeMs: notBefore) {
                finishSprint(at: t, method: "marked_line", source: "gps")
            }
        } else if let finishLine = plan.finishLine {
            let dir = LineCrossing.bearing(from: plan.startLine, to: finishLine)
            if let t = LineCrossing.crossingTime(points, line: finishLine, direction: dir, notBeforeMs: gate) {
                finishSprint(at: t, method: "marked_line", source: "gps")
            }
        }
    }

    /// The runner taps Finish: no marked line, or the crossing was missed.
    func finishSprintManually() {
        guard sprintPhase == .racing else { return }
        finishSprint(at: runTimeMs(), method: "manual_tap", source: "user")
    }

    private func finishSprint(at t: Int, method: String, source: String) {
        guard sprintPhase == .racing, let gate = builder?.effort?.gate?.value else { return }
        builder?.effort?.finish = Sourced(t, source: source, fidelity: .estimated, method: method)
        builder?.effort?.events.append(EffortEvent("finish", tMs: t))
        sprintPhase = .finished(timeMs: t - gate, method: method)
        announcer.say("Finish")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        checkpointNow()
    }

    /// At save: both distances and the first-movement estimate, with provenance.
    private func completeEffort() {
        guard let e = builder?.effort, let gate = e.gate?.value, let finish = e.finish?.value,
              let points = builder?.points else { return }
        let d = EffortMeasure.distances(points, gateMs: gate, finishMs: finish)
        builder?.effort?.distanceGps = Sourced(d.gps, source: "gps", fidelity: .measured, method: "positions")
        builder?.effort?.distanceDoppler = Sourced(d.doppler, source: "gps", fidelity: .estimated, method: "doppler_integrated")
        if let first = EffortMeasure.firstMovementMs(points, gateMs: gate, finishMs: finish) {
            builder?.effort?.firstMovement = Sourced(first, source: "gps", fidelity: .estimated, method: "speed_over_1.5_mps")
        }
    }

    private func clearSprint() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        sprintPhase = nil
        sprintPlan = nil
        sprintGateDate = nil
        sprintDistanceM = 0
        pendingSprint = nil
        lastSprintT = nil
        lapNotBeforeMs = nil
        lapDirection = nil
    }

    /// A haptic and the system's record sound, so a pocketed phone tells you it
    /// started. The screen is kept awake while arming, so both still fire.
    private func announceRecording() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1113)
    }

    func stop(location: LocationService, pedometer: PedometerService, music: MusicLogger, spotify: SpotifyService, store: RunStore) {
        guard case .running = state, let b = builder else { return }
        timer?.invalidate()
        timer = nil
        location.stopRun()
        pedometer.stop()
        music.stopLogging()
        spotify.stopLogging()
        location.onFix = nil
        pedometer.onSample = nil
        music.onTrack = nil
        spotify.onTrack = nil
        UIApplication.shared.isIdleTimerDisabled = false

        completeEffort()
        clearSprint()
        let run = (builder ?? b).finish(at: Date())
        store.save(run)
        checkpoint.close()
        builder = nil
        state = .finished(run.id)
    }

    func reset() {
        state = .idle
        elapsedMs = 0
        distanceM = 0
        speedMps = 0
        cadenceSpm = nil
        liveSource = nil
        acceptedPoints = 0
        rejectedFixes = 0
        lastRejectReason = nil
        musicCount = 0
        trace = []
    }

    // MARK: Ingest

    private func ingest(_ fix: LocationFix) {
        guard isRunning, builder != nil else { return }
        let verdict = builder!.addFix(fix)
        if case .accepted(let p) = verdict {
            if let lat = p.lat, let lng = p.lng {
                trace.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
            }
            sprintIngest(p)
        }
        refreshLive()
    }

    private func ingest(_ sample: PedometerSample) {
        guard isRunning, builder != nil else { return }
        builder!.addPedometer(sample)
        refreshLive()
    }

    private func refreshLive() {
        guard let b = builder else { return }
        let now = Date()
        distanceM = b.distanceM
        cadenceSpm = b.latestCadenceSpm
        liveSource = b.liveSource(now: now)
        speedMps = liveSource == nil ? 0 : b.liveSpeedMps
        acceptedPoints = b.points.count
        rejectedFixes = b.rejectedFixes
        lastRejectReason = b.lastRejectReason
        musicCount = b.music.count
    }

    private func tick() {
        guard let b = builder else { return }
        let now = Date()
        elapsedMs = Int(now.timeIntervalSince(b.startedAt) * 1000)
        liveSource = b.liveSource(now: now)
        if liveSource == nil { speedMps = 0 }
        if now.timeIntervalSince(lastCheckpointAt) >= Self.checkpointEvery {
            checkpointNow()
        }
    }
}
