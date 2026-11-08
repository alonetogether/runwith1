import Foundation

// MARK: - Finish-line geometry

/// Crossing a marked line, in a local flat frame (equirectangular around the
/// line; at sprint scale the error is millimetres). A marked line is a point
/// the runner stood on; the line through it runs perpendicular to the
/// direction of travel.
public enum LineCrossing {
    /// Metres east and north of `origin`.
    static func xy(lat: Double, lng: Double, origin: LinePoint) -> (x: Double, y: Double) {
        let k = Double.pi / 180 * Geo.earthRadiusM
        return ((lng - origin.lng) * k * cos(origin.lat * .pi / 180), (lat - origin.lat) * k)
    }

    /// Bearing from one point to another, radians clockwise from north.
    public static func bearing(from a: LinePoint, to b: LinePoint) -> Double {
        let p = xy(lat: b.lat, lng: b.lng, origin: a)
        return atan2(p.x, p.y)
    }

    /// Direction of the first `metres` of travel after `fromMs`, for a lap
    /// where start and finish are the same line.
    public static func courseBearing(_ points: [RunPoint], fromMs: Int, metres: Double = 20) -> Double? {
        let after = points.filter { $0.t >= fromMs && $0.lat != nil && $0.lng != nil }
        guard let first = after.first, let lat0 = first.lat, let lng0 = first.lng else { return nil }
        let origin = LinePoint(lat: lat0, lng: lng0, accuracyM: 0)
        for p in after.dropFirst() {
            let q = xy(lat: p.lat!, lng: p.lng!, origin: origin)
            if hypot(q.x, q.y) >= metres { return atan2(q.x, q.y) }
        }
        return nil
    }

    /// Run time (ms) at which the track crosses the line through `line`,
    /// moving along `direction`, no earlier than `notBeforeMs`. Interpolated
    /// linearly between the two fixes either side of the line.
    public static func crossingTime(_ points: [RunPoint], line: LinePoint, direction: Double, notBeforeMs: Int) -> Int? {
        let ux = sin(direction), uy = cos(direction)
        var prev: (t: Int, s: Double)?
        for p in points where p.t >= notBeforeMs {
            guard let lat = p.lat, let lng = p.lng else { continue }
            let q = xy(lat: lat, lng: lng, origin: line)
            let s = q.x * ux + q.y * uy   // signed metres past the line
            if let pr = prev, pr.s < 0, s >= 0 {
                let f = -pr.s / (s - pr.s)
                return pr.t + Int((Double(p.t - pr.t) * f).rounded())
            }
            prev = (p.t, s)
        }
        return nil
    }
}

// MARK: - Measuring an effort

public enum EffortMeasure {
    /// Doppler speed for a point, falling back to the cleaner's raw speed.
    static func speed(_ p: RunPoint) -> Double { p.rawSpeedMps ?? p.speedMps }

    static func segment(_ points: [RunPoint], gateMs: Int, finishMs: Int) -> [RunPoint] {
        points.filter { $0.source == .gps && $0.t >= gateMs && $0.t <= finishMs }
    }

    /// Distance covered from the gate as a piecewise-linear curve of (t_ms, metres),
    /// integrating Doppler speed. The runner starts from rest at the gate, and
    /// the last speed carries on to the finish.
    static func integratedCurve(_ seg: [RunPoint], gateMs: Int, finishMs: Int) -> [(t: Int, d: Double)] {
        guard let first = seg.first else { return [] }
        var curve: [(Int, Double)] = [(gateMs, 0)]
        var d = speed(first) * Double(first.t - gateMs) / 2000
        curve.append((first.t, d))
        for i in 1..<max(1, seg.count) where i < seg.count {
            let a = seg[i - 1], b = seg[i]
            d += (speed(a) + speed(b)) / 2 * Double(b.t - a.t) / 1000
            curve.append((b.t, d))
        }
        if let last = seg.last, finishMs > last.t {
            d += speed(last) * Double(finishMs - last.t) / 1000
            curve.append((finishMs, d))
        }
        return curve
    }

    /// Distances between gate and finish: from positions, and from Doppler speed.
    public static func distances(_ points: [RunPoint], gateMs: Int, finishMs: Int) -> (gps: Double, doppler: Double) {
        let seg = segment(points, gateMs: gateMs, finishMs: finishMs)
        var gps = 0.0
        for i in 1..<max(1, seg.count) where i < seg.count {
            if let a1 = seg[i - 1].lat, let o1 = seg[i - 1].lng, let a2 = seg[i].lat, let o2 = seg[i].lng {
                gps += Geo.haversineM(lat1: a1, lng1: o1, lat2: a2, lng2: o2)
            }
        }
        return (gps, integratedCurve(seg, gateMs: gateMs, finishMs: finishMs).last?.d ?? 0)
    }

    /// First sample after the gate moving faster than walking pace.
    public static func firstMovementMs(_ points: [RunPoint], gateMs: Int, finishMs: Int, threshold: Double = 1.5) -> Int? {
        segment(points, gateMs: gateMs, finishMs: finishMs).first { speed($0) >= threshold }?.t
    }
}

// MARK: - Analysis

/// What one sprint was, in numbers: time, interpolated 100 m splits, peak,
/// fade from the peak split, and the opening. Deterministic, no labels.
public enum SprintAnalysis {
    public struct Split: Equatable, Sendable {
        public let index: Int
        public let timeMs: Int
        public let speedMps: Double
    }

    public enum Mode: Equatable, Sendable {
        /// Under 200 m: a peak-speed measurement only (Diagnostic §2).
        case peakOnly
        case splits
    }

    public enum Refusal: Equatable, Sendable {
        case noEffort
        case noFinish
        case tooShort
        case notMultipleOf100
        /// A gap in GPS fixes inside the race, in seconds.
        case gpsGap(Int)
        case tooFewSamples
        /// Most fixes in the race carried no valid Doppler speed.
        case noDoppler
    }

    public struct Result: Equatable, Sendable {
        public let targetM: Double
        public let timeMs: Int
        public let mode: Mode
        public let splits: [Split]
        public let peakSplitIndex: Int
        /// Fastest single sample, the top-speed number.
        public let peakSampleSpeedMps: Double
        /// Last split's speed against the peak split's (1.0 when the last split is the peak).
        public let fade: Double?
        /// Gate to the first sample at 90% of peak speed. Stored, not classified:
        /// at 1 Hz it resolves ±1 s and Doppler is weakest while accelerating.
        public let openingMs: Int?
    }

    public enum Outcome: Equatable, Sendable {
        case result(Result)
        case refused(Refusal)

        public var result: Result? {
            if case .result(let r) = self { return r }
            return nil
        }
    }

    public struct Config: Sendable {
        public var maxGapMs = 2_000
        public var minSamplesForSplits = 20
        public var minSamplesPeakOnly = 8
        public var minValidDopplerShare = 0.8
        public init() {}
    }

    public static func analyze(_ run: Run, config: Config = Config()) -> Outcome {
        guard let effort = run.effort else { return .refused(.noEffort) }
        guard let gate = effort.gate?.value, let finish = effort.finish?.value, finish > gate else {
            return .refused(.noFinish)
        }
        let target = effort.target.value
        guard target >= 100 else { return .refused(.tooShort) }
        guard target.truncatingRemainder(dividingBy: 100) == 0 else { return .refused(.notMultipleOf100) }

        let seg = EffortMeasure.segment(run.points, gateMs: gate, finishMs: finish)
        let mode: Mode = target < 200 ? .peakOnly : .splits
        let minSamples = mode == .splits ? config.minSamplesForSplits : config.minSamplesPeakOnly
        guard seg.count >= minSamples else { return .refused(.tooFewSamples) }

        // Gaps, including gate to first fix and last fix to finish.
        let times = [gate] + seg.map(\.t) + [finish]
        let worst = zip(times, times.dropFirst()).map { $1 - $0 }.max() ?? 0
        guard worst <= config.maxGapMs else { return .refused(.gpsGap(Int((Double(worst) / 1000).rounded()))) }

        // Doppler validity from the raw stream, when this run recorded it (v5).
        if let raw = run.rawStreams["gps_fixes"], let ai = raw.fields.firstIndex(of: "speed_accuracy_mps") {
            let inRace = raw.samples.filter { s in (s.first ?? nil).map { Int($0) >= gate && Int($0) <= finish } ?? false }
            let valid = inRace.filter { ai < $0.count && ($0[ai] ?? -1) >= 0 }.count
            if !inRace.isEmpty, Double(valid) / Double(inRace.count) < config.minValidDopplerShare {
                return .refused(.noDoppler)
            }
        }

        // Split boundaries by integrated Doppler distance, scaled so the race
        // is exactly the marked line-to-line target, interpolated in time.
        let curve = EffortMeasure.integratedCurve(seg, gateMs: gate, finishMs: finish)
        guard let total = curve.last?.d, total > 0 else { return .refused(.tooFewSamples) }
        let n = Int(target / 100)
        let scale = total / target
        var boundaries: [Double] = [Double(gate)]
        for j in 1..<n {
            boundaries.append(timeAt(distance: Double(j) * 100 * scale, curve: curve))
        }
        boundaries.append(Double(finish))
        let splits = (0..<n).map { j -> Split in
            let dt = boundaries[j + 1] - boundaries[j]
            return Split(index: j, timeMs: Int(dt.rounded()), speedMps: dt > 0 ? 100_000 / dt : 0)
        }

        let peakSplit = splits.indices.max { splits[$0].speedMps < splits[$1].speedMps } ?? 0
        let peakSample = seg.map(EffortMeasure.speed).max() ?? 0
        let opening = seg.first { EffortMeasure.speed($0) >= 0.9 * peakSample }.map { $0.t - gate }
        let fade: Double? = mode == .splits ? splits[n - 1].speedMps / splits[peakSplit].speedMps : nil

        return .result(Result(targetM: target, timeMs: finish - gate, mode: mode, splits: splits,
                              peakSplitIndex: peakSplit, peakSampleSpeedMps: peakSample,
                              fade: fade, openingMs: opening))
    }

    static func timeAt(distance d: Double, curve: [(t: Int, d: Double)]) -> Double {
        for i in 1..<curve.count where curve[i].d >= d {
            let a = curve[i - 1], b = curve[i]
            let f = b.d > a.d ? (d - a.d) / (b.d - a.d) : 0
            return Double(a.t) + Double(b.t - a.t) * f
        }
        return Double(curve.last?.t ?? 0)
    }
}

// MARK: - Style

/// The sprint's style call, against the runner's own history at the same
/// distance, never a population norm: in 400 m research the fittest runners
/// fade most, so a population baseline would label fitness, not style.
/// Until there is enough history, numbers only.
public enum SprintStyle {
    public enum Outcome: Equatable, Sendable {
        case style(StyleClassifier.Style, usualFade: Double, delta: Double)
        case needsHistory(have: Int, need: Int)
        case peakOnly
    }

    public static let minHistory = 3
    public static let minDelta = 0.05
    /// A late split must beat the best earlier one by this much to count as a
    /// surge: on a plateau, 1 Hz Doppler noise (~1–2% per split) decides which
    /// near-equal split is "fastest", and that must not read as a tactic.
    public static let minLift = 0.04

    /// Last split against the best split before it. At 200 m this is mostly
    /// the standing start, which is why it is only ever compared with the
    /// runner's own usual, never read on its own.
    static func closing(_ splits: [SprintAnalysis.Split]) -> Double? {
        guard splits.count >= 2, let best = splits.dropLast().map(\.speedMps).max(), best > 0 else { return nil }
        return splits[splits.count - 1].speedMps / best
    }

    /// `history`: earlier sprints at the same distance (splits mode only).
    public static func call(_ result: SprintAnalysis.Result, history: [SprintAnalysis.Result]) -> Outcome {
        guard result.mode == .splits, let fade = result.fade, let close = closing(result.splits) else { return .peakOnly }
        let past = history.filter { $0.mode == .splits && $0.targetM == result.targetM && $0.fade != nil }
        guard past.count >= minHistory else { return .needsHistory(have: past.count, need: minHistory) }

        let pastFades = past.compactMap(\.fade)
        let pastClosings = past.compactMap { closing($0.splits) }
        let usual = median(pastFades)
        let usualClosing = median(pastClosings)
        // Robust spread of the runner's own fades; δ never tighter than it, so
        // real measurement noise widens the band instead of flipping labels.
        let spread = 1.4826 * median(pastFades.map { abs($0 - usual) })
        let delta = max(minDelta, spread)

        let splits = result.splits
        let n = splits.count
        let style: StyleClassifier.Style
        if close >= usualClosing + delta {
            style = .endCloser          // closed clearly harder than this runner usually does
        } else if n >= 3, let surge = lateSurge(splits), surge {
            style = .lateSurger         // a real lift in the second half, then eased
        } else if fade < usual - delta {
            style = .frontRunner        // faded more than this runner usually does
        } else {
            style = .paceChaser         // held up as usual, or better
        }
        return .style(style, usualFade: usual, delta: delta)
    }

    /// Fastest split lands in the second half (not the last) and beats the
    /// best first-half split by `minLift`.
    static func lateSurge(_ splits: [SprintAnalysis.Split]) -> Bool? {
        let n = splits.count
        guard n >= 3 else { return nil }
        let early = splits[0..<(n / 2)].map(\.speedMps).max() ?? 0
        let late = splits[(n / 2)..<(n - 1)].map(\.speedMps).max() ?? 0
        let peak = splits.indices.max { splits[$0].speedMps < splits[$1].speedMps } ?? 0
        return peak >= n / 2 && peak < n - 1 && late >= early * (1 + minLift)
    }

    static func median(_ xs: [Double]) -> Double {
        let s = xs.sorted()
        guard !s.isEmpty else { return 0 }
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }
}
