import Foundation
import UserNotifications
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
            return settings.authorizationStatus == .authorized
        }
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
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

