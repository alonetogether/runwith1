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
}

// MARK: - Run object (schema_version 2)

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
    }

    enum CodingKeys: String, CodingKey {
        case t, title, artist, source, album, isrc, genre, bpm
        case trackID = "track_id"
        case durationMs = "duration_ms"
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

    public init(title: String, artist: String, album: String? = nil, isrc: String? = nil, trackID: String? = nil,
                genre: String? = nil, durationMs: Int? = nil, bpm: Double? = nil) {
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
public struct Run: Codable, Identifiable, Equatable, Sendable {
    public static let currentSchemaVersion = 3

    public var id: UUID
    public var schemaVersion: Int
    public var startedAt: Date
    public var endedAt: Date?
    public var durationMs: Int
    public var points: [RunPoint]
    public var music: [MusicEntry]
    public var summary: RunSummary
    public var rawStreams: [String: RawStream]

    public init(id: UUID, schemaVersion: Int = Run.currentSchemaVersion, startedAt: Date, endedAt: Date?,
                durationMs: Int, points: [RunPoint], music: [MusicEntry], summary: RunSummary,
                rawStreams: [String: RawStream]) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationMs = durationMs
        self.points = points
        self.music = music
        self.summary = summary
        self.rawStreams = rawStreams
    }

    enum CodingKeys: String, CodingKey {
        case id
        case schemaVersion = "schema_version"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationMs = "duration_ms"
        case points, music, summary
        case rawStreams = "raw_streams"
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
