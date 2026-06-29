import Foundation
import UserNotifications
import UIKit
import WidgetKit

// MARK: - Message Scheduler (local notifications for time/location events)

@MainActor
final class MessageScheduler {
    static let shared = MessageScheduler()

    static let petIdKey = "pet_id"
    static let petNameKey = "pet_name"

    private let center = UNUserNotificationCenter.current()
    private let sharedDefaults = UserDefaults(suiteName: "group.com.petmoji.app")

    private init() {}

    // MARK: - Permission

    func requestNotificationPermission() async -> Bool {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            let authorized = settings.authorizationStatus == .authorized
            // Already decided — make sure we have a fresh APNs token for the server to push to.
            if authorized { registerForRemoteNotifications() }
            return authorized
        }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        // Obtaining the APNs device token requires an explicit registration call; without it
        // `didRegisterForRemoteNotificationsWithDeviceToken` never fires and no token is stored,
        // so the server has nothing to send a push to.
        if granted { registerForRemoteNotifications() }
        return granted
    }

    /// Registers with APNs for a device token when the user has already authorized notifications.
    /// Safe to call on every foreground — APNs tokens can rotate, and re-registering refreshes them.
    func registerForPushIfAuthorized() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            registerForRemoteNotifications()
        default:
            break
        }
    }

    private func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - Been gone follow-ups (AI messages via background refresh at ~2h / ~6h)

    func scheduleBeenGoneNotifications() {
        BeenGoneBackgroundScheduler.scheduleFollowUps()
    }

    func cancelBeenGoneNotifications() {
        BeenGoneBackgroundScheduler.cancelFollowUps()
    }

    // MARK: - Store pet metadata for notifications

    func savePetMetadata(name: String, petId: String) {
        sharedDefaults?.set(name, forKey: Self.petNameKey)
        sharedDefaults?.set(petId, forKey: Self.petIdKey)
    }

    // MARK: - Widget reload helper

    func reloadWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

