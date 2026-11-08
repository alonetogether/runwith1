import Foundation

/// What tapping Start should do, as a pure function so the recorder's choice
/// is testable at the desk. Diagnostic §6 discipline 3 (no silent-failure
/// run) holds by construction: no point and no clock exist before a fix
/// passes, unless the runner chose the step source.
public enum ArmingPolicy {
    public enum Decision: Equatable, Sendable {
        /// A fresh fix is already there: record now.
        case startNow
        /// Wait for the first fix that passes, then record from that moment.
        case arm
        /// Indoor: record on the step source straight away.
        case startOnSteps
        case blocked(Blocker)
    }

    public enum Blocker: Equatable, Sendable {
        case locationNotAuthorized
        case stepsUnavailable
        /// A sprint is timed between two GPS-marked lines; it cannot run indoors.
        case sprintNeedsGPS
    }

    /// What the arming screen offers after a long wait.
    public enum Fallback: Equatable, Sendable {
        case none
        /// Start on steps now; GPS takes over when it can (the builder already
        /// arbitrates per point). Not Indoor: that would tag an outdoor run as proxy.
        case offerSteps
        /// No step source either: the only honest option is to keep waiting.
        case keepWaitingOnly
    }

    public static let fallbackAfter: TimeInterval = 90

    public static func decide(indoor: Bool, locationAuthorized: Bool, pedometerReady: Bool, hasFix: Bool,
                              sprint: Bool = false) -> Decision {
        if sprint {
            if indoor { return .blocked(.sprintNeedsGPS) }
            guard locationAuthorized else { return .blocked(.locationNotAuthorized) }
            return hasFix ? .startNow : .arm
        }
        if indoor {
            return pedometerReady ? .startOnSteps : .blocked(.stepsUnavailable)
        }
        guard locationAuthorized else { return .blocked(.locationNotAuthorized) }
        return hasFix ? .startNow : .arm
    }

    public static func fallback(waited: TimeInterval, pedometerReady: Bool, sprint: Bool = false) -> Fallback {
        guard waited >= fallbackAfter else { return .none }
        // Steps cannot time a sprint, so they are never offered for one.
        if sprint { return .keepWaitingOnly }
        return pedometerReady ? .offerSteps : .keepWaitingOnly
    }
}
