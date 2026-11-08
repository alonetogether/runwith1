import CoreMotion
import Observation
import RunCore

/// CMPedometer wrapper: cadence everywhere, and the primary distance source
/// indoors where GPS is meaningless (brief §4).
@MainActor
@Observable
final class PedometerService {
    private(set) var authorization: CMAuthorizationStatus = CMPedometer.authorizationStatus()
    private(set) var latest: PedometerSample?
    private(set) var lastError: String?
    /// Set by the recorder for the duration of a run.
    var onSample: ((PedometerSample) -> Void)?

    let isAvailable = CMPedometer.isStepCountingAvailable()
    let isDistanceAvailable = CMPedometer.isDistanceAvailable()
    let isCadenceAvailable = CMPedometer.isCadenceAvailable()

    /// Created lazily: merely touching CMPedometer on a device without a step
    /// counter can raise the Motion prompt, and the brief forbids cold prompts.
    private var pedometer: CMPedometer?
    private var isUpdating = false

    var isAuthorized: Bool { authorization == .authorized }
    var isDenied: Bool { authorization == .denied || authorization == .restricted }
    var isReady: Bool { isAvailable && isAuthorized }

    private func makePedometer() -> CMPedometer {
        if let pedometer { return pedometer }
        let p = CMPedometer()
        pedometer = p
        return p
    }

    /// Core Motion has no explicit request call; the first query raises the
    /// system prompt. Called from the gear check, in context.
    func requestPermission() {
        guard isAvailable else { return }
        let now = Date()
        makePedometer().queryPedometerData(from: now.addingTimeInterval(-60), to: now) { [weak self] _, error in
            let message = error?.localizedDescription
            Task { @MainActor in
                self?.authorization = CMPedometer.authorizationStatus()
                if let message, self?.isAuthorized == false { self?.lastError = message }
            }
        }
    }

    func start(from date: Date) {
        guard isAvailable else { return }
        isUpdating = true
        makePedometer().startUpdates(from: date) { [weak self] data, error in
            if let error {
                let message = error.localizedDescription
                Task { @MainActor in
                    self?.lastError = message
                    self?.authorization = CMPedometer.authorizationStatus()
                }
                return
            }
            guard let data else { return }
            let sample = PedometerSample(timestamp: data.endDate,
                                         steps: data.numberOfSteps.intValue,
                                         cumulativeDistanceM: data.distance?.doubleValue,
                                         paceSPerM: data.currentPace?.doubleValue,
                                         cadenceStepsPerS: data.currentCadence?.doubleValue)
            Task { @MainActor in
                self?.authorization = CMPedometer.authorizationStatus()
                self?.latest = sample
                self?.onSample?(sample)
            }
        }
    }

    func stop() {
        guard isUpdating, let pedometer else { return }
        pedometer.stopUpdates()
        isUpdating = false
    }
}
