import Foundation
import CoreLocation
import UserNotifications
import WidgetKit

// MARK: - Location Service (geofencing + home detection)

@MainActor
final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var homeRegion: CLCircularRegion?

    private let manager = CLLocationManager()
    private let homeRegionIdentifier = "com.petmoji.home"
    private let defaultRadius: CLLocationDistance = 200 // meters

    // App Group UserDefaults for sharing state with widget
    private let sharedDefaults = UserDefaults(suiteName: "group.com.petmoji.app")

    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
        restoreHomeRegion()
    }

    // MARK: - Permission

    func requestWhenInUsePermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysPermission() {
        manager.requestAlwaysAuthorization()
    }

    // MARK: - Home Setup

    func setHomeLocation(lat: Double, lng: Double) {
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let region = CLCircularRegion(
            center: center,
            radius: defaultRadius,
            identifier: homeRegionIdentifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        homeRegion = region

        // Persist
        sharedDefaults?.set(lat, forKey: "home_lat")
        sharedDefaults?.set(lng, forKey: "home_lng")

        // Start monitoring
        manager.startMonitoring(for: region)
    }

    func getCurrentLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = OneTimeLocationDelegate(continuation: continuation)
            manager.delegate = delegate
            manager.requestLocation()
            // Hold delegate reference
            objc_setAssociatedObject(manager, "oneTimeDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    // MARK: - Private

    private func restoreHomeRegion() {
        guard let lat = sharedDefaults?.double(forKey: "home_lat"),
              let lng = sharedDefaults?.double(forKey: "home_lng"),
              lat != 0 else { return }
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let region = CLCircularRegion(
            center: center,
            radius: defaultRadius,
            identifier: homeRegionIdentifier
        )
        homeRegion = region
        manager.startMonitoring(for: region)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
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
        let now = Date()
        sharedDefaults?.set(now.timeIntervalSince1970, forKey: "departure_time")

        // Schedule local "been gone" notifications
        MessageScheduler.shared.scheduleBeenGoneNotifications()

        // Reload widget
        WidgetReloader.reload()

        // Notify backend for a priority message
        Task {
            if let petId = await AppState.shared.petId() {
                try? await SupabaseService.shared.reportLocationEvent(
                    petId: petId, event: "left_home"
                )
            }
        }
    }

    @MainActor
    private func handleReturnedHome() {
        sharedDefaults?.removeObject(forKey: "departure_time")

        // Cancel pending "been gone" notifications
        MessageScheduler.shared.cancelBeenGoneNotifications()

        // Reload widget
        WidgetReloader.reload()

        // Notify backend for celebration message
        Task {
            if let petId = await AppState.shared.petId() {
                try? await SupabaseService.shared.reportLocationEvent(
                    petId: petId, event: "returned"
                )
            }
        }
    }
}

// MARK: - One-time location fetch helper

private class OneTimeLocationDelegate: NSObject, CLLocationManagerDelegate {
    private let continuation: CheckedContinuation<CLLocation, Error>

    init(continuation: CheckedContinuation<CLLocation, Error>) {
        self.continuation = continuation
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            continuation.resume(returning: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation.resume(throwing: error)
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
