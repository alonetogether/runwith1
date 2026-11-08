import XCTest
@testable import RunCore

final class RunCoreTests: XCTestCase {
    // Whole-second epoch so ISO-8601 round-trips compare equal.
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let lat0 = 35.6717
    let lng0 = 139.6949
    let metresPerDegreeLat = 111_320.0

    /// Fixes moving due north at `speed` m/s, one per second, no source speed.
    func straightTrack(speed: Double, seconds: Int, accuracy: Double = 5, from: Date? = nil) -> [LocationFix] {
        let t0 = from ?? start
        return (0..<seconds).map { i in
            LocationFix(timestamp: t0.addingTimeInterval(Double(i)),
                        lat: lat0 + speed * Double(i) / metresPerDegreeLat,
                        lng: lng0, horizontalAccuracyM: accuracy, speedMps: nil,
                        altitudeM: 40, verticalAccuracyM: 5)
        }
    }

    func testStraightLineDistanceAndSmoothedSpeed() {
        var b = RunBuilder(startedAt: start)
        for f in straightTrack(speed: 3, seconds: 60) { b.addFix(f) }
        XCTAssertEqual(b.points.count, 60)
        XCTAssertEqual(b.distanceM, 177, accuracy: 2)           // 59 segments × 3 m
        XCTAssertEqual(b.liveSpeedMps, 3, accuracy: 0.15)        // smoothing has converged
        XCTAssertEqual(b.movingTimeMs, 59_000)
        XCTAssertEqual(b.points.last?.source, .gps)
        XCTAssertEqual(b.points.last?.fidelity, .measured)
        XCTAssertEqual(b.points.last?.elevationM, 40)
    }

    func testPoorAccuracyFixesAreRejectedAndDoNotMoveDistance() {
        var b = RunBuilder(startedAt: start)
        let track = straightTrack(speed: 3, seconds: 10)
        for f in track { b.addFix(f) }
        let before = b.distanceM
        let junk = LocationFix(timestamp: start.addingTimeInterval(10.5), lat: lat0 + 0.001, lng: lng0,
                               horizontalAccuracyM: 80)
        XCTAssertEqual(b.addFix(junk), .rejected(.poorAccuracy))
        XCTAssertEqual(b.distanceM, before)
        XCTAssertEqual(b.rejectedFixes, 1)
    }

    func testImplausibleJumpIsRejected() {
        var b = RunBuilder(startedAt: start)
        for f in straightTrack(speed: 3, seconds: 10) { b.addFix(f) }
        let before = b.distanceM
        let teleport = LocationFix(timestamp: start.addingTimeInterval(10), lat: lat0 + 0.01, lng: lng0,
                                   horizontalAccuracyM: 5)
        XCTAssertEqual(b.addFix(teleport), .rejected(.implausibleJump))
        XCTAssertEqual(b.distanceM, before)
        // The series continues from the last accepted fix, not from the jump.
        let next = LocationFix(timestamp: start.addingTimeInterval(11), lat: lat0 + 3 * 10 / metresPerDegreeLat,
                               lng: lng0, horizontalAccuracyM: 5)
        if case .accepted = b.addFix(next) {} else { XCTFail("expected accepted") }
    }

    func testStoppedSegmentsAccumulateNoDistanceOrMovingTime() {
        var b = RunBuilder(startedAt: start)
        // Standing still: source reports speed 0 while position jitters ~0.3 m.
        for i in 0..<20 {
            let jitter = (i % 2 == 0 ? 0.3 : -0.3) / metresPerDegreeLat
            b.addFix(LocationFix(timestamp: start.addingTimeInterval(Double(i)), lat: lat0 + jitter, lng: lng0,
                                 horizontalAccuracyM: 8, speedMps: 0))
        }
        XCTAssertEqual(b.points.count, 20)
        XCTAssertEqual(b.distanceM, 0)
        XCTAssertEqual(b.movingTimeMs, 0)
    }

    func testPedometerTakesOverWhenGPSIsAbsent() {
        var b = RunBuilder(startedAt: start)
        for i in 0..<10 {
            b.addPedometer(PedometerSample(timestamp: start.addingTimeInterval(Double(i) * 2.5), steps: i * 7,
                                           cumulativeDistanceM: Double(i) * 7.5, paceSPerM: 1.0 / 3.0,
                                           cadenceStepsPerS: 2.8))
        }
        XCTAssertEqual(b.points.count, 9)                      // first sample only primes the delta
        XCTAssertEqual(b.distanceM, 67.5, accuracy: 0.01)
        XCTAssertEqual(b.liveSource(now: start.addingTimeInterval(22.5)), .pedometer)
        XCTAssertEqual(b.points.last?.source, .pedometer)
        XCTAssertEqual(b.points.last?.fidelity, .proxy)
        XCTAssertNil(b.points.last?.lat)
        XCTAssertEqual(b.points.last?.cadenceSpm ?? 0, 168, accuracy: 0.01)
    }

    func testPedometerDoesNotDoubleCountWhileGPSIsLive() {
        var b = RunBuilder(startedAt: start)
        let gps = straightTrack(speed: 3, seconds: 30)
        for (i, f) in gps.enumerated() {
            b.addFix(f)
            if i % 3 == 0 {
                b.addPedometer(PedometerSample(timestamp: f.timestamp, steps: i * 3,
                                               cumulativeDistanceM: Double(i) * 3.2, paceSPerM: nil, cadenceStepsPerS: 2.9))
            }
        }
        XCTAssertEqual(b.points.filter { $0.source == .pedometer }.count, 0)
        XCTAssertEqual(b.distanceM, 87, accuracy: 2)             // GPS only: 29 × 3 m
        XCTAssertEqual(b.points.last?.cadenceSpm ?? 0, 174, accuracy: 0.01) // cadence still attached
        XCTAssertEqual(b.liveSource(now: gps.last!.timestamp), .gps)
    }

    func testRunJSONUsesSchemaV3SnakeCaseAndExplicitNulls() throws {
        var b = RunBuilder(startedAt: start)
        for f in straightTrack(speed: 3, seconds: 5) { b.addFix(f) }
        b.addPedometer(PedometerSample(timestamp: start.addingTimeInterval(10), steps: 10, cumulativeDistanceM: 10, paceSPerM: nil, cadenceStepsPerS: 2.7))
        b.addPedometer(PedometerSample(timestamp: start.addingTimeInterval(12), steps: 16, cumulativeDistanceM: 16, paceSPerM: nil, cadenceStepsPerS: 2.7))
        b.addMusic(title: "ユメヲカケル", artist: "Uma Musume", source: "apple_music", at: start.addingTimeInterval(3))
        b.addMusic(title: "ユメヲカケル", artist: "Uma Musume", source: "apple_music", at: start.addingTimeInterval(4)) // dedup
        let run = b.finish(at: start.addingTimeInterval(13))

        let data = try run.jsonData()
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"schema_version\" : 3"))
        XCTAssertTrue(text.contains("\"genre\" : null"))     // music attribute the player did not give
        XCTAssertTrue(text.contains("\"speed_mps\""))
        XCTAssertTrue(text.contains("\"raw_speed_mps\""))
        XCTAssertTrue(text.contains("\"lat\" : null"))         // indoor point, explicit null
        XCTAssertTrue(text.contains("\"raw_streams\""))
        XCTAssertEqual(run.music.count, 1)
        XCTAssertEqual(run.durationMs, 13_000)
        XCTAssertNotNil(run.rawStreams["gps_fixes"])
        XCTAssertNotNil(run.rawStreams["pedometer"])

        let decoded = try Run.fromJSON(data)
        XCTAssertEqual(decoded, run)
    }

    func testMusicAttributesRoundTripAndOldFilesStillDecode() throws {
        var b = RunBuilder(startedAt: start)
        for f in straightTrack(speed: 3, seconds: 5) { b.addFix(f) }
        b.addMusic(PlayingTrack(title: "Around the World", artist: "Daft Punk", album: "Homework", isrc: "GBDUW0600018",
                              trackID: "1pKYYY0dkg23sQQXi0Q5zN", genre: "french house", durationMs: 429_000, bpm: 121),
                   source: "spotify", at: start.addingTimeInterval(2))
        let run = b.finish(at: start.addingTimeInterval(6))
        let data = try run.jsonData()
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"isrc\" : \"GBDUW0600018\""))
        XCTAssertTrue(text.contains("\"track_id\""))
        XCTAssertEqual(try Run.fromJSON(data), run)

        // A schema-2 file has none of the new keys; it must still load, with nils.
        let v2 = """
        {"id":"\(UUID().uuidString)","schema_version":2,"started_at":"2026-11-08T05:40:00Z","ended_at":null,
         "duration_ms":1000,"points":[],"raw_streams":{},
         "summary":{"distance_m":0,"avg_speed_mps":0,"max_speed_mps":0,"moving_time_ms":0},
         "music":[{"t":0,"title":"Old","artist":"File","source":"apple_music"}]}
        """
        let old = try Run.fromJSON(Data(v2.utf8))
        XCTAssertEqual(old.music.first?.title, "Old")
        XCTAssertNil(old.music.first?.genre)
    }

    func testBuilderSurvivesACheckpointRoundTrip() throws {
        // Ten seconds of running, checkpointed, decoded, then ten more seconds.
        let track = straightTrack(speed: 3, seconds: 20)
        let id = UUID()
        var uninterrupted = RunBuilder(id: id, startedAt: start)
        for f in track { uninterrupted.addFix(f) }

        var first = RunBuilder(id: id, startedAt: start)
        for f in track.prefix(10) { first.addFix(f) }
        let data = try JSONEncoder().encode(first)
        var resumed = try JSONDecoder().decode(RunBuilder.self, from: data)
        for f in track.dropFirst(10) { resumed.addFix(f) }

        XCTAssertEqual(resumed.finish(at: start.addingTimeInterval(20)),
                       uninterrupted.finish(at: start.addingTimeInterval(20)))
    }

    func testResumeAfterGapDoesNotInventDistanceAcrossTheGap() {
        var b = RunBuilder(startedAt: start)
        for f in straightTrack(speed: 3, seconds: 10) { b.addFix(f) }
        let before = b.distanceM
        let movingBefore = b.movingTimeMs
        b.resumeAfterGap()
        // Two minutes later and 360 m further on, recording picks up again.
        let later = straightTrack(speed: 3, seconds: 5, from: start.addingTimeInterval(130))
            .map { f -> LocationFix in var g = f; g.lat += 360 / 111_000.0; return g }
        for f in later { b.addFix(f) }
        // Only the 4 seconds after the gap count: about 12 m and 4 s, not 372 m and 124 s.
        XCTAssertEqual(b.distanceM - before, 12, accuracy: 2)
        XCTAssertEqual(b.movingTimeMs - movingBefore, 4_000, accuracy: 500)
    }

    func testGPXExportRoundTripsThroughParser() throws {
        var b = RunBuilder(startedAt: start)
        for f in straightTrack(speed: 3, seconds: 12) { b.addFix(f) }
        let run = b.finish(at: start.addingTimeInterval(12))
        let gpx = GPX.export(run, name: "Test & <loop>")
        XCTAssertTrue(gpx.contains("<gpx version=\"1.1\""))
        XCTAssertTrue(gpx.contains("Test &amp; &lt;loop&gt;"))

        let fixes = try GPX.parseFixes(Data(gpx.utf8))
        XCTAssertEqual(fixes.count, 12)
        XCTAssertEqual(fixes.first!.lat, lat0, accuracy: 1e-6)
        XCTAssertEqual(fixes.first!.timestamp, start)
        XCTAssertEqual(fixes.last!.altitudeM ?? 0, 40, accuracy: 0.01)

        // Replaying the exported track through the cleaner reproduces the distance.
        var b2 = RunBuilder(startedAt: start)
        for f in fixes { b2.addFix(f) }
        XCTAssertEqual(b2.distanceM, run.summary.distanceM, accuracy: 0.5)
    }

    func testPaceFormatting() {
        XCTAssertEqual(PaceFormat.minPerKm(speedMps: 3.333), "5:00")
        XCTAssertEqual(PaceFormat.minPerKm(speedMps: 0), "--:--")
        XCTAssertEqual(PaceFormat.elapsed(ms: 61_000), "1:01")
        XCTAssertEqual(PaceFormat.elapsed(ms: 3_661_000), "1:01:01")
    }
}
