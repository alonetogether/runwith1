import Foundation

// MARK: - Inputs

/// A raw position fix, decoupled from CoreLocation so the cleaner is testable
/// on macOS and portable (brief §2).
public struct LocationFix: Codable, Equatable, Sendable {
    public var timestamp: Date
    public var lat: Double
    public var lng: Double
    /// Horizontal accuracy in metres; negative means the fix is invalid.
    public var horizontalAccuracyM: Double
    /// The source's own speed, or nil if the source did not supply a valid one.
    public var speedMps: Double?
    public var altitudeM: Double?
    public var verticalAccuracyM: Double?

    public init(timestamp: Date, lat: Double, lng: Double, horizontalAccuracyM: Double,
                speedMps: Double? = nil, altitudeM: Double? = nil, verticalAccuracyM: Double? = nil) {
        self.timestamp = timestamp
        self.lat = lat
        self.lng = lng
        self.horizontalAccuracyM = horizontalAccuracyM
        self.speedMps = speedMps
        self.altitudeM = altitudeM
        self.verticalAccuracyM = verticalAccuracyM
    }
}

/// A step-counter update (CMPedometer-shaped), decoupled from Core Motion.
public struct PedometerSample: Equatable, Sendable {
    public var timestamp: Date
    public var steps: Int
    /// Cumulative distance since the pedometer query started, if the device estimates it.
    public var cumulativeDistanceM: Double?
    /// Seconds per metre, if available.
    public var paceSPerM: Double?
    /// Steps per second, if available.
    public var cadenceStepsPerS: Double?

    public init(timestamp: Date, steps: Int, cumulativeDistanceM: Double?, paceSPerM: Double?, cadenceStepsPerS: Double?) {
        self.timestamp = timestamp
        self.steps = steps
        self.cumulativeDistanceM = cumulativeDistanceM
        self.paceSPerM = paceSPerM
        self.cadenceStepsPerS = cadenceStepsPerS
    }
}

// MARK: - Config

public struct CleanerConfig: Codable, Equatable, Sendable {
    /// Fixes worse than this are junk and never enter the series.
    public var maxHorizontalAccuracyM: Double = 30
    /// Anything faster than a world-record sprint is a GPS jump, not a runner.
    public var maxPlausibleSpeedMps: Double = 12.5
    /// Below this the runner is treated as stopped: no distance, no moving time.
    public var stoppedSpeedMps: Double = 0.5
    /// Time constant of the exponential smoothing applied to speed.
    public var smoothingTimeConstantS: Double = 3.0
    /// Fixes closer together than this are duplicates/bursts and are skipped.
    public var minDtS: Double = 0.2
    /// Elevation is only stored when the vertical accuracy is at least this good.
    public var maxVerticalAccuracyM: Double = 20
    /// After this long without an accepted fix, GPS is considered stale and the
    /// step source takes over as the live speed/distance source.
    public var gpsStaleAfterS: Double = 5

    public init() {}
}

// MARK: - GPS cleaner

public enum RejectReason: String, Codable, Equatable, Sendable {
    case poorAccuracy
    case nonMonotonicTime
    case tooSoon
    case implausibleJump
}

public enum CleanerVerdict: Equatable, Sendable {
    case accepted(RunPoint)
    case rejected(RejectReason)
}

/// The one real cleaning algorithm (brief §4): accuracy-gate junk, prefer the
/// source's own speed when sane else derive from haversine/dt, smooth,
/// accumulate distance from accepted points only, exclude stopped segments
/// from moving time. Incremental so the live UI and offline replay share it.
public struct SpeedCleaner: Codable, Sendable {
    public let config: CleanerConfig
    public let startedAt: Date

    public private(set) var distanceM: Double = 0
    public private(set) var movingTimeMs: Int = 0
    public private(set) var smoothedSpeedMps: Double = 0
    public private(set) var acceptedCount = 0
    public private(set) var rejectedCount = 0

    private var lastFix: LocationFix?

    public init(startedAt: Date, config: CleanerConfig = CleanerConfig()) {
        self.startedAt = startedAt
        self.config = config
    }

    public mutating func process(_ fix: LocationFix, cadenceSpm: Double? = nil) -> CleanerVerdict {
        guard fix.horizontalAccuracyM >= 0, fix.horizontalAccuracyM <= config.maxHorizontalAccuracyM else {
            return reject(.poorAccuracy)
        }
        let tMs = Int((fix.timestamp.timeIntervalSince(startedAt) * 1000).rounded())
        guard tMs >= 0 else { return reject(.nonMonotonicTime) }

        let elevation: Double? = {
            guard let alt = fix.altitudeM else { return nil }
            if let va = fix.verticalAccuracyM, va < 0 || va > config.maxVerticalAccuracyM { return nil }
            return alt
        }()

        guard let last = lastFix else {
            let raw = sanitizedSourceSpeed(fix.speedMps) ?? 0
            smoothedSpeedMps = raw
            lastFix = fix
            acceptedCount += 1
            let p = RunPoint(t: tMs, lat: fix.lat, lng: fix.lng, accuracyM: fix.horizontalAccuracyM,
                             rawSpeedMps: raw, speedMps: raw, distanceM: 0, cadenceSpm: cadenceSpm,
                             elevationM: elevation, source: .gps, fidelity: .measured)
            return .accepted(p)
        }

        let dt = fix.timestamp.timeIntervalSince(last.timestamp)
        guard dt > 0 else { return reject(.nonMonotonicTime) }
        guard dt >= config.minDtS else { return reject(.tooSoon) }

        let segmentM = Geo.haversineM(lat1: last.lat, lng1: last.lng, lat2: fix.lat, lng2: fix.lng)
        let derived = segmentM / dt
        guard derived <= config.maxPlausibleSpeedMps else { return reject(.implausibleJump) }

        let raw = sanitizedSourceSpeed(fix.speedMps) ?? derived
        let alpha = 1 - exp(-dt / config.smoothingTimeConstantS)
        smoothedSpeedMps += alpha * (raw - smoothedSpeedMps)

        if raw >= config.stoppedSpeedMps {
            distanceM += segmentM
            movingTimeMs += Int((dt * 1000).rounded())
        }

        lastFix = fix
        acceptedCount += 1
        let p = RunPoint(t: tMs, lat: fix.lat, lng: fix.lng, accuracyM: fix.horizontalAccuracyM,
                         rawSpeedMps: raw, speedMps: smoothedSpeedMps, distanceM: distanceM,
                         cadenceSpm: cadenceSpm, elevationM: elevation, source: .gps, fidelity: .measured)
        return .accepted(p)
    }

    /// After a gap in recording (a resume after the app was killed), the next
    /// fix starts a fresh segment: no straight line is drawn across the gap and
    /// the gap adds no distance or moving time. Honest hole over invented data.
    public mutating func forgetLastFix() {
        lastFix = nil
    }

    private func sanitizedSourceSpeed(_ s: Double?) -> Double? {
        guard let s, s >= 0, s <= config.maxPlausibleSpeedMps else { return nil }
        return s
    }

    private mutating func reject(_ r: RejectReason) -> CleanerVerdict {
        rejectedCount += 1
        return .rejected(r)
    }
}

// MARK: - Run builder (source arbitration + raw streams + finish)

/// Owns one in-progress run: feeds GPS fixes through the cleaner, falls back to
/// the step source when GPS goes stale, keeps raw streams wider than v1
/// interprets (brief §11), and produces the final `Run`.
/// Codable so an in-progress run can be checkpointed to disk and resumed
/// after the app is killed (competitive doc §3.4: never lose a run to a crash).
public struct RunBuilder: Codable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let config: CleanerConfig

    public private(set) var points: [RunPoint] = []
    public private(set) var music: [MusicEntry] = []
    public private(set) var distanceM: Double = 0
    public private(set) var movingTimeMs: Int = 0
    public private(set) var maxSpeedMps: Double = 0
    public private(set) var latestCadenceSpm: Double?
    public private(set) var lastGPSAcceptedAt: Date?
    public private(set) var rejectedFixes = 0
    public private(set) var lastRejectReason: RejectReason?

    private var cleaner: SpeedCleaner
    private var cleanerDistanceSeen: Double = 0
    private var cleanerMovingSeen = 0

    private var pedPrevDistance: Double?
    private var pedPrevTimestamp: Date?
    private var pedSmoothedSpeed: Double = 0

    private var gpsRaw: [[Double?]] = []
    private var pedRaw: [[Double?]] = []

    /// When Start was tapped, if recording waited for a fix. Optional with a
    /// default so checkpoints written by older builds still decode.
    public private(set) var armedAt: Date? = nil
    /// The intent the runner declared at Start, if any.
    public private(set) var intent: Reported<RunIntent>? = nil

    public init(id: UUID = UUID(), startedAt: Date, config: CleanerConfig = CleanerConfig(),
                armedAt: Date? = nil, intent: Reported<RunIntent>? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.config = config
        self.armedAt = armedAt
        self.intent = intent
        self.cleaner = SpeedCleaner(startedAt: startedAt, config: config)
    }

    public var liveSpeedMps: Double { points.last?.speedMps ?? 0 }

    /// Call when recording restarts after a gap. GPS starts a fresh segment.
    /// The step counter is left alone: CMPedometer reports cumulative totals
    /// from the run's start, so steps taken during the gap are still measured.
    public mutating func resumeAfterGap() {
        cleaner.forgetLastFix()
        lastGPSAcceptedAt = nil
    }

    /// Which source is currently producing the speed/distance series, if any.
    public func liveSource(now: Date) -> PointSource? {
        if let last = lastGPSAcceptedAt, now.timeIntervalSince(last) <= config.gpsStaleAfterS {
            return .gps
        }
        if pedPrevDistance != nil { return .pedometer }
        return nil
    }

    private func ms(_ date: Date) -> Double {
        (date.timeIntervalSince(startedAt) * 1000).rounded()
    }

    @discardableResult
    public mutating func addFix(_ fix: LocationFix) -> CleanerVerdict {
        gpsRaw.append([ms(fix.timestamp), fix.lat, fix.lng, fix.horizontalAccuracyM, fix.speedMps, fix.altitudeM])
        let verdict = cleaner.process(fix, cadenceSpm: latestCadenceSpm)
        switch verdict {
        case .accepted(var p):
            let dDist = cleaner.distanceM - cleanerDistanceSeen
            let dMove = cleaner.movingTimeMs - cleanerMovingSeen
            cleanerDistanceSeen = cleaner.distanceM
            cleanerMovingSeen = cleaner.movingTimeMs
            distanceM += dDist
            movingTimeMs += dMove
            p.distanceM = distanceM
            maxSpeedMps = max(maxSpeedMps, p.speedMps)
            points.append(p)
            lastGPSAcceptedAt = fix.timestamp
            return .accepted(p)
        case .rejected(let reason):
            rejectedFixes += 1
            lastRejectReason = reason
            return verdict
        }
    }

    /// Keeps a fix that arrived while waiting for GPS to settle, before the
    /// run's clock started: raw stream only (negative `t_ms`), never a point.
    public mutating func recordPreStartFix(_ fix: LocationFix) {
        gpsRaw.append([ms(fix.timestamp), fix.lat, fix.lng, fix.horizontalAccuracyM, fix.speedMps, fix.altitudeM])
    }

    /// Always consumes the sample (cadence, raw stream, distance bookkeeping);
    /// only emits a point when GPS is not the live source.
    public mutating func addPedometer(_ s: PedometerSample) {
        pedRaw.append([ms(s.timestamp), Double(s.steps), s.cumulativeDistanceM, s.paceSPerM, s.cadenceStepsPerS])
        if let c = s.cadenceStepsPerS { latestCadenceSpm = c * 60 }

        defer {
            if let d = s.cumulativeDistanceM { pedPrevDistance = d }
            pedPrevTimestamp = s.timestamp
        }

        if liveSource(now: s.timestamp) == .gps { return }
        guard let dist = s.cumulativeDistanceM, let prev = pedPrevDistance, let prevT = pedPrevTimestamp else { return }
        let dt = s.timestamp.timeIntervalSince(prevT)
        guard dt > 0 else { return }

        let delta = max(0, dist - prev)
        let raw: Double
        if let pace = s.paceSPerM, pace > 0 {
            raw = 1 / pace
        } else {
            raw = delta / dt
        }
        let alpha = 1 - exp(-dt / config.smoothingTimeConstantS)
        pedSmoothedSpeed += alpha * (raw - pedSmoothedSpeed)

        if raw >= config.stoppedSpeedMps {
            distanceM += delta
            movingTimeMs += Int((dt * 1000).rounded())
        }
        maxSpeedMps = max(maxSpeedMps, pedSmoothedSpeed)

        let p = RunPoint(t: Int(ms(s.timestamp)), lat: nil, lng: nil, accuracyM: nil,
                         rawSpeedMps: raw, speedMps: pedSmoothedSpeed, distanceM: distanceM,
                         cadenceSpm: latestCadenceSpm, elevationM: nil,
                         source: .pedometer, fidelity: .proxy)
        points.append(p)
    }

    /// Embodiment-gated by construction: only called for a track that was
    /// actually playing during the run.
    public mutating func addMusic(title: String, artist: String, source: String, at date: Date) {
        addMusic(PlayingTrack(title: title, artist: artist), source: source, at: date)
    }

    public mutating func addMusic(_ track: PlayingTrack, source: String, at date: Date) {
        let entry = MusicEntry(t: Int(ms(date)), track: track, source: source)
        if music.last.map({ $0.title == entry.title && $0.artist == entry.artist }) == true { return }
        music.append(entry)
    }

    public func finish(at end: Date) -> Run {
        let durationMs = Int(ms(end))
        let avg = movingTimeMs > 0 ? distanceM / (Double(movingTimeMs) / 1000) : 0
        var streams: [String: RawStream] = [:]
        if !gpsRaw.isEmpty {
            streams["gps_fixes"] = RawStream(source: "gps", fidelity: .measured,
                                             fields: ["t_ms", "lat", "lng", "accuracy_m", "speed_mps", "altitude_m"],
                                             samples: gpsRaw)
        }
        if !pedRaw.isEmpty {
            streams["pedometer"] = RawStream(source: "pedometer", fidelity: .proxy,
                                             fields: ["t_ms", "steps", "distance_m", "pace_s_per_m", "cadence_steps_per_s"],
                                             samples: pedRaw)
        }
        return Run(id: id, startedAt: startedAt, endedAt: end, durationMs: durationMs,
                   points: points, music: music,
                   summary: RunSummary(distanceM: distanceM, avgSpeedMps: avg, maxSpeedMps: maxSpeedMps, movingTimeMs: movingTimeMs),
                   rawStreams: streams, armedAt: armedAt,
                   annotations: RunAnnotations(intent: intent.map { [$0] } ?? []))
    }
}
