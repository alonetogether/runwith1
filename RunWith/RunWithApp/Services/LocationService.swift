import CoreLocation
import Observation
import RunCore

/// Thin CoreLocation wrapper. Converts CLLocation into the platform-agnostic
/// `LocationFix` and hands it to whoever is listening (the recorder).
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var latestFix: LocationFix?
    private(set) var lastError: String?
    /// Set by the recorder for the duration of a run.
    var onFix: ((LocationFix) -> Void)?

    /// Fixes worse than this never count as "GPS acquired" on the gear check.
    static let usableAccuracyM: Double = 30

    private let manager = CLLocationManager()
    /// True between startRun and stopRun, so a permission change cannot drop a
    /// run (or an armed start) back to foreground-only warm-up.
    private var isRunMode = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        authorization = manager.authorizationStatus
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshFreshness() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        freshnessTimer = timer
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    /// A fix good enough to start on: accurate and recent. Stored rather than
    /// computed, and changed only when it flips, so screens re-render when GPS
    /// is gained or goes stale instead of on a blanket timer that can swallow taps.
    private(set) var hasFix = false
    private var freshnessTimer: Timer?

    private func refreshFreshness() {
        let fresh: Bool = {
            guard let f = latestFix else { return false }
            return f.horizontalAccuracyM >= 0
                && f.horizontalAccuracyM <= Self.usableAccuracyM
                && Date().timeIntervalSince(f.timestamp) < 15
        }()
        if fresh != hasFix { hasFix = fresh }
    }

    // MARK: Control

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Foreground-only updates so the gear check can show "fix acquired" before Start.
    func startWarmup() {
        guard isAuthorized, !isRunMode else { return }
        manager.allowsBackgroundLocationUpdates = false
        manager.startUpdatingLocation()
    }

    /// Pocketable: keeps delivering fixes with the screen off (UIBackgroundModes: location).
    func startRun() {
        guard isAuthorized else { return }
        isRunMode = true
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func stopRun() {
        isRunMode = false
        manager.allowsBackgroundLocationUpdates = false
        manager.stopUpdatingLocation()
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if self.isAuthorized {
                if self.isRunMode { self.startRun() } else { self.startWarmup() }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let fixes = locations.map { l in
            LocationFix(timestamp: l.timestamp,
                        lat: l.coordinate.latitude,
                        lng: l.coordinate.longitude,
                        horizontalAccuracyM: l.horizontalAccuracy,
                        speedMps: l.speed >= 0 ? l.speed : nil,
                        altitudeM: l.verticalAccuracy >= 0 ? l.altitude : nil,
                        verticalAccuracyM: l.verticalAccuracy)
        }
        Task { @MainActor in
            for f in fixes {
                self.latestFix = f
                self.onFix?(f)
            }
            self.refreshFreshness()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message: String
        switch (error as? CLError)?.code {
        case .locationUnknown: message = "no GPS signal yet"
        case .denied: message = "location access denied"
        default: message = error.localizedDescription
        }
        Task { @MainActor in self.lastError = message }
    }
}
