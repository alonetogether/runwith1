import XCTest
@testable import RunCore

final class RunInsightsTests: XCTestCase {
    /// A 10-minute run at 1 Hz. `speed(t)` gives m/s at second t; `elevation(t)` metres.
    func makeRun(seconds: Int = 600, music: [(Int, String)],
                 speed: (Int) -> Double, elevation: ((Int) -> Double)? = nil,
                 fidelity: Fidelity = .measured) -> Run {
        var points: [RunPoint] = []
        var dist = 0.0
        for s in 0..<seconds {
            let v = speed(s)
            dist += v
            points.append(RunPoint(t: s * 1000, lat: 35.67, lng: 139.70, accuracyM: 5, rawSpeedMps: v,
                                   speedMps: v, distanceM: dist, cadenceSpm: nil, elevationM: elevation?(s),
                                   source: fidelity == .proxy ? .pedometer : .gps, fidelity: fidelity))
        }
        return Run(id: UUID(), startedAt: Date(timeIntervalSince1970: 0), endedAt: nil, durationMs: seconds * 1000,
                   points: points,
                   music: music.map { MusicEntry(t: $0.0 * 1000, title: $0.1, artist: "Artist", source: "apple_music") },
                   summary: RunSummary(distanceM: dist, avgSpeedMps: dist / Double(seconds), maxSpeedMps: 4, movingTimeMs: seconds * 1000),
                   rawStreams: [:])
    }

    let playlist = [(0, "Warm Up"), (240, "Banger"), (420, "Cool Down")]

    func testPickupCreditsTheSongWhoseFirstMinuteWasFaster() {
        // Steady 3.0 m/s, then 3.6 m/s from 250 s to 330 s: 20% faster right after "Banger".
        let run = makeRun(music: playlist) { s in (250..<330).contains(s) ? 3.6 : 3.0 }
        let m = RunInsights.pickup(in: run)
        XCTAssertEqual(m?.song.title, "Banger")
        XCTAssertEqual(m?.kind, .pickup)
        XCTAssertEqual(m?.beforeSpeedMps ?? 0, 3.0, accuracy: 0.01)
        XCTAssertEqual(m?.speedMps ?? 0, 3.6, accuracy: 0.01)
        XCTAssertEqual(m?.fidelity, .measured)
        XCTAssertEqual(RunInsights.songHighlight(in: run)?.kind, .pickup)
    }

    func testFirstSongNeverGetsPickupCredit() {
        // Fast opening minute under "Warm Up", flat afterwards.
        let run = makeRun(music: playlist) { s in s < 70 ? 3.8 : 3.0 }
        XCTAssertNil(RunInsights.pickup(in: run))
    }

    func testPickupAfterAStopIsNotAPickup() {
        // Traffic light for the minute before "Banger", then normal running.
        let run = makeRun(music: playlist) { s in (180..<240).contains(s) ? 0.2 : 3.0 }
        XCTAssertNil(RunInsights.pickup(in: run))
    }

    func testDownhillMinuteGetsNoCredit() {
        // Faster after "Banger", but the after minute drops 8 m while the before minute was flat.
        let run = makeRun(music: playlist,
                          speed: { s in (250..<330).contains(s) ? 3.6 : 3.0 },
                          elevation: { s in s < 250 ? 40 : max(32, 40 - Double(s - 250) * 0.2) })
        XCTAssertNil(RunInsights.pickup(in: run))
    }

    func testSmallLiftIsWithinNoise() {
        let run = makeRun(music: playlist) { s in (250..<330).contains(s) ? 3.1 : 3.0 }   // +3%
        XCTAssertNil(RunInsights.pickup(in: run))
    }

    func testShortSongIsSkipped() {
        // "Banger" plays only 60 s before the next track.
        let run = makeRun(music: [(0, "Warm Up"), (240, "Banger"), (300, "Cool Down")]) { s in (250..<330).contains(s) ? 3.6 : 3.0 }
        XCTAssertNil(RunInsights.pickup(in: run))
    }

    func testFastestStretchFallsBackWhenThereIsNoPickup() {
        // Gradual build: no step after any song start, but the best minute is late, under "Cool Down".
        let run = makeRun(music: playlist) { s in 2.5 + Double(s) / 600.0 }
        let m = RunInsights.songHighlight(in: run)
        XCTAssertEqual(m?.kind, .fastestStretch)
        XCTAssertEqual(m?.song.title, "Cool Down")
        XCTAssertEqual(m?.atMs, 599_000)
    }

    func testIndoorRunIsTaggedProxy() {
        let run = makeRun(music: playlist, speed: { s in (250..<330).contains(s) ? 3.6 : 3.0 }, fidelity: .proxy)
        XCTAssertEqual(RunInsights.pickup(in: run)?.fidelity, .proxy)
    }

    func testNoMusicMeansNothingToSay() {
        let run = makeRun(music: []) { _ in 3.0 }
        XCTAssertNil(RunInsights.songHighlight(in: run))
    }
}
