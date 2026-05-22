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

    // MARK: - Been gone notifications (scheduled on departure)

    func scheduleBeenGoneNotifications() {
        // Cancel any existing ones
        center.removePendingNotificationRequests(withIdentifiers: [
            "been_gone_2h", "been_gone_6h"
        ])

        let petName = sharedDefaults?.string(forKey: Self.petNameKey) ?? "your pet"

        // 2 hours after departure
        let content2h = UNMutableNotificationContent()
        content2h.title = petName
        content2h.body = "it has been two hours. i am fine. i am not waiting by the door."
        content2h.sound = .default
        content2h.userInfo = ["trigger": "been_gone_2h"]

        let trigger2h = UNTimeIntervalNotificationTrigger(
            timeInterval: 2 * 60 * 60,
            repeats: false
        )
        let request2h = UNNotificationRequest(
            identifier: "been_gone_2h",
            content: content2h,
            trigger: trigger2h
        )

        // 6 hours after departure
        let content6h = UNMutableNotificationContent()
        content6h.title = petName
        content6h.body = "ok i literally cannot believe this"
        content6h.sound = .default
        content6h.userInfo = ["trigger": "been_gone_6h"]

        let trigger6h = UNTimeIntervalNotificationTrigger(
            timeInterval: 6 * 60 * 60,
            repeats: false
        )
        let request6h = UNNotificationRequest(
            identifier: "been_gone_6h",
            content: content6h,
            trigger: trigger6h
        )

        center.add(request2h)
        center.add(request6h)
    }

    func cancelBeenGoneNotifications() {
        center.removePendingNotificationRequests(withIdentifiers: [
            "been_gone_2h", "been_gone_6h"
        ])
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

