import Foundation

// MARK: - Provenance

/// Where a sample's speed/distance came from (brief §3, §4).
public enum PointSource: String, Codable, Sendable {
    case gps
    case pedometer
    case fused
}

/// How much to trust the number (brief §3 "every point carries source + fidelity").
public enum Fidelity: String, Codable, Sendable {
    case measured
    case proxy
    case estimated
    /// The runner said so: a self-report, never a sensor reading.
    case reported
}

// MARK: - Run object (schema_version 6)

/// One cleaned, provenance-tagged sample. `speedMps` is the stored truth;
/// pace is a display transform and is never stored.
public struct RunPoint: Codable, Equatable, Sendable {
    /// Milliseconds since `Run.startedAt`.
    public var t: Int
    public var lat: Double?
    public var lng: Double?
    /// GPS horizontal accuracy in metres; nil for non-GPS points.
    public var accuracyM: Double?
    /// The source's own speed before smoothing, kept so cleaning is inspectable.
    public var rawSpeedMps: Double?
    /// Cleaned/smoothed speed — THE stored truth.
    public var speedMps: Double
    /// Cumulative distance from accepted samples only.
    public var distanceM: Double
    public var cadenceSpm: Double?
    public var elevationM: Double?
    public var source: PointSource
    public var fidelity: Fidelity

    public init(t: Int, lat: Double?, lng: Double?, accuracyM: Double?, rawSpeedMps: Double?,
                speedMps: Double, distanceM: Double, cadenceSpm: Double?, elevationM: Double?,
                source: PointSource, fidelity: Fidelity) {
        self.t = t
        self.lat = lat
        self.lng = lng
        self.accuracyM = accuracyM
        self.rawSpeedMps = rawSpeedMps
        self.speedMps = speedMps
        self.distanceM = distanceM
        self.cadenceSpm = cadenceSpm
        self.elevationM = elevationM
        self.source = source
        self.fidelity = fidelity
    }

    enum CodingKeys: String, CodingKey {
        case t, lat, lng
        case accuracyM = "accuracy_m"
        case rawSpeedMps = "raw_speed_mps"
        case speedMps = "speed_mps"
        case distanceM = "distance_m"
        case cadenceSpm = "cadence_spm"
        case elevationM = "elevation_m"
        case source, fidelity
    }

    // Explicit nulls on purpose: an indoor point should read `"lat": null`,
    // not silently omit the key. Decoding stays synthesized.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(t, forKey: .t)
        try c.encode(lat, forKey: .lat)
        try c.encode(lng, forKey: .lng)
        try c.encode(accuracyM, forKey: .accuracyM)
        try c.encode(rawSpeedMps, forKey: .rawSpeedMps)
        try c.encode(speedMps, forKey: .speedMps)
        try c.encode(distanceM, forKey: .distanceM)
        try c.encode(cadenceSpm, forKey: .cadenceSpm)
        try c.encode(elevationM, forKey: .elevationM)
        try c.encode(source, forKey: .source)
        try c.encode(fidelity, forKey: .fidelity)
    }
}

/// Metadata only — never audio (brief §5). Identity and attributes are
/// captured at log time when the player exposes them (schema v3), so that
/// songs, artists, genres and tempos can be related to performance over
/// time. Anything the player did not say is an explicit null.
public struct MusicEntry: Codable, Equatable, Sendable {
    public var t: Int
    public var title: String
    public var artist: String
    public var source: String
    public var album: String?
    /// International Standard Recording Code: the same recording across services.
    public var isrc: String?
    /// The provider's own identifier (Spotify track id, Apple Music store id).
    public var trackID: String?
    public var genre: String?
    public var durationMs: Int?
    public var bpm: Double?

    // Schema v6: how the song was played, derived from raw sightings, and
    // artwork pointers. All optional: null means unknown, never zero, and
    // entries from v2–v5 files decode with every one of these nil.

    /// Estimated run time the track began (`t` minus its progress at first
    /// sight). Negative when it was already playing at Start. `t` keeps its
    /// old meaning: the moment the app first saw the track.
    public var startedT: Int?
    /// When it stopped being the current track, or the run ended.
    public var endedT: Int?
    /// Time audibly playing inside the run; playback pauses excluded. A fact,
    /// not a verdict: whether that counts as "listened" is decided later.
    public var playedMs: Int?
    /// How the song stopped being current.
    public var end: MusicEnd?
    /// One fidelity and method for all of this entry's times, since they share
    /// one connector: Spotify polls are estimates, Apple Music is local.
    public var timingFidelity: Fidelity?
    public var timingMethod: String?
    /// A pointer to cover art (Spotify), never the image itself.
    public var artworkURL: String?
    public var albumID: String?
    public var artistID: String?
    /// Raw song-position sightings, so every derived field above can be
    /// recomputed if the estimator changes, and run time maps to song time
    /// through seeks.
    public var sightings: [MusicSighting]?

    public init(t: Int, title: String, artist: String, source: String,
                album: String? = nil, isrc: String? = nil, trackID: String? = nil,
                genre: String? = nil, durationMs: Int? = nil, bpm: Double? = nil) {
        self.t = t
        self.title = title
        self.artist = artist
        self.source = source
        self.album = album
        self.isrc = isrc
        self.trackID = trackID
        self.genre = genre
        self.durationMs = durationMs
        self.bpm = bpm
    }

    public init(t: Int, track: PlayingTrack, source: String) {
        self.init(t: t, title: track.title, artist: track.artist, source: source, album: track.album,
                  isrc: track.isrc, trackID: track.trackID, genre: track.genre,
                  durationMs: track.durationMs, bpm: track.bpm)
        artworkURL = track.artworkURL
        albumID = track.albumID
        artistID = track.artistID
    }

    enum CodingKeys: String, CodingKey {
        case t, title, artist, source, album, isrc, genre, bpm, end, sightings
        case trackID = "track_id"
        case durationMs = "duration_ms"
        case startedT = "started_t"
        case endedT = "ended_t"
        case playedMs = "played_ms"
        case timingFidelity = "timing_fidelity"
        case timingMethod = "timing_method"
        case artworkURL = "artwork_url"
        case albumID = "album_id"
        case artistID = "artist_id"
    }

    // Explicit nulls, as for points: an unknown genre reads `"genre": null`.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(t, forKey: .t)
        try c.encode(title, forKey: .title)
        try c.encode(artist, forKey: .artist)
        try c.encode(source, forKey: .source)
        try c.encode(album, forKey: .album)
        try c.encode(isrc, forKey: .isrc)
        try c.encode(trackID, forKey: .trackID)
        try c.encode(genre, forKey: .genre)
        try c.encode(durationMs, forKey: .durationMs)
        try c.encode(bpm, forKey: .bpm)
        try c.encode(startedT, forKey: .startedT)
        try c.encode(endedT, forKey: .endedT)
        try c.encode(playedMs, forKey: .playedMs)
        try c.encode(end, forKey: .end)
        try c.encode(timingFidelity, forKey: .timingFidelity)
        try c.encode(timingMethod, forKey: .timingMethod)
        try c.encode(artworkURL, forKey: .artworkURL)
        try c.encode(albumID, forKey: .albumID)
        try c.encode(artistID, forKey: .artistID)
        try c.encode(sightings, forKey: .sightings)
    }
}

/// What a player reports about the current track, before it is stamped
/// with a run time. Shared by every music connector.
public struct PlayingTrack: Equatable, Sendable {
    public var title: String
    public var artist: String
    public var album: String?
    public var isrc: String?
    public var trackID: String?
    public var genre: String?
    public var durationMs: Int?
    public var bpm: Double?
    public var artworkURL: String?
    public var albumID: String?
    public var artistID: String?

    public init(title: String, artist: String, album: String? = nil, isrc: String? = nil, trackID: String? = nil,
                genre: String? = nil, durationMs: Int? = nil, bpm: Double? = nil,
                artworkURL: String? = nil, albumID: String? = nil, artistID: String? = nil) {
        self.artworkURL = artworkURL
        self.albumID = albumID
        self.artistID = artistID
        self.title = title
        self.artist = artist
        self.album = album
        self.isrc = isrc
        self.trackID = trackID
        self.genre = genre
        self.durationMs = durationMs
        self.bpm = bpm
    }
}

public struct RunSummary: Codable, Equatable, Sendable {
    public var distanceM: Double
    public var avgSpeedMps: Double
    public var maxSpeedMps: Double
    public var movingTimeMs: Int

    public init(distanceM: Double, avgSpeedMps: Double, maxSpeedMps: Double, movingTimeMs: Int) {
        self.distanceM = distanceM
        self.avgSpeedMps = avgSpeedMps
        self.maxSpeedMps = maxSpeedMps
        self.movingTimeMs = movingTimeMs
    }

    enum CodingKeys: String, CodingKey {
        case distanceM = "distance_m"
        case avgSpeedMps = "avg_speed_mps"
        case maxSpeedMps = "max_speed_mps"
        case movingTimeMs = "moving_time_ms"
    }
}

/// A sensor stream stored wider than v1 interprets (brief §11). Column-named
/// rows of numbers; nil where a field was unavailable for that sample.
public struct RawStream: Codable, Equatable, Sendable {
    public var source: String
    public var fidelity: Fidelity
    public var fields: [String]
    public var samples: [[Double?]]

    public init(source: String, fidelity: Fidelity, fields: [String], samples: [[Double?]]) {
        self.source = source
        self.fidelity = fidelity
        self.fields = fields
        self.samples = samples
    }
}

/// The shared contract between the recorder and everything downstream (brief §3).
// MARK: - Self-reported annotations (schema v4)

/// What the runner declared the outing was. A declaration, not a measurement:
/// "push" is a hint for benchmark detection, never a benchmark flag by itself.
public enum RunIntent: String, Codable, CaseIterable, Sendable {
    case walk, easy, push
}

/// One self-reported value with its provenance, so the "source and fidelity
/// on every stored number" rule holds for things the runner told us too.
public struct Reported<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var value: Value
    public var source: String
    public var fidelity: Fidelity
    public var recordedAt: Date

    public init(_ value: Value, at date: Date, source: String = "user") {
        self.value = value
        self.source = source
        self.fidelity = .reported
        self.recordedAt = date
    }

    enum CodingKeys: String, CodingKey {
        case value, source, fidelity
        case recordedAt = "recorded_at"
    }
}

/// Things the runner said about a run. Append-only: an answer given on the
/// finish screen stays distinct from one changed three days later, and the
/// latest is the current one. Nothing measured lives here.
public struct RunAnnotations: Codable, Equatable, Sendable {
    /// How it felt, 1 (rough) to 5 (great).
    public var feel: [Reported<Int>]
    public var intent: [Reported<RunIntent>]

    public init(feel: [Reported<Int>] = [], intent: [Reported<RunIntent>] = []) {
        self.feel = feel
        self.intent = intent
    }

    public var currentFeel: Int? { feel.last?.value }
    public var currentIntent: RunIntent? { intent.last?.value }

    public mutating func recordFeel(_ value: Int, at date: Date) {
        feel.append(Reported(min(max(value, 1), 5), at: date))
    }

    public mutating func recordIntent(_ value: RunIntent, at date: Date) {
        intent.append(Reported(value, at: date))
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        feel = try c.decodeIfPresent([Reported<Int>].self, forKey: .feel) ?? []
        intent = try c.decodeIfPresent([Reported<RunIntent>].self, forKey: .intent) ?? []
    }
}

// MARK: - Measured efforts (schema v5)

/// A value with its provenance spelled out: who produced it, how much to
/// trust it, and how it was derived when that matters.
public struct Sourced<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var value: Value
    public var source: String
    public var fidelity: Fidelity
    public var method: String?

    public init(_ value: Value, source: String, fidelity: Fidelity, method: String? = nil) {
        self.value = value
        self.source = source
        self.fidelity = fidelity
        self.method = method
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(value, forKey: .value)
        try c.encode(source, forKey: .source)
        try c.encode(fidelity, forKey: .fidelity)
        try c.encode(method, forKey: .method)
    }

    enum CodingKeys: String, CodingKey { case value, source, fidelity, method }
}

/// A position the runner marked by standing on it.
public struct LinePoint: Codable, Equatable, Sendable {
    public var lat: Double
    public var lng: Double
    public var accuracyM: Double

    public init(lat: Double, lng: Double, accuracyM: Double) {
        self.lat = lat
        self.lng = lng
        self.accuracyM = accuracyM
    }

    enum CodingKeys: String, CodingKey {
        case lat, lng
        case accuracyM = "accuracy_m"
    }
}

/// Something that happened during an effort, at a run time. These are the
/// hooks future Moments attach to (Idea Capture §28): gate_open, to_go_100, finish.
public struct EffortEvent: Codable, Equatable, Sendable {
    public var name: String
    public var tMs: Int

    public init(_ name: String, tMs: Int) {
        self.name = name
        self.tMs = tMs
    }

    enum CodingKeys: String, CodingKey {
        case name
        case tMs = "t_ms"
    }
}

/// A gated, line-to-line maximal effort inside a run: the sprint, and later
/// the datum the speed-duration fit and re-benchmarking need (Diagnostic §2–§3,
/// Idea Capture §27). Measured, not annotated, with provenance per field.
public struct Effort: Codable, Equatable, Sendable {
    /// How it was run. Only "line_to_line" for now.
    public var protocolName: String
    /// Target distance in metres: chosen by the runner.
    public var target: Sourced<Double>
    /// Gun time: when the app sounded the gate, as run time in ms.
    public var gate: Sourced<Int>?
    /// When the runner crossed the finish, as run time in ms, with its method.
    public var finish: Sourced<Int>?
    public var startLine: Sourced<LinePoint>?
    public var finishLine: Sourced<LinePoint>?
    /// Start and finish are the same line (a lap of a track).
    public var lap: Bool
    /// Distance between gate and finish from positions and from Doppler speed.
    public var distanceGps: Sourced<Double>?
    public var distanceDoppler: Sourced<Double>?
    /// First movement after the gate, estimated from speed (±1 s at 1 Hz).
    public var firstMovement: Sourced<Int>?
    public var events: [EffortEvent]

    public init(targetM: Double, chosenAt: Date? = nil, startLine: Sourced<LinePoint>? = nil,
                finishLine: Sourced<LinePoint>? = nil, lap: Bool = false) {
        protocolName = "line_to_line"
        target = Sourced(targetM, source: "user", fidelity: .reported)
        self.startLine = startLine
        self.finishLine = finishLine
        self.lap = lap
        events = []
    }

    enum CodingKeys: String, CodingKey {
        case target, gate, finish, lap, events
        case protocolName = "protocol"
        case startLine = "start_line"
        case finishLine = "finish_line"
        case distanceGps = "distance_gps_m"
        case distanceDoppler = "distance_doppler_m"
        case firstMovement = "first_movement_t_ms"
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(protocolName, forKey: .protocolName)
        try c.encode(target, forKey: .target)
        try c.encode(gate, forKey: .gate)
        try c.encode(finish, forKey: .finish)
        try c.encode(startLine, forKey: .startLine)
        try c.encode(finishLine, forKey: .finishLine)
        try c.encode(lap, forKey: .lap)
        try c.encode(distanceGps, forKey: .distanceGps)
        try c.encode(distanceDoppler, forKey: .distanceDoppler)
        try c.encode(firstMovement, forKey: .firstMovement)
        try c.encode(events, forKey: .events)
    }
}

public struct Run: Codable, Identifiable, Equatable, Sendable {
    public static let currentSchemaVersion = 6

    public var id: UUID
    public var schemaVersion: Int
    public var startedAt: Date
    public var endedAt: Date?
    public var durationMs: Int
    public var points: [RunPoint]
    public var music: [MusicEntry]
    public var summary: RunSummary
    public var rawStreams: [String: RawStream]
    /// When Start was tapped, if recording waited for a GPS fix. The gap to
    /// `startedAt` is time-to-fix, kept as data about the gear check itself.
    public var armedAt: Date?
    /// What the runner said about the run (v4). Empty for older files.
    public var annotations: RunAnnotations
    /// A sprint or other line-to-line effort inside the run (v5), if any.
    public var effort: Effort?

    public init(id: UUID, schemaVersion: Int = Run.currentSchemaVersion, startedAt: Date, endedAt: Date?,
                durationMs: Int, points: [RunPoint], music: [MusicEntry], summary: RunSummary,
                rawStreams: [String: RawStream], armedAt: Date? = nil, annotations: RunAnnotations = RunAnnotations(),
                effort: Effort? = nil) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationMs = durationMs
        self.points = points
        self.music = music
        self.summary = summary
        self.rawStreams = rawStreams
        self.armedAt = armedAt
        self.annotations = annotations
        self.effort = effort
    }

    /// The only sanctioned way to change a stored run: annotations in,
    /// everything measured untouched by construction.
    /// Re-saving writes the whole file in the current format, so the version
    /// is bumped to match; the measured data itself is untouched.
    public func annotated(_ change: (inout RunAnnotations) -> Void) -> Run {
        var copy = self
        change(&copy.annotations)
        copy.schemaVersion = max(copy.schemaVersion, Run.currentSchemaVersion)
        return copy
    }

    enum CodingKeys: String, CodingKey {
        case id
        case schemaVersion = "schema_version"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationMs = "duration_ms"
        case points, music, summary, annotations, effort
        case rawStreams = "raw_streams"
        case armedAt = "armed_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        durationMs = try c.decode(Int.self, forKey: .durationMs)
        points = try c.decode([RunPoint].self, forKey: .points)
        music = try c.decode([MusicEntry].self, forKey: .music)
        summary = try c.decode(RunSummary.self, forKey: .summary)
        rawStreams = try c.decode([String: RawStream].self, forKey: .rawStreams)
        armedAt = try c.decodeIfPresent(Date.self, forKey: .armedAt)
        annotations = try c.decodeIfPresent(RunAnnotations.self, forKey: .annotations) ?? RunAnnotations()
        effort = try c.decodeIfPresent(Effort.self, forKey: .effort)
    }

    // Explicit nulls, as everywhere else: `"armed_at": null` rather than a missing key.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(startedAt, forKey: .startedAt)
        try c.encode(endedAt, forKey: .endedAt)
        try c.encode(durationMs, forKey: .durationMs)
        try c.encode(points, forKey: .points)
        try c.encode(music, forKey: .music)
        try c.encode(summary, forKey: .summary)
        try c.encode(rawStreams, forKey: .rawStreams)
        try c.encode(armedAt, forKey: .armedAt)
        try c.encode(annotations, forKey: .annotations)
        try c.encode(effort, forKey: .effort)
    }
}

// MARK: - JSON

public extension Run {
    static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func jsonData() throws -> Data {
        try Run.makeEncoder().encode(self)
    }

    static func fromJSON(_ data: Data) throws -> Run {
        try makeDecoder().decode(Run.self, from: data)
    }

    /// Points that have a position, for map rendering and GPX.
    var geoPoints: [RunPoint] {
        points.filter { $0.lat != nil && $0.lng != nil }
    }
}

// MARK: - Display transforms (pace is derived, never stored)

public enum PaceFormat {
    /// "5:12" min/km, or "--:--" when effectively stopped.
    public static func minPerKm(speedMps: Double) -> String {
        guard speedMps > 0.3 else { return "--:--" }
        let secPerKm = 1000.0 / speedMps
        let m = Int(secPerKm) / 60
        let s = Int(secPerKm) % 60
        return String(format: "%d:%02d", m, s)
    }

    /// "12:34" or "1:02:03".
    public static func elapsed(ms: Int) -> String {
        let total = max(0, ms / 1000)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    public static func kilometres(_ metres: Double) -> String {
        String(format: "%.2f", metres / 1000)
    }
}
