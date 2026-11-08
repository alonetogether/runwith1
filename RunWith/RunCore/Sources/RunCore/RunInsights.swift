import Foundation

/// Post-run observations that need nothing but the saved Run. Deterministic
/// code over the cleaned trace; it narrates nothing and claims no cause.
///
/// The one insight here ties the music log to the speed curve:
/// - **pickup**: the minute after a song came on was clearly faster than the
///   minute before it. The stronger claim, so it carries the honesty rails
///   (not the first song, not after a stop, not downhill, not within noise).
/// - **fastest stretch**: the best rolling minute of the run fell inside a
///   song. Always true when it fires; says less.
public enum RunInsights {
    public struct SongMoment: Equatable, Sendable {
        public enum Kind: Equatable, Sendable { case pickup, fastestStretch }

        public let kind: Kind
        public let song: MusicEntry
        /// Mean speed in the minute the claim is about (after the song came
        /// on, or the fastest minute).
        public let speedMps: Double
        /// Pickup only: mean speed in the minute before the song came on.
        public let beforeSpeedMps: Double?
        /// Where in the run the minute ends, ms since start.
        public let atMs: Int
        /// `.proxy` when any sample in the minute came from the step counter.
        public let fidelity: Fidelity

        public var deltaFraction: Double? {
            guard let before = beforeSpeedMps, before > 0 else { return nil }
            return (speedMps - before) / before
        }
    }

    public struct Config: Sendable {
        public var windowMs = 60_000
        /// Reaction time between the song starting and the "after" minute.
        public var reactionMs = 10_000
        /// A song has to have played this long to be credited at all.
        public var minSongPlayMs = 90_000
        /// Pickup threshold: both must hold.
        public var minPickupFraction = 0.08
        public var minPickupMps = 0.15
        /// Below this mean speed the "before" minute counts as a stop, not a baseline.
        public var minBeforeSpeedMps = 1.0
        /// Metres of extra descent in the after minute that disqualify a pickup.
        public var maxExtraDescentM = 3.0
        /// A window needs this much of its span covered by samples.
        public var minCoverage = 0.6

        public init() {}
    }

    /// The one line worth saying about this run's music, if any: a pickup
    /// when there is one, else the fastest stretch.
    public static func songHighlight(in run: Run, config: Config = Config()) -> SongMoment? {
        pickup(in: run, config: config) ?? fastestStretch(in: run, config: config)
    }

    // MARK: Pickup

    public static func pickup(in run: Run, config: Config = Config()) -> SongMoment? {
        let segments = songSegments(in: run)
        guard segments.count >= 2 else { return nil }
        var best: SongMoment?
        // Never the first song: they were fresh anyway.
        for seg in segments.dropFirst() where seg.playedMs >= config.minSongPlayMs {
            guard seg.start >= config.windowMs else { continue }
            let before = window(run.points, from: seg.start - config.windowMs, to: seg.start, config: config)
            let afterStart = seg.start + config.reactionMs
            let after = window(run.points, from: afterStart, to: afterStart + config.windowMs, config: config)
            guard let before, let after else { continue }
            guard before.meanSpeed >= config.minBeforeSpeedMps else { continue }
            let delta = after.meanSpeed - before.meanSpeed
            guard delta >= config.minPickupMps, delta / before.meanSpeed >= config.minPickupFraction else { continue }
            if let eb = before.elevationChange, let ea = after.elevationChange,
               (eb - ea) >= config.maxExtraDescentM {
                continue   // the after minute ran downhill; the song gets no credit
            }
            let moment = SongMoment(kind: .pickup, song: seg.entry, speedMps: after.meanSpeed,
                                    beforeSpeedMps: before.meanSpeed, atMs: afterStart + config.windowMs,
                                    fidelity: before.proxy || after.proxy ? .proxy : .measured)
            if let b = best, let bd = b.deltaFraction, let md = moment.deltaFraction, bd >= md { continue }
            best = moment
        }
        return best
    }

    // MARK: Fastest stretch

    public static func fastestStretch(in run: Run, config: Config = Config()) -> SongMoment? {
        let segments = songSegments(in: run).filter { $0.playedMs >= config.minSongPlayMs }
        guard !segments.isEmpty, !run.points.isEmpty else { return nil }
        var best: (speed: Double, end: Int, proxy: Bool)?
        // Slide a window ending at each sample; samples are ~1 s apart so this is cheap.
        for p in run.points where p.t >= config.windowMs {
            guard let w = window(run.points, from: p.t - config.windowMs, to: p.t, config: config) else { continue }
            if best == nil || w.meanSpeed > best!.speed {
                best = (w.meanSpeed, p.t, w.proxy)
            }
        }
        guard let best, best.speed > 0 else { return nil }
        let mid = best.end - config.windowMs / 2
        guard let seg = segments.first(where: { $0.start <= mid && mid < $0.end }) else { return nil }
        return SongMoment(kind: .fastestStretch, song: seg.entry, speedMps: best.speed, beforeSpeedMps: nil,
                          atMs: best.end, fidelity: best.proxy ? .proxy : .measured)
    }

    // MARK: Pieces

    struct Segment {
        let entry: MusicEntry; let start: Int; let end: Int
        /// Played time when the log says (v6), else the span.
        var playedMs: Int { entry.playedMs ?? (end - start) }
    }

    /// Each song's span. v6 entries carry their own estimated start and end
    /// (Spotify's are corrected from up to 10 s of poll lag); older entries
    /// run from first sight to the next entry, or the end of the run.
    static func songSegments(in run: Run) -> [Segment] {
        let entries = run.music.sorted { ($0.startedT ?? $0.t) < ($1.startedT ?? $1.t) }
        return entries.enumerated().map { i, e in
            let start = max(0, e.startedT ?? e.t)
            let next = i + 1 < entries.count ? max(0, entries[i + 1].startedT ?? entries[i + 1].t) : nil
            let end = e.endedT ?? next ?? max(run.durationMs, start)
            return Segment(entry: e, start: start, end: max(end, start))
        }
    }

    struct Window { let meanSpeed: Double; let proxy: Bool; let elevationChange: Double? }

    /// Time-weighted mean speed over [from, to), or nil when too little of the
    /// span is covered by samples.
    static func window(_ points: [RunPoint], from: Int, to: Int, config: Config) -> Window? {
        guard to > from else { return nil }
        let inside = points.filter { $0.t >= from && $0.t < to }
        guard inside.count >= 2 else { return nil }
        var weighted = 0.0, covered = 0
        for (i, p) in inside.enumerated() {
            let next = i + 1 < inside.count ? inside[i + 1].t : to
            let dt = min(max(next - p.t, 0), 5_000)   // a gap longer than 5 s is not coverage
            weighted += p.speedMps * Double(dt)
            covered += dt
        }
        guard Double(covered) / Double(to - from) >= config.minCoverage, covered > 0 else { return nil }
        let elev: Double?
        if let first = inside.first?.elevationM, let last = inside.last?.elevationM {
            elev = last - first
        } else {
            elev = nil
        }
        return Window(meanSpeed: weighted / Double(covered),
                      proxy: inside.contains { $0.fidelity == .proxy },
                      elevationChange: elev)
    }
}
