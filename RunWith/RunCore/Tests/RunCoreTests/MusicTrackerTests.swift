import XCTest
@testable import RunCore

/// Music log v6: one entry per play, with start, end, play time and end
/// reason derived from raw sightings (README, Music).
final class MusicTrackerTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let spotify = MusicTiming(fidelity: .estimated, method: "spotify_poll_10s_progress")
    let apple = MusicTiming(fidelity: .measured, method: "system_player_notifications_2s_sampling")

    func track(_ id: String, duration: Int = 200_000) -> PlayingTrack {
        PlayingTrack(title: "Song \(id)", artist: "Artist", trackID: id, durationMs: duration)
    }

    func see(_ b: inout RunBuilder, _ id: String?, at s: Double, p: Int? = nil, playing: Bool = true,
             duration: Int = 200_000, timing: MusicTiming? = nil, source: String = "spotify") {
        let obs: MusicObservation = id.map { .track(track($0, duration: duration), progressMs: p, playing: playing) } ?? .nothingPlaying
        b.observeMusic(obs, source: source, timing: timing ?? spotify, at: start.addingTimeInterval(s))
    }

    func testSkipIsTimedFromTheNextTracksPositionNotThePoll() {
        var b = RunBuilder(startedAt: start)
        see(&b, "A", at: 0, p: 5_000)
        see(&b, "A", at: 10, p: 15_000)
        see(&b, "B", at: 20, p: 4_000)          // B was 4 s in: the change was at ~16 s
        let run = b.finish(at: start.addingTimeInterval(30))
        let a = run.music[0], next = run.music[1]
        XCTAssertEqual(a.startedT, -5_000)       // already playing at Start
        XCTAssertEqual(a.endedT, 16_000)
        XCTAssertEqual(a.end, .skipped)
        XCTAssertEqual(a.playedMs, 16_000)       // 10 s between sightings + 6 s tail; none before Start
        XCTAssertEqual(next.startedT, 16_000)
        XCTAssertEqual(a.timingFidelity, .estimated)
        XCTAssertEqual(a.sightings?.count, 2)
    }

    func testTrackThatReachesItsEndIsCompletedEvenWithCrossfade() {
        var b = RunBuilder(startedAt: start)
        see(&b, "A", at: 0, p: 0, duration: 30_000)
        see(&b, "A", at: 10, p: 10_000, duration: 30_000)
        see(&b, "A", at: 20, p: 20_000, duration: 30_000)
        see(&b, "B", at: 30, p: 5_000)          // changed ~5 s before the end of A: crossfade
        let a = b.finish(at: start.addingTimeInterval(40)).music[0]
        XCTAssertEqual(a.end, .completed)
        XCTAssertEqual(a.endedT, 25_000)
    }

    func testFinalSpurtSongCutOffByStopIsRunEndedNotSkipped() {
        var b = RunBuilder(startedAt: start)
        see(&b, "A", at: 0, p: 0)
        see(&b, "B", at: 90, p: 2_000)
        let run = b.finish(at: start.addingTimeInterval(100))
        let last = run.music[1]
        XCTAssertEqual(last.end, .runEnded)
        XCTAssertEqual(last.endedT, 100_000)
        XCTAssertEqual(last.playedMs, 12_000)    // 2 s before it was seen + 10 s to Stop
    }

    func testPauseAndResumeStaysOneEntryAndPauseIsNotPlayTime() {
        var b = RunBuilder(startedAt: start)
        see(&b, "A", at: 0, p: 0)
        see(&b, "A", at: 10, p: 10_000, playing: false)
        see(&b, "A", at: 40, p: 10_000, playing: false)
        see(&b, "A", at: 50, p: 20_000)
        let run = b.finish(at: start.addingTimeInterval(50))
        XCTAssertEqual(run.music.count, 1)
        XCTAssertEqual(run.music[0].playedMs, 20_000)
        XCTAssertEqual(run.music[0].end, .runEnded)
    }

    func testTrackPausedAtStartIsLoggedWhenItStartsPlaying() {
        var b = RunBuilder(startedAt: start)
        see(&b, "A", at: 0, p: 1_000, playing: false)
        XCTAssertTrue(b.music.isEmpty)           // embodiment gate: not playing yet
        see(&b, "A", at: 5, p: 1_000)
        XCTAssertEqual(b.music.count, 1)
        XCTAssertEqual(b.music[0].t, 5_000)
        XCTAssertEqual(b.music[0].startedT, 4_000)
    }

    func testReplayFromTheTopIsANewEntry() {
        var b = RunBuilder(startedAt: start)
        see(&b, "A", at: 0, p: 150_000, duration: 160_000)
        see(&b, "A", at: 10, p: 2_000, duration: 160_000)   // back to the top
        let run = b.finish(at: start.addingTimeInterval(20))
        XCTAssertEqual(run.music.count, 2)
        XCTAssertEqual(run.music[0].end, .completed)
    }

    func testPlayerGoingQuietMidSongIsStopped() {
        var b = RunBuilder(startedAt: start)
        see(&b, "A", at: 0, p: 0)
        see(&b, "A", at: 10, p: 10_000, playing: false)
        see(&b, nil, at: 20)
        let a = b.finish(at: start.addingTimeInterval(30)).music[0]
        XCTAssertEqual(a.end, .stopped)
        XCTAssertEqual(a.endedT, 10_000)
        XCTAssertEqual(a.playedMs, 10_000)
    }

    func testRecordingGapClosesOpenSongAsLostWhereLastSeen() {
        var b = RunBuilder(startedAt: start)
        see(&b, "A", at: 0, p: 0)
        see(&b, "A", at: 10, p: 10_000)
        b.resumeAfterGap()
        let a = b.finish(at: start.addingTimeInterval(120)).music[0]
        XCTAssertEqual(a.end, .lost)
        XCTAssertLessThanOrEqual(a.endedT ?? .max, 10_000)
    }

    func testTwoSourcesKeepTheirOwnOpenEntries() {
        var b = RunBuilder(startedAt: start)
        see(&b, "A", at: 0, p: 0)
        see(&b, "X", at: 1, p: 0, timing: apple, source: "apple_music")
        see(&b, "A", at: 10, p: 10_000)
        let run = b.finish(at: start.addingTimeInterval(20))
        XCTAssertEqual(run.music.count, 2)
        XCTAssertEqual(run.music.first { $0.source == "apple_music" }?.timingFidelity, .measured)
    }

    func testV6FieldsEncodeAsExplicitNullsAndRoundTrip() throws {
        var b = RunBuilder(startedAt: start)
        var t = track("A")
        t.artworkURL = "https://i.scdn.co/image/abc"
        t.albumID = "album1"
        b.observeMusic(.track(t, progressMs: 0, playing: true), source: "spotify", timing: spotify, at: start)
        b.addMusic(title: "Legacy", artist: "Path", source: "apple_music", at: start.addingTimeInterval(5))
        let run = b.finish(at: start.addingTimeInterval(10))
        let data = try run.jsonData()
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"schema_version\" : 6"))
        XCTAssertTrue(text.contains("\"artwork_url\" : \"https:\\/\\/i.scdn.co\\/image\\/abc\"")
                      || text.contains("\"artwork_url\" : \"https://i.scdn.co/image/abc\""))
        XCTAssertTrue(text.contains("\"played_ms\" : null"))     // the legacy entry: unknown, not zero
        XCTAssertTrue(text.contains("\"progress_ms\" : 0"))
        XCTAssertEqual(try Run.fromJSON(data), run)
    }

    func testV5FileAndV5CheckpointStillDecode() throws {
        let v5 = """
        {"id":"\(UUID().uuidString)","schema_version":5,"started_at":"2026-11-08T05:40:00Z","ended_at":null,
         "duration_ms":1000,"points":[],"raw_streams":{},
         "summary":{"distance_m":0,"avg_speed_mps":0,"max_speed_mps":0,"moving_time_ms":0},
         "music":[{"t":0,"title":"Old","artist":"File","source":"spotify","album":null,"isrc":null,
                   "track_id":"x","genre":null,"duration_ms":1000,"bpm":null}]}
        """
        let old = try Run.fromJSON(Data(v5.utf8))
        XCTAssertNil(old.music[0].playedMs)
        XCTAssertNil(old.music[0].sightings)

        // A checkpoint written before v6 has no music state: it must still decode.
        var b = RunBuilder(startedAt: start)
        b.addMusic(title: "Old", artist: "Build", source: "apple_music", at: start)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(b)) as! [String: Any]
        json.removeValue(forKey: "musicOpen")
        var music = json["music"] as! [[String: Any]]
        for k in ["started_t", "ended_t", "played_ms", "end", "timing_fidelity", "timing_method",
                  "artwork_url", "album_id", "artist_id", "sightings"] { music[0].removeValue(forKey: k) }
        json["music"] = music
        let restored = try JSONDecoder().decode(RunBuilder.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.music.count, 1)
    }

    func testSongLineUsesPlayedTimeWhenTheLogHasIt() {
        // A long span but only 30 s of actual play: below the 90 s floor.
        var e = MusicEntry(t: 60_000, title: "Brief", artist: "A", source: "spotify")
        e.startedT = 60_000; e.endedT = 300_000; e.playedMs = 30_000
        let run = Run(id: UUID(), startedAt: start, endedAt: nil, durationMs: 300_000, points: [],
                      music: [e], summary: RunSummary(distanceM: 0, avgSpeedMps: 0, maxSpeedMps: 0, movingTimeMs: 0),
                      rawStreams: [:])
        let seg = RunInsights.songSegments(in: run)[0]
        XCTAssertEqual(seg.playedMs, 30_000)
        XCTAssertLessThan(seg.playedMs, RunInsights.Config().minSongPlayMs)
    }
}
