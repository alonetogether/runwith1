import XCTest
@testable import RunCore

/// Deterministic noise for robustness tests.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func gaussian(sd: Double) -> Double {
        let u1 = max(Double.random(in: 0..<1, using: &self), 1e-12)
        let u2 = Double.random(in: 0..<1, using: &self)
        return sd * sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }
}

final class SprintTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    let lat0 = 35.67, lng0 = 139.70
    let metresPerDegLat = 111_000.0
    let gateMs = 5_000

    /// True motion from a speed profile v(seconds since gate), on a straight
    /// due north. Returns fine-grained (t_s, distance) to read truth from.
    func truth(_ v: (Double) -> Double, target: Double) -> (grid: [(t: Double, d: Double)], finishS: Double) {
        var grid: [(Double, Double)] = [(0, 0)]
        var t = 0.0, d = 0.0
        let dt = 0.001
        while d < target {
            d += (v(t) + v(t + dt)) / 2 * dt
            t += dt
            grid.append((t, d))
        }
        return (grid, t)
    }

    func distance(at s: Double, _ grid: [(t: Double, d: Double)]) -> Double {
        let i = min(grid.count - 1, max(0, Int(s / 0.001)))
        return grid[i].d
    }

    func trueSplitSpeeds(_ grid: [(t: Double, d: Double)], target: Double) -> [Double] {
        var times: [Double] = [0]
        var next = 100.0
        for g in grid where g.d >= next && next < target { times.append(g.t); next += 100 }
        times.append(grid.last!.t)
        return zip(times, times.dropFirst()).map { 100 / ($1 - $0) }
    }

    /// A run with a line-to-line effort, sampled at 1 Hz with a sub-second
    /// offset from the gate, optional Doppler noise and gate-time error.
    func sprintRun(target: Double, v: (Double) -> Double, noise: Double = 0, seed: UInt64 = 1,
                   gateShiftMs: Int = 0, sampleOffsetS: Double = 0.37, speedAccuracy: Double? = 0.2,
                   dropFrom: Double? = nil, dropTo: Double? = nil, jogAfterS: Double = 0) -> Run {
        let (grid, finishS) = truth(v, target: target)
        var rng = SplitMix64(state: seed)
        var points: [RunPoint] = []
        var raw: [[Double?]] = []
        var s = sampleOffsetS
        let endS = finishS + 3 + jogAfterS
        while s <= endS {
            defer { s += 1 }
            if let a = dropFrom, let b = dropTo, s >= a, s < b { continue }
            let inRace = s <= finishS
            let d = inRace ? distance(at: s, grid) : target + 3 * (s - finishS)
            let speed = max(0, (inRace ? v(s) : 3) + rng.gaussian(sd: noise))
            let t = gateMs + Int(s * 1000)
            points.append(RunPoint(t: t, lat: lat0 + d / metresPerDegLat, lng: lng0, accuracyM: 5,
                                   rawSpeedMps: speed, speedMps: speed, distanceM: d, cadenceSpm: nil,
                                   elevationM: nil, source: .gps, fidelity: .measured))
            raw.append([Double(t), lat0 + d / metresPerDegLat, lng0, 5, speed, nil, speedAccuracy, 0])
        }
        var effort = Effort(targetM: target)
        effort.gate = Sourced(gateMs + gateShiftMs, source: "app", fidelity: .measured, method: "gate_sound")
        effort.finish = Sourced(gateMs + Int(finishS * 1000), source: "gps", fidelity: .estimated, method: "marked_line")
        let total = points.last?.distanceM ?? 0
        return Run(id: UUID(), startedAt: t0, endedAt: nil, durationMs: (points.last?.t ?? 0) + 1000, points: points,
                   music: [], summary: RunSummary(distanceM: total, avgSpeedMps: 4, maxSpeedMps: 8, movingTimeMs: points.last?.t ?? 0),
                   rawStreams: ["gps_fixes": RawStream(source: "gps", fidelity: .measured,
                                                       fields: ["t_ms", "lat", "lng", "accuracy_m", "speed_mps", "altitude_m",
                                                                "speed_accuracy_mps", "course_deg"], samples: raw)],
                   effort: effort)
    }

    /// 4 s to 8 m/s, hold to 26 s, then fade linearly to `endSpeed` at 54 s.
    func profile(endSpeed: Double = 7) -> (Double) -> Double {
        { t in
            if t < 4 { return 8 * t / 4 }
            if t < 26 { return 8 }
            return 8 - (8 - endSpeed) * min(1, (t - 26) / 28)
        }
    }

    func history(_ fades: [Double]) -> [SprintAnalysis.Result] {
        fades.map { f in
            SprintAnalysis.Result(targetM: 400, timeMs: 55_000, mode: .splits,
                                  splits: (0..<4).map { SprintAnalysis.Split(index: $0, timeMs: 13_000, speedMps: $0 == 3 ? 7.7 * f : 7.7) },
                                  peakSplitIndex: 1, peakSampleSpeedMps: 8, fade: f, openingMs: 3_000)
        }
    }

    // MARK: Analysis

    func testSynthetic400mYieldsTheKnownFade() throws {
        let v = profile()
        let run = sprintRun(target: 400, v: v)
        let r = try XCTUnwrap(SprintAnalysis.analyze(run).result)
        let truthSpeeds = trueSplitSpeeds(truth(v, target: 400).grid, target: 400)
        let expectedFade = truthSpeeds.last! / truthSpeeds.max()!
        XCTAssertEqual(r.mode, .splits)
        XCTAssertEqual(r.splits.count, 4)
        XCTAssertEqual(r.fade!, expectedFade, accuracy: 0.01)
        XCTAssertEqual(r.peakSampleSpeedMps, 8, accuracy: 0.05)
        XCTAssertEqual(r.peakSplitIndex, 1, "split 0 carries the acceleration, so the peak is the second 100 m")
        XCTAssertNotNil(r.openingMs)
    }

    func testSplitsAreInterpolatedNotSnappedToSamples() throws {
        // Constant 7 m/s (after a short start) sampled 0.37 s off the gate: snapping
        // boundaries to 1 Hz samples would be off by up to a second per split.
        let v: (Double) -> Double = { t in t < 1 ? 7 * t : 7 }
        let run = sprintRun(target: 400, v: v)
        let r = try XCTUnwrap(SprintAnalysis.analyze(run).result)
        let truthSpeeds = trueSplitSpeeds(truth(v, target: 400).grid, target: 400)
        for (got, want) in zip(r.splits.map(\.speedMps), truthSpeeds) {
            XCTAssertEqual(got, want, accuracy: want * 0.01)
        }
    }

    func test100mIsPeakOnly() throws {
        let r = try XCTUnwrap(SprintAnalysis.analyze(sprintRun(target: 100, v: profile())).result)
        XCTAssertEqual(r.mode, .peakOnly)
        XCTAssertNil(r.fade)
        XCTAssertEqual(SprintStyle.call(r, history: []), .peakOnly)
    }

    func testRefusals() {
        let v = profile()
        var run = sprintRun(target: 400, v: v)
        run.effort = nil
        XCTAssertEqual(SprintAnalysis.analyze(run), .refused(.noEffort))

        run = sprintRun(target: 400, v: v)
        run.effort?.finish = nil
        XCTAssertEqual(SprintAnalysis.analyze(run), .refused(.noFinish))

        // Dropping the 1 Hz fixes from 20 s to 24 s leaves a 5 s hole between the neighbours.
        XCTAssertEqual(SprintAnalysis.analyze(sprintRun(target: 400, v: v, dropFrom: 20, dropTo: 24)), .refused(.gpsGap(5)))
        XCTAssertEqual(SprintAnalysis.analyze(sprintRun(target: 400, v: v, speedAccuracy: -1)), .refused(.noDoppler))

        run = sprintRun(target: 400, v: v)
        run.effort?.target = Sourced(50, source: "user", fidelity: .reported)
        XCTAssertEqual(SprintAnalysis.analyze(run), .refused(.tooShort))

        // 200 m at a slow jog is long enough; 200 m covered in 15 fixes is not.
        let quick = sprintRun(target: 200, v: { t in t < 1 ? 14 * t : 14 })
        XCTAssertEqual(SprintAnalysis.analyze(quick), .refused(.tooFewSamples))
    }

    // MARK: Style

    func testStyleWaitsForOwnHistory() throws {
        let r = try XCTUnwrap(SprintAnalysis.analyze(sprintRun(target: 400, v: profile())).result)
        XCTAssertEqual(SprintStyle.call(r, history: history([0.9, 0.91])), .needsHistory(have: 2, need: 3))
        // Other distances do not count towards a 400 m history.
        var other = history([0.9, 0.9, 0.9])
        other = other.map { h in SprintAnalysis.Result(targetM: 200, timeMs: h.timeMs, mode: .splits, splits: h.splits,
                                                         peakSplitIndex: h.peakSplitIndex, peakSampleSpeedMps: 8, fade: h.fade, openingMs: nil) }
        XCTAssertEqual(SprintStyle.call(r, history: other), .needsHistory(have: 0, need: 3))
    }

    /// Measured on this harness: ±0.3 m/s Doppler noise moves the fade by about
    /// 2–3 points from run to run, so calls within a few points of usual − δ are
    /// coin flips. This run sits about 8 points beyond the threshold, where the
    /// label must not move with noise or a ±0.5 s gate error.
    func testFadingMoreThanUsualIsAFrontRunnerAndStableUnderNoise() throws {
        let v = profile(endSpeed: 6.3)   // fade ≈ 0.86 from the peak split
        let usual = history([0.98, 0.99, 1.0])
        let clean = try XCTUnwrap(SprintAnalysis.analyze(sprintRun(target: 400, v: v)).result)
        guard case .style(let style, _, _) = SprintStyle.call(clean, history: usual) else { return XCTFail("no call") }
        XCTAssertEqual(style, .frontRunner)

        for seed in 1...100 {
            for shift in [-500, 0, 500] {
                let noisy = sprintRun(target: 400, v: v, noise: 0.3, seed: UInt64(seed), gateShiftMs: shift)
                let r = try XCTUnwrap(SprintAnalysis.analyze(noisy).result)
                guard case .style(let s, _, _) = SprintStyle.call(r, history: usual) else { return XCTFail("seed \(seed)") }
                XCTAssertEqual(s, .frontRunner, "seed \(seed), gate shift \(shift) ms")
            }
        }
    }

    func testHoldingUpAsUsualIsAPaceChaser() throws {
        let r = try XCTUnwrap(SprintAnalysis.analyze(sprintRun(target: 400, v: profile(endSpeed: 7))).result)
        guard case .style(let s, let usual, let delta) = SprintStyle.call(r, history: history([0.88, 0.9, 0.92])) else {
            return XCTFail("no call")
        }
        XCTAssertEqual(s, .paceChaser)
        XCTAssertEqual(usual, 0.9, accuracy: 1e-9)
        XCTAssertEqual(delta, 0.05, accuracy: 1e-9)
    }

    func testAPlateauNearTieIsNotALateSurge() throws {
        // Splits 2 and 3 nearly equal: noise may make either the fastest, but
        // without a real lift it is not a tactic.
        let v: (Double) -> Double = { t in t < 4 ? 8 * t / 4 : (t < 40 ? 8 : 7.6) }
        for seed in 1...50 {
            let r = try XCTUnwrap(SprintAnalysis.analyze(sprintRun(target: 400, v: v, noise: 0.3, seed: UInt64(seed))).result)
            guard case .style(let s, _, _) = SprintStyle.call(r, history: history([0.94, 0.95, 0.96])) else { return XCTFail() }
            XCTAssertNotEqual(s, .lateSurger, "seed \(seed)")
        }
    }

    func testFastestLastSplitIsAnEndCloserAndLatePeakIsALateSurger() throws {
        let closing: (Double) -> Double = { t in t < 4 ? 7 * t / 4 : (t < 40 ? 7 : 8.2) }
        let r1 = try XCTUnwrap(SprintAnalysis.analyze(sprintRun(target: 400, v: closing)).result)
        XCTAssertEqual(r1.peakSplitIndex, 3)
        guard case .style(let s1, _, _) = SprintStyle.call(r1, history: history([0.9, 0.9, 0.9])) else { return XCTFail() }
        XCTAssertEqual(s1, .endCloser)

        // Surge through the third 100 m, then ease off.
        let surge: (Double) -> Double = { t in t < 4 ? 7 * t / 4 : (t < 28 ? 7 : (t < 41 ? 8.2 : 7.4)) }
        let r2 = try XCTUnwrap(SprintAnalysis.analyze(sprintRun(target: 400, v: surge)).result)
        XCTAssertEqual(r2.peakSplitIndex, 2)
        guard case .style(let s2, _, _) = SprintStyle.call(r2, history: history([0.9, 0.9, 0.9])) else { return XCTFail() }
        XCTAssertEqual(s2, .lateSurger)
    }

    func testRegularStyleCallRefusesASprintWithACoolDownJog() {
        // 400 m sprint then six minutes of jogging: long enough for the 4-minute floor.
        let run = sprintRun(target: 400, v: profile(), jogAfterS: 360)
        XCTAssertGreaterThan(run.durationMs, 240_000)
        XCTAssertEqual(StyleClassifier.classify(run).outcome, .unclassified(.sprint))
    }

    // MARK: Finish line

    func testCrossingAMarkedLineIsInterpolated() throws {
        let v: (Double) -> Double = { _ in 7 }
        let run = sprintRun(target: 300, v: v)
        let line = LinePoint(lat: lat0 + 200 / metresPerDegLat, lng: lng0, accuracyM: 4)
        let start = LinePoint(lat: lat0, lng: lng0, accuracyM: 4)
        let t = try XCTUnwrap(LineCrossing.crossingTime(run.points, line: line,
                                                       direction: LineCrossing.bearing(from: start, to: line),
                                                       notBeforeMs: gateMs))
        // 200 m at 7 m/s from the gate: 28.571 s.
        XCTAssertEqual(Double(t - gateMs) / 1000, 200.0 / 7, accuracy: 0.05)
    }

    func testLapFinishIgnoresTheStartCrossing() throws {
        // Out 100 m north and back south past the start: a "lap" in miniature.
        var points: [RunPoint] = []
        for s in 0...40 {
            let d = s <= 20 ? 5.0 * Double(s) : 100 - 5.0 * Double(s - 20)
            // Northbound leg runs 1 m east of the line, southbound 1 m west.
            let east = s <= 20 ? 1.0 : -1.0
            points.append(RunPoint(t: gateMs + s * 1000, lat: lat0 + (d - 2) / metresPerDegLat,
                                   lng: lng0 + east / (metresPerDegLat * cos(lat0 * .pi / 180)), accuracyM: 5,
                                   rawSpeedMps: 5, speedMps: 5, distanceM: 5 * Double(s), cadenceSpm: nil,
                                   elevationM: nil, source: .gps, fidelity: .measured))
        }
        let startLine = LinePoint(lat: lat0, lng: lng0, accuracyM: 4)
        let dir = try XCTUnwrap(LineCrossing.courseBearing(points, fromMs: gateMs))
        XCTAssertEqual(dir, 0, accuracy: 0.1, "northbound start")
        // Without a not-before guard, the start crossing would count as the finish.
        let early = LineCrossing.crossingTime(points, line: startLine, direction: dir, notBeforeMs: gateMs)
        XCTAssertNotNil(early)
        // Returning south, the line is crossed in the opposite direction: a lap finish
        // uses the reverse bearing on an out-and-back, and the guard skips the start.
        let finish = LineCrossing.crossingTime(points, line: startLine, direction: dir + .pi, notBeforeMs: gateMs + 21_000)
        XCTAssertEqual(Double(try XCTUnwrap(finish) - gateMs) / 1000, 39.6, accuracy: 0.2)
    }

    // MARK: Schema and policy

    func testV4FilesDecodeUnderV5() throws {
        let v4 = """
        {"id":"\(UUID().uuidString)","schema_version":4,"started_at":"2026-11-08T05:40:00Z","ended_at":null,
         "duration_ms":1000,"points":[],"music":[],"armed_at":null,"annotations":{"feel":[],"intent":[]},
         "summary":{"distance_m":0,"avg_speed_mps":0,"max_speed_mps":0,"moving_time_ms":0},
         "raw_streams":{"gps_fixes":{"source":"gps","fidelity":"measured",
           "fields":["t_ms","lat","lng","accuracy_m","speed_mps","altitude_m"],"samples":[[0,35.6,139.7,5,3,null]]}}}
        """
        let run = try Run.fromJSON(Data(v4.utf8))
        XCTAssertNil(run.effort)
        XCTAssertEqual(run.rawStreams["gps_fixes"]?.fields.count, 6)
    }

    func testEffortRoundTripsWithExplicitNulls() throws {
        let run = sprintRun(target: 400, v: profile())
        let text = String(decoding: try run.jsonData(), as: UTF8.self)
        XCTAssertTrue(text.contains("\"protocol\" : \"line_to_line\""))
        XCTAssertTrue(text.contains("\"first_movement_t_ms\" : null"))
        XCTAssertTrue(text.contains("\"speed_accuracy_mps\""))
        XCTAssertEqual(try Run.fromJSON(run.jsonData()), run)
    }

    func testDistancesAndFirstMovement() {
        let run = sprintRun(target: 400, v: profile())
        let finish = run.effort!.finish!.value
        let d = EffortMeasure.distances(run.points, gateMs: gateMs, finishMs: finish)
        XCTAssertEqual(d.doppler, 400, accuracy: 4)
        XCTAssertEqual(d.gps, 400, accuracy: 10)
        let first = EffortMeasure.firstMovementMs(run.points, gateMs: gateMs, finishMs: finish)
        XCTAssertEqual(first, gateMs + 1_370, "first fix above walking pace")
    }

    func testSprintArmingNeverOffersSteps() {
        XCTAssertEqual(ArmingPolicy.decide(indoor: true, locationAuthorized: true, pedometerReady: true, hasFix: true, sprint: true),
                       .blocked(.sprintNeedsGPS))
        XCTAssertEqual(ArmingPolicy.decide(indoor: false, locationAuthorized: true, pedometerReady: true, hasFix: false, sprint: true), .arm)
        XCTAssertEqual(ArmingPolicy.fallback(waited: 120, pedometerReady: true, sprint: true), .keepWaitingOnly)
    }
}
