import Foundation
import CoreLocation
import WidgetKit

// MARK: - Location Service (geofencing + home detection)

enum HomeLocationError: LocalizedError {
    case permissionDenied
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location access is required to set your home. Enable it in Settings."
        case .locationUnavailable:
            return "Couldn't get your current location. Try again in a moment."
        }
    }
}

@MainActor
final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var homeRegion: CLCircularRegion?
    @Published var isLocationTrackingEnabled: Bool = true

    private let manager = CLLocationManager()
    private let homeRegionIdentifier = "com.petmoji.home"
    private let defaultRadius: CLLocationDistance = 200 // meters

    private let sharedDefaults = UserDefaults(suiteName: "group.com.petmoji.app")

    override init() {
        super.init()
        manager.delegate = self
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
        isLocationTrackingEnabled = Self.loadLocationTrackingEnabled()
        applyLocationTrackingState()
    }

    // MARK: - Tracking preference

    func setLocationTrackingEnabled(_ enabled: Bool) {
        isLocationTrackingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: MockUserSettings.Keys.locationTrackingEnabled)
        applyLocationTrackingState()
    }

    private static func loadLocationTrackingEnabled() -> Bool {
        let d = UserDefaults.standard
        guard d.object(forKey: MockUserSettings.Keys.locationTrackingEnabled) != nil else {
            return false
        }
        return d.bool(forKey: MockUserSettings.Keys.locationTrackingEnabled)
    }

    private func applyLocationTrackingState() {
        if isLocationTrackingEnabled {
            restoreHomeRegion()
            configureBackgroundLocationIfAuthorized()
        } else {
            stopHomeMonitoring()
            sharedDefaults?.removeObject(forKey: "departure_time")
            MessageScheduler.shared.cancelBeenGoneNotifications()
            manager.allowsBackgroundLocationUpdates = false
        }
    }

    private func stopHomeMonitoring() {
        if let region = homeRegion {
            manager.stopMonitoring(for: region)
        }
    }

    // MARK: - Permission

    func requestWhenInUsePermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysPermission() {
        manager.requestAlwaysAuthorization()
    }

    var needsAlwaysForLeaveHomeAlerts: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    // MARK: - Home setup (GPS → Supabase → geofence)

    /// Captures current GPS, saves to pet row, starts geofence, then prompts for Always.
    func saveCurrentLocationAsHome(
        petId: UUID,
        petName: String,
        onPetHomeUpdated: ((Double, Double) -> Void)? = nil
    ) async throws {
        try await ensureWhenInUseAuthorized()
        let location = try await fetchCurrentLocation()
        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude

        try await SupabaseService.shared.updatePetHomeLocation(petId: petId, lat: lat, lng: lng)
        if !isLocationTrackingEnabled {
            setLocationTrackingEnabled(true)
        }
        setHomeLocation(lat: lat, lng: lng)
        MessageScheduler.shared.savePetMetadata(name: petName, petId: petId.uuidString)
        _ = await MessageScheduler.shared.requestNotificationPermission()
        onPetHomeUpdated?(lat, lng)

        if authorizationStatus == .notDetermined {
            requestAlwaysPermission()
        } else if authorizationStatus == .authorizedWhenInUse {
            requestAlwaysPermission()
        }
        configureBackgroundLocationIfAuthorized()
    }

    /// Restores geofence from server pet row (e.g. after sign-in or reinstall).
    func syncHomeGeofence(lat: Double, lng: Double, petId: UUID, petName: String) {
        guard lat != 0, lng != 0, isLocationTrackingEnabled else { return }
        let storedLat = sharedDefaults?.double(forKey: "home_lat") ?? 0
        let storedLng = sharedDefaults?.double(forKey: "home_lng") ?? 0
        let coordsChanged = abs(storedLat - lat) > 0.00001 || abs(storedLng - lng) > 0.00001
        if homeRegion == nil || coordsChanged {
            setHomeLocation(lat: lat, lng: lng)
        }
        MessageScheduler.shared.savePetMetadata(name: petName, petId: petId.uuidString)
        configureBackgroundLocationIfAuthorized()
    }

    func setHomeLocation(lat: Double, lng: Double) {
        if let existing = homeRegion {
            manager.stopMonitoring(for: existing)
        }

        let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let region = CLCircularRegion(
            center: center,
            radius: defaultRadius,
            identifier: homeRegionIdentifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        homeRegion = region

        sharedDefaults?.set(lat, forKey: "home_lat")
        sharedDefaults?.set(lng, forKey: "home_lng")

        guard isLocationTrackingEnabled else { return }
        manager.startMonitoring(for: region)
        configureBackgroundLocationIfAuthorized()
    }

    // MARK: - Private

    private func ensureWhenInUseAuthorized() async throws {
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            return
        }
        if authorizationStatus == .denied || authorizationStatus == .restricted {
            throw HomeLocationError.permissionDenied
        }
        requestWhenInUsePermission()
        try await waitForAuthorization(timeoutSeconds: 30) { status in
            status == .authorizedWhenInUse || status == .authorizedAlways
        }
    }

    private func waitForAuthorization(
        timeoutSeconds: Int,
        isSatisfied: (CLAuthorizationStatus) -> Bool
    ) async throws {
        for _ in 0..<(timeoutSeconds * 5) {
            if isSatisfied(authorizationStatus) { return }
            if authorizationStatus == .denied || authorizationStatus == .restricted {
                throw HomeLocationError.permissionDenied
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        throw HomeLocationError.permissionDenied
    }

    private func fetchCurrentLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            let oneShot = CLLocationManager()
            let delegate = OneTimeLocationDelegate(continuation: continuation)
            oneShot.delegate = delegate
            oneShot.desiredAccuracy = kCLLocationAccuracyHundredMeters
            objc_setAssociatedObject(oneShot, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            oneShot.requestLocation()
        }
    }

    private func configureBackgroundLocationIfAuthorized() {
        guard isLocationTrackingEnabled, authorizationStatus == .authorizedAlways else {
            manager.allowsBackgroundLocationUpdates = false
            return
        }
        manager.allowsBackgroundLocationUpdates = true
    }

    private func restoreHomeRegion() {
        guard isLocationTrackingEnabled,
              let lat = sharedDefaults?.double(forKey: "home_lat"),
              let lng = sharedDefaults?.double(forKey: "home_lng"),
              lat != 0, lng != 0 else { return }

        if let existing = homeRegion {
            manager.stopMonitoring(for: existing)
        }

        let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let region = CLCircularRegion(
            center: center,
            radius: defaultRadius,
            identifier: homeRegionIdentifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        homeRegion = region
        manager.startMonitoring(for: region)
        configureBackgroundLocationIfAuthorized()
    }

    var hasHomeLocation: Bool {
        let lat = sharedDefaults?.double(forKey: "home_lat") ?? 0
        let lng = sharedDefaults?.double(forKey: "home_lng") ?? 0
        return lat != 0 && lng != 0
    }

    private func storedPetId() -> UUID? {
        guard let raw = sharedDefaults?.string(forKey: MessageScheduler.petIdKey) else { return nil }
        return UUID(uuidString: raw)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
            configureBackgroundLocationIfAuthorized()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == homeRegionIdentifier else { return }
        Task { @MainActor in
            handleLeftHome()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == homeRegionIdentifier else { return }
        Task { @MainActor in
            handleReturnedHome()
        }
    }

    @MainActor
    private func handleLeftHome() {
        guard isLocationTrackingEnabled else { return }
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "departure_time")
        MessageScheduler.shared.scheduleBeenGoneNotifications()
        WidgetReloader.reload()

        Task {
            guard let petId = storedPetId() else { return }
            try? await SupabaseService.shared.reportLocationEvent(petId: petId, event: "left_home")
        }
    }

    @MainActor
    private func handleReturnedHome() {
        guard isLocationTrackingEnabled else { return }
        sharedDefaults?.removeObject(forKey: "departure_time")
        MessageScheduler.shared.cancelBeenGoneNotifications()
        WidgetReloader.reload()

        Task {
            guard let petId = storedPetId() else { return }
            try? await SupabaseService.shared.reportLocationEvent(petId: petId, event: "returned")
        }
    }
}

// MARK: - One-time location fetch helper

private final class OneTimeLocationDelegate: NSObject, CLLocationManagerDelegate {
    private let continuation: CheckedContinuation<CLLocation, Error>
    private var didResume = false

    init(continuation: CheckedContinuation<CLLocation, Error>) {
        self.continuation = continuation
    }

    private func resumeOnce(with result: Result<CLLocation, Error>) {
        guard !didResume else { return }
        didResume = true
        continuation.resume(with: result)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            resumeOnce(with: .failure(HomeLocationError.locationUnavailable))
            return
        }
        resumeOnce(with: .success(location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resumeOnce(with: .failure(error))
    }
}

// MARK: - Widget Reloader

enum WidgetReloader {
    static func reload() {
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }
}
