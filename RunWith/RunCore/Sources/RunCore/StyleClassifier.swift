import Foundation

/// Single-run effort-distribution probe (diagnostic doc §2.1): from cleaned
/// speed and cumulative distance alone, name the shape of one self-paced run
/// as one of four styles, or decline. Deterministic, no literature, no HR.
///
/// The call is provisional by construction. A style is a tendency across
/// many runs; this says only "you ran like X this time". Thresholds are the
/// doc's illustrative starting points and are meant to be tuned on real runs.
public enum StyleClassifier {
    /// The 脚質 taxonomy with its user-facing English names.
    public enum Style: String, Codable, CaseIterable, Sendable {
        case frontRunner = "nige"     // 逃げ: fast start, fades
        case paceChaser = "senko"     // 先行: even, no dominant spike or fade
        case lateSurger = "sashi"     // 差し: lifts in the third quarter
        case endCloser = "oikomi"     // 追込: sharp final-quarter jump

        public var englishName: String {
            switch self {
            case .frontRunner: return "Front Runner"
            case .paceChaser: return "Pace Chaser"
            case .lateSurger: return "Late Surger"
            case .endCloser: return "End Closer"
            }
        }

        public var japaneseName: String {
            switch self {
            case .frontRunner: return "逃げ"
            case .paceChaser: return "先行"
            case .lateSurger: return "差し"
            case .endCloser: return "追込"
            }
        }
    }

    /// Why no label was given. Each is an explained outcome, never a silent null.
    public enum Refusal: Equatable, Sendable {
        /// Under the minimum duration or too few clean points to read a shape.
        case tooShort
        /// Quarters within the noise floor of each other: nothing to read.
        case flat
        /// Speed came from the step counter only: a belt set the pace, not the runner.
        case treadmill
        /// No distance accrued, so there are no quarters.
        case noDistance
    }

    public enum Outcome: Equatable, Sendable {
        case style(Style)
        case unclassified(Refusal)
    }

    public struct Result: Equatable, Sendable {
        public let outcome: Outcome
        /// Each quarter's speed relative to the run's own average (1.0 = average).
        /// Empty when the run could not be split.
        public let quarterRatios: [Double]
        /// True when elevation was present and speeds were grade-adjusted first.
        public let gradeAdjusted: Bool

        public var style: Style? {
            if case .style(let s) = outcome { return s }
            return nil
        }
    }

    public struct Config: Sendable {
        public var minDurationMs = 240_000
        public var minPoints = 120
        /// Warm-up and cool-down trimmed from each end, by distance, on runs long enough.
        public var trimFraction = 0.05
        public var trimMinDurationMs = 480_000
        /// Below this speed a sample counts as stopped and is left out of the quarters.
        public var stoppedBelowMps = 0.5
        /// Doc's illustrative starting points. Deviations are relative to the runner's own average.
        public var kickThreshold = 0.05
        public var surgeThreshold = 0.04
        public var declineThreshold = 0.05
        /// If no quarter strays further than this from average, there is no signal.
        public var noiseFloor = 0.015
        /// Grade is read over this much horizontal distance either side of a point.
        public var gradeWindowM = 50.0
        /// Elevation has to be present on this share of points to be used.
        public var minElevationCoverage = 0.8

        public init() {}
    }

    // MARK: Classify

    public static func classify(_ run: Run, config: Config = Config()) -> Result {
        let points = run.points
        guard run.durationMs >= config.minDurationMs, points.count >= config.minPoints else {
            return Result(outcome: .unclassified(.tooShort), quarterRatios: [], gradeAdjusted: false)
        }
        // A fixed belt dictates pace, which violates the self-paced precondition.
        if points.allSatisfy({ $0.fidelity == .proxy }) {
            return Result(outcome: .unclassified(.treadmill), quarterRatios: [], gradeAdjusted: false)
        }
        guard let total = points.last?.distanceM, total > 0 else {
            return Result(outcome: .unclassified(.noDistance), quarterRatios: [], gradeAdjusted: false)
        }

        // Speeds, grade-adjusted when the trace carries elevation.
        let grades = gradeSeries(points, config: config)
        let adjusted = grades != nil
        let speeds: [Double] = points.enumerated().map { i, p in
            guard let g = grades?[i] else { return p.speedMps }
            return p.speedMps * Grade.costRatio(grade: g)
        }

        // Active portion: trim warm-up and cool-down by distance on longer runs.
        let trim = run.durationMs >= config.trimMinDurationMs ? config.trimFraction : 0
        let start = total * trim
        let end = total * (1 - trim)
        let span = end - start
        guard span > 0 else {
            return Result(outcome: .unclassified(.noDistance), quarterRatios: [], gradeAdjusted: adjusted)
        }

        // Quarters by distance. Each quarter's speed is distance over moving
        // time, so a stop inside it does not drag the quarter down.
        var movingTime = [Double](repeating: 0, count: 4)
        var distance = [Double](repeating: 0, count: 4)
        for i in 1..<points.count {
            let p = points[i], prev = points[i - 1]
            let dt = Double(p.t - prev.t) / 1000
            let ds = p.distanceM - prev.distanceM
            guard dt > 0, ds > 0, p.speedMps >= config.stoppedBelowMps else { continue }
            let mid = (p.distanceM + prev.distanceM) / 2
            guard mid >= start, mid < end else { continue }
            let q = min(3, Int((mid - start) / span * 4))
            // Grade-adjusted distance: equivalent flat metres covered in dt.
            distance[q] += speeds[i] * dt
            movingTime[q] += dt
        }
        guard movingTime.allSatisfy({ $0 > 0 }) else {
            return Result(outcome: .unclassified(.tooShort), quarterRatios: [], gradeAdjusted: adjusted)
        }
        let quarterSpeed = (0..<4).map { distance[$0] / movingTime[$0] }
        let mean = distance.reduce(0, +) / movingTime.reduce(0, +)
        let r = quarterSpeed.map { $0 / mean }

        // Shape.
        let peak = r.indices.max { r[$0] < r[$1] }!
        let decline = r[0] - r[3]
        let lateKick = r[3] - max(r[0], r[1], r[2])
        let midSurge = r[2] - (r[0] + r[1]) / 2

        guard r.contains(where: { abs($0 - 1) >= config.noiseFloor }) else {
            return Result(outcome: .unclassified(.flat), quarterRatios: r, gradeAdjusted: adjusted)
        }

        let style: Style
        if peak == 3, lateKick > config.kickThreshold {
            style = .endCloser
        } else if peak == 2 || midSurge > config.surgeThreshold {
            style = .lateSurger
        } else if peak == 0, decline > config.declineThreshold {
            style = .frontRunner
        } else {
            style = .paceChaser
        }
        return Result(outcome: .style(style), quarterRatios: r, gradeAdjusted: adjusted)
    }

    // MARK: Grade

    /// Per-point grade (rise over run, as a fraction) read over a window of
    /// horizontal distance either side, or nil when elevation is too sparse.
    static func gradeSeries(_ points: [RunPoint], config: Config) -> [Double]? {
        let withElevation = points.filter { $0.elevationM != nil }.count
        guard points.count > 1, Double(withElevation) / Double(points.count) >= config.minElevationCoverage else { return nil }
        let n = points.count
        var grades = [Double](repeating: 0, count: n)
        var lo = 0, hi = 0
        for i in 0..<n {
            let d = points[i].distanceM
            while points[lo].distanceM < d - config.gradeWindowM { lo += 1 }
            while hi + 1 < n, points[hi + 1].distanceM <= d + config.gradeWindowM { hi += 1 }
            // Nearest elevation-bearing points at each end of the window.
            guard let a = (lo...i).first(where: { points[$0].elevationM != nil }),
                  let b = (i...hi).last(where: { points[$0].elevationM != nil }) else { continue }
            let run = points[b].distanceM - points[a].distanceM
            guard run >= 20, let ea = points[a].elevationM, let eb = points[b].elevationM else { continue }
            grades[i] = min(max((eb - ea) / run, -0.25), 0.25)
        }
        return grades
    }

    enum Grade {
        /// Energy cost of running on a grade relative to flat (Minetti et al.
        /// 2002), used as a grade-adjusted-pace factor: uphill speed counts
        /// for more, downhill for less.
        static func costRatio(grade i: Double) -> Double {
            let c = 155.4 * pow(i, 5) - 30.4 * pow(i, 4) - 43.3 * pow(i, 3) + 46.3 * pow(i, 2) + 19.5 * i + 3.6
            return max(0.5, min(3.0, c / 3.6))
        }
    }
}
