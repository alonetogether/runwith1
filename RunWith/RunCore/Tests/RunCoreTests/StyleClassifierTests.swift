import XCTest
@testable import RunCore

final class StyleClassifierTests: XCTestCase {
    /// A run at 1 Hz where `speed(f)` is m/s at fraction f (0..1) of the way through,
    /// and `elevation(f)` metres if given.
    func makeRun(seconds: Int = 1200, speed: (Double) -> Double, elevation: ((Double) -> Double)? = nil,
                 fidelity: Fidelity = .measured) -> Run {
        var points: [RunPoint] = []
        var dist = 0.0
        for s in 0..<seconds {
            let f = Double(s) / Double(seconds)
            let v = speed(f)
            dist += v
            points.append(RunPoint(t: s * 1000, lat: 35.67, lng: 139.70, accuracyM: 5, rawSpeedMps: v, speedMps: v,
                                   distanceM: dist, cadenceSpm: nil, elevationM: elevation?(f),
                                   source: fidelity == .proxy ? .pedometer : .gps, fidelity: fidelity))
        }
        return Run(id: UUID(), startedAt: Date(timeIntervalSince1970: 0), endedAt: nil, durationMs: seconds * 1000,
                   points: points, music: [],
                   summary: RunSummary(distanceM: dist, avgSpeedMps: dist / Double(seconds), maxSpeedMps: 4, movingTimeMs: seconds * 1000),
                   rawStreams: [:])
    }

    func testEvenRunIsAPaceChaser() {
        // Gentle 2% wobble: above the noise floor, below every threshold.
        let run = makeRun { f in 3.0 + 0.06 * sin(f * 6.28) }
        XCTAssertEqual(StyleClassifier.classify(run).style, .paceChaser)
    }

    func testFastStartThatFadesIsAFrontRunner() {
        let run = makeRun { f in 3.4 - 0.5 * f }   // 3.4 down to 2.9
        let r = StyleClassifier.classify(run)
        XCTAssertEqual(r.style, .frontRunner)
        XCTAssertGreaterThan(r.quarterRatios[0], r.quarterRatios[3])
    }

    func testThirdQuarterLiftIsALateSurger() {
        let run = makeRun { f in (0.5..<0.75).contains(f) ? 3.3 : 3.0 }
        XCTAssertEqual(StyleClassifier.classify(run).style, .lateSurger)
    }

    func testFinalQuarterKickIsAnEndCloser() {
        let run = makeRun { f in f >= 0.75 ? 3.4 : 3.0 }
        XCTAssertEqual(StyleClassifier.classify(run).style, .endCloser)
    }

    func testDownhillFinishIsNotCreditedAsAKick() {
        // 8% faster in the last quarter, but it is a 5% descent: grade-adjusted it is no kick.
        let run = makeRun(speed: { f in f >= 0.75 ? 3.24 : 3.0 },
                          elevation: { f in f < 0.75 ? 50 : 50 - (f - 0.75) * 4 * 45 })
        let r = StyleClassifier.classify(run)
        XCTAssertTrue(r.gradeAdjusted)
        XCTAssertNotEqual(r.style, .endCloser)
    }

    func testSameFinishWithoutElevationIsAKick() {
        let run = makeRun { f in f >= 0.75 ? 3.24 : 3.0 }
        let r = StyleClassifier.classify(run)
        XCTAssertFalse(r.gradeAdjusted)
        XCTAssertEqual(r.style, .endCloser)
    }

    func testStopsInsideAQuarterDoNotDragIt() {
        // Even run with a 90 s traffic light in the second quarter.
        let run = makeRun { f in (0.30..<0.375).contains(f) ? 0.0 : 3.0 }
        let r = StyleClassifier.classify(run)
        XCTAssertEqual(r.outcome, .unclassified(.flat), "a stop is not a slow quarter")
    }

    func testShortRunIsRefused() {
        let run = makeRun(seconds: 180) { f in f >= 0.75 ? 3.4 : 3.0 }
        XCTAssertEqual(StyleClassifier.classify(run).outcome, .unclassified(.tooShort))
    }

    func testTreadmillIsRefusedByDesign() {
        let run = makeRun(speed: { f in f >= 0.75 ? 3.4 : 3.0 }, fidelity: .proxy)
        XCTAssertEqual(StyleClassifier.classify(run).outcome, .unclassified(.treadmill))
    }

    func testPerfectlyFlatRunHasNoSignal() {
        let run = makeRun { _ in 3.0 }
        XCTAssertEqual(StyleClassifier.classify(run).outcome, .unclassified(.flat))
    }

    func testGradeCostIsOneOnTheFlatAndOrderedBySlope() {
        XCTAssertEqual(StyleClassifier.Grade.costRatio(grade: 0), 1, accuracy: 1e-9)
        XCTAssertGreaterThan(StyleClassifier.Grade.costRatio(grade: 0.05), 1)
        XCTAssertLessThan(StyleClassifier.Grade.costRatio(grade: -0.05), 1)
    }
}
