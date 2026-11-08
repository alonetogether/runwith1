import Foundation

// MARK: - Music log v6: what was played, for how long, and how it ended
//
// Connectors report what the player says (a sighting); the builder keeps one
// open entry per source and closes it when the track changes, the player goes
// quiet, recording is interrupted, or the run ends. Everything derived here
// (start, end, play time, end reason) is recomputable from the stored raw
// sightings. Nothing here decides whether a song was "listened to": that is a
// later, tested filter with its own thresholds (README, Music).

/// One look at the player: run time, song position, playing or paused.
public struct MusicSighting: Codable, Equatable, Sendable {
    public var t: Int
    public var progressMs: Int?
    public var playing: Bool

    public init(t: Int, progressMs: Int?, playing: Bool) {
        self.t = t
        self.progressMs = progressMs
        self.playing = playing
    }

    enum CodingKeys: String, CodingKey {
        case t, playing
        case progressMs = "progress_ms"
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(t, forKey: .t)
        try c.encode(progressMs, forKey: .progressMs)
        try c.encode(playing, forKey: .playing)
    }
}

/// How a song stopped being the current track.
public enum MusicEnd: String, Codable, Sendable {
    /// Its position reached the end (within a tolerance for crossfade).
    case completed
    /// Another track, or the same one from the top, replaced it before the end.
    case skipped
    /// Paused or stopped and not playing again before the run ended.
    case stopped
    /// Still playing when the run ended: a final-spurt song cut off by Stop.
    case runEnded = "run_ended"
    /// Sight was lost (an ad, a private session, a recording gap); no
    /// completion could be inferred.
    case lost
}

/// What a connector saw on one look at its player.
public enum MusicObservation: Equatable, Sendable {
    case track(PlayingTrack, progressMs: Int?, playing: Bool)
    /// The player reports no current item.
    case nothingPlaying
    /// Something the connector cannot see holds the player (an ad, a private session).
    case unknown
}

/// The fidelity and method stamped on an entry's times by its connector.
public struct MusicTiming: Equatable, Sendable {
    public var fidelity: Fidelity
    public var method: String

    public init(fidelity: Fidelity, method: String) {
        self.fidelity = fidelity
        self.method = method
    }
}

public enum MusicLog {
    /// Crossfade can end a track up to 12 s early on Spotify without a skip.
    public static let completionToleranceMs = 15_000
    /// Position jumping back more than this on the same track is a replay: a new entry.
    public static let restartBackMs = 5_000

    enum Cause: Equatable {
        /// A different track (or a replay) appeared; its position when seen, if it was playing.
        case changed(nextProgressMs: Int?)
        case nothingPlaying
        case lost
        case runEnded
    }

    static func key(_ track: PlayingTrack) -> String { track.trackID ?? "\(track.title)|\(track.artist)" }
    static func key(_ entry: MusicEntry) -> String { entry.trackID ?? "\(entry.title)|\(entry.artist)" }

    /// Same track, still the same play (not restarted from the top).
    static func continues(_ entry: MusicEntry, with track: PlayingTrack, progressMs: Int?) -> Bool {
        guard key(entry) == key(track) else { return false }
        if let p = progressMs, let last = entry.sightings?.last?.progressMs, p < last - restartBackMs {
            return false
        }
        return true
    }

    /// Closes an open entry at run time `closeT`: fills `ended_t`, `played_ms`
    /// and `end` from its sightings. Pure, so a later estimator can redo it.
    static func close(_ e: inout MusicEntry, at closeT: Int, cause: Cause) {
        guard let s = e.sightings, let first = s.first, let last = s.last else { return }
        let duration = e.durationMs
        let remaining: Int? = {
            guard let d = duration, let lp = last.progressMs else { return nil }
            return max(d - lp, 0)
        }()

        // When it stopped being current.
        let ended: Int
        switch cause {
        case .changed(let q):
            // The new track was q ms in when seen: the change was about q ago,
            // never before the last time this one was seen.
            ended = q.map { max(last.t, min(closeT, closeT - $0)) } ?? closeT
        case .nothingPlaying, .lost:
            if last.playing {
                ended = remaining.map { min(closeT, last.t + $0) } ?? closeT
            } else {
                ended = last.t
            }
        case .runEnded:
            ended = closeT
        }

        // Where the song had got to when it ended.
        var endProgress: Int? = last.progressMs.map { last.playing ? $0 + max(ended - last.t, 0) : $0 }
        if let d = duration, let p = endProgress { endProgress = min(p, d) }

        // Time audibly playing inside the run.
        var played = 0
        if let p0 = first.progressMs { played += min(p0, max(first.t, 0)) }   // before first sight, inside the run
        for (a, b) in zip(s, s.dropFirst()) {
            let wall = max(b.t - a.t, 0)
            if let pa = a.progressMs, let pb = b.progressMs {
                played += min(max(pb - pa, 0), wall)      // position only moves while playing
            } else if a.playing && b.playing {
                played += wall
            }
        }
        if last.playing {
            var tail = max(ended - last.t, 0)
            if let r = remaining { tail = min(tail, r) }
            played += tail
        }

        let nearEnd: Bool = {
            guard let d = duration, let p = endProgress else { return false }
            return p >= d - completionToleranceMs
        }()
        let end: MusicEnd
        switch cause {
        case .changed: end = nearEnd ? .completed : .skipped
        case .nothingPlaying: end = nearEnd ? .completed : .stopped
        case .lost: end = nearEnd ? .completed : .lost
        case .runEnded: end = last.playing ? .runEnded : (nearEnd ? .completed : .stopped)
        }

        e.endedT = ended
        e.playedMs = played
        e.end = end
    }
}

// MARK: - RunBuilder intake

extension RunBuilder {
    /// One look at a connector's player. A track becomes an entry the first
    /// time it is actually playing (embodiment gate, brief §5), so a track
    /// paused at Start and played later is logged when it starts, and a pause
    /// and resume of the same track stays one entry.
    public mutating func observeMusic(_ obs: MusicObservation, source: String, timing: MusicTiming, at date: Date) {
        let t = runTimeMs(date)
        var open = musicOpen ?? [:]
        let current = open[source]

        switch obs {
        case .track(let track, let progress, let playing):
            if let i = current, MusicLog.continues(music[i], with: track, progressMs: progress) {
                appendSighting(MusicSighting(t: t, progressMs: progress, playing: playing), to: i)
            } else {
                if let i = current {
                    closeMusic(at: i, closeT: t, cause: .changed(nextProgressMs: playing ? progress : nil))
                    open[source] = nil
                }
                if playing {
                    var e = MusicEntry(t: t, track: track, source: source)
                    e.startedT = progress.map { t - $0 }
                    e.sightings = [MusicSighting(t: t, progressMs: progress, playing: true)]
                    e.timingFidelity = timing.fidelity
                    e.timingMethod = timing.method
                    appendMusic(e)
                    open[source] = music.count - 1
                }
            }
        case .nothingPlaying, .unknown:
            if let i = current {
                closeMusic(at: i, closeT: t, cause: obs == .nothingPlaying ? .nothingPlaying : .lost)
                open[source] = nil
            }
        }
        musicOpen = open
    }

    /// After a recording gap: open entries close as lost where they were last
    /// seen. They are never stretched across the gap.
    mutating func closeMusicForGap() {
        for (_, i) in musicOpen ?? [:] {
            let lastT = music[i].sightings?.last?.t ?? music[i].t
            closeMusic(at: i, closeT: lastT, cause: .lost)
        }
        musicOpen = nil
    }

    /// The music log as saved: entries still open are closed at the run's end.
    func musicClosed(atRunMs endT: Int) -> [MusicEntry] {
        var out = music
        for (_, i) in musicOpen ?? [:] where i < out.count {
            MusicLog.close(&out[i], at: endT, cause: .runEnded)
        }
        return out
    }
}
