import XCTest
@testable import RunCore

final class AnnotationsTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    func track(seconds: Int, from t0: Date) -> [LocationFix] {
        (0..<seconds).map { i in
            LocationFix(timestamp: t0.addingTimeInterval(Double(i)), lat: 35.67 + 3 * Double(i) / 111_000, lng: 139.70,
                        horizontalAccuracyM: 5, speedMps: nil, altitudeM: nil, verticalAccuracyM: nil)
        }
    }

    func testCurrentSchemaEncodesExplicitNullsAndEmptyAnnotations() throws {
        var b = RunBuilder(startedAt: start)
        for f in track(seconds: 3, from: start) { b.addFix(f) }
        let text = String(decoding: try b.finish(at: start.addingTimeInterval(3)).jsonData(), as: UTF8.self)
        XCTAssertTrue(text.contains("\"schema_version\" : \(Run.currentSchemaVersion)"))
        XCTAssertTrue(text.contains("\"armed_at\" : null"))
        XCTAssertTrue(text.contains("\"annotations\""))
    }

    func testOlderFilesDecodeWithEmptyAnnotations() throws {
        let v3 = """
        {"id":"\(UUID().uuidString)","schema_version":3,"started_at":"2026-11-08T05:40:00Z","ended_at":null,
         "duration_ms":1000,"points":[],"raw_streams":{},"music":[],
         "summary":{"distance_m":0,"avg_speed_mps":0,"max_speed_mps":0,"moving_time_ms":0}}
        """
        let run = try Run.fromJSON(Data(v3.utf8))
        XCTAssertEqual(run.annotations, RunAnnotations())
        XCTAssertNil(run.armedAt)
        // Annotating re-saves in the current format, so the version follows.
        XCTAssertEqual(run.annotated { $0.recordFeel(3, at: Date()) }.schemaVersion, Run.currentSchemaVersion)
    }

    func testAnnotationsCarryProvenanceAndAreAppendOnly() throws {
        var b = RunBuilder(startedAt: start, armedAt: start.addingTimeInterval(-40),
                           intent: Reported(.easy, at: start.addingTimeInterval(-40)))
        for f in track(seconds: 3, from: start) { b.addFix(f) }
        let run = b.finish(at: start.addingTimeInterval(3))
            .annotated { $0.recordFeel(4, at: self.start.addingTimeInterval(10)) }
            .annotated { $0.recordFeel(2, at: self.start.addingTimeInterval(3 * 86_400)) }

        XCTAssertEqual(run.annotations.currentIntent, .easy)
        XCTAssertEqual(run.annotations.feel.map(\.value), [4, 2], "an edit appends, it does not overwrite")
        XCTAssertEqual(run.annotations.currentFeel, 2)
        XCTAssertEqual(run.annotations.feel.first?.fidelity, .reported)
        XCTAssertEqual(run.annotations.feel.first?.source, "user")

        let data = try run.jsonData()
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"fidelity\" : \"reported\""))
        XCTAssertTrue(text.contains("\"recorded_at\""))
        XCTAssertEqual(try Run.fromJSON(data), run)
    }

    func testAnnotatingLeavesEverythingMeasuredByteIdentical() throws {
        var b = RunBuilder(startedAt: start)
        for f in track(seconds: 20, from: start) { b.addFix(f) }
        let original = b.finish(at: start.addingTimeInterval(20))
        let changed = original.annotated { $0.recordFeel(5, at: self.start.addingTimeInterval(30)) }
        let enc = Run.makeEncoder()
        XCTAssertEqual(try enc.encode(changed.points), try enc.encode(original.points))
        XCTAssertEqual(try enc.encode(changed.music), try enc.encode(original.music))
        XCTAssertEqual(try enc.encode(changed.rawStreams), try enc.encode(original.rawStreams))
        XCTAssertEqual(try enc.encode(changed.summary), try enc.encode(original.summary))
        XCTAssertNotEqual(changed.annotations, original.annotations)
    }

    func testFeelIsClampedToTheScale() {
        var a = RunAnnotations()
        a.recordFeel(9, at: start)
        a.recordFeel(-1, at: start)
        XCTAssertEqual(a.feel.map(\.value), [5, 1])
    }

    func testBuilderWithIntentSurvivesCheckpointAndOldCheckpointsStillDecode() throws {
        var b = RunBuilder(startedAt: start, armedAt: start.addingTimeInterval(-30), intent: Reported(.push, at: start))
        for f in track(seconds: 5, from: start) { b.addFix(f) }
        let data = try JSONEncoder().encode(b)
        let back = try JSONDecoder().decode(RunBuilder.self, from: data)
        XCTAssertEqual(back.intent?.value, .push)
        XCTAssertEqual(back.armedAt, start.addingTimeInterval(-30))

        // A checkpoint from the previous build has neither key.
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "intent")
        json.removeValue(forKey: "armedAt")
        let old = try JSONDecoder().decode(RunBuilder.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(old.intent)
        XCTAssertEqual(old.points.count, 5)
    }

    func testBuilderSeededWithTheFirstPassingFixStartsAtZero() {
        let fix = track(seconds: 1, from: start)[0]
        var b = RunBuilder(startedAt: fix.timestamp, armedAt: start.addingTimeInterval(-45))
        b.recordPreStartFix(LocationFix(timestamp: start.addingTimeInterval(-10), lat: 35.6, lng: 139.6,
                                        horizontalAccuracyM: 80, speedMps: nil, altitudeM: nil, verticalAccuracyM: nil))
        b.addFix(fix)
        let run = b.finish(at: start.addingTimeInterval(5))
        XCTAssertEqual(run.points.first?.t, 0)
        XCTAssertEqual(run.points.count, 1, "a pre-start fix is raw data, never a point")
        XCTAssertEqual(run.rawStreams["gps_fixes"]?.samples.first?.first ?? nil, -10_000)
        XCTAssertEqual(run.armedAt, start.addingTimeInterval(-45))
    }

    func testWalkDeclinesTheStyleCallAndOtherIntentsDoNot() {
        // 20 minutes with a clear final-quarter kick.
        var b = RunBuilder(startedAt: start)
        var lat = 35.67
        for s in 0..<1200 {
            let v = s >= 900 ? 3.4 : 3.0
            lat += v / 111_000
            b.addFix(LocationFix(timestamp: start.addingTimeInterval(Double(s)), lat: lat, lng: 139.70,
                                 horizontalAccuracyM: 5, speedMps: v, altitudeM: nil, verticalAccuracyM: nil))
        }
        let run = b.finish(at: start.addingTimeInterval(1200))
        XCTAssertEqual(StyleClassifier.classify(run.annotated { $0.recordIntent(.walk, at: self.start) }).outcome,
                       .unclassified(.walk))
        XCTAssertEqual(StyleClassifier.classify(run.annotated { $0.recordIntent(.easy, at: self.start) }).style, .endCloser)
        XCTAssertEqual(StyleClassifier.classify(run.annotated { $0.recordIntent(.push, at: self.start) }).style, .endCloser)
    }

    func testArmingPolicy() {
        XCTAssertEqual(ArmingPolicy.decide(indoor: false, locationAuthorized: true, pedometerReady: false, hasFix: true), .startNow)
        XCTAssertEqual(ArmingPolicy.decide(indoor: false, locationAuthorized: true, pedometerReady: true, hasFix: false), .arm)
        XCTAssertEqual(ArmingPolicy.decide(indoor: false, locationAuthorized: false, pedometerReady: true, hasFix: false),
                       .blocked(.locationNotAuthorized))
        XCTAssertEqual(ArmingPolicy.decide(indoor: true, locationAuthorized: false, pedometerReady: true, hasFix: false), .startOnSteps)
        XCTAssertEqual(ArmingPolicy.decide(indoor: true, locationAuthorized: true, pedometerReady: false, hasFix: true),
                       .blocked(.stepsUnavailable))
        XCTAssertEqual(ArmingPolicy.fallback(waited: 89, pedometerReady: true), .none)
        XCTAssertEqual(ArmingPolicy.fallback(waited: 90, pedometerReady: true), .offerSteps)
        XCTAssertEqual(ArmingPolicy.fallback(waited: 200, pedometerReady: false), .keepWaitingOnly)
    }
}
