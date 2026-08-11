import Foundation
import OneSignalFramework
import UIKit
import UserNotifications

// MARK: - OneSignal lifecycle + push payload parsing

enum PushNotificationService {
    private static var appId: String {
        if let env = ProcessInfo.processInfo.environment["ONESIGNAL_APP_ID"], !env.isEmpty {
            return env
        }
        return Bundle.main.object(forInfoDictionaryKey: "ONESIGNAL_APP_ID") as? String ?? ""
    }

    /// Retained so OneSignal's weak listener refs stay alive.
    private static let bridge = OneSignalPushBridge()

    static func configure(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        let id = appId
        guard !id.isEmpty else {
            print("[PushNotificationService] ONESIGNAL_APP_ID not set — remote push disabled")
            return
        }
        OneSignal.initialize(id, withLaunchOptions: launchOptions)
        OneSignal.Notifications.addClickListener(bridge)
        OneSignal.Notifications.addForegroundLifecycleListener(bridge)
    }

    static func login(userId: UUID) {
        guard !appId.isEmpty else { return }
        OneSignal.login(userId.uuidString)
        registerForRemoteNotificationsIfAuthorized()
    }

    static func logout() {
        guard !appId.isEmpty else { return }
        OneSignal.logout()
    }

    static func registerForRemoteNotificationsIfAuthorized() {
        Task { @MainActor in
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized else { return }
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    static func parsePetMessagePayload(_ userInfo: [AnyHashable: Any]) -> (petId: UUID, messageId: UUID)? {
        if let parsed = parseFlatPayload(userInfo) {
            return parsed
        }
        if let custom = userInfo["custom"] as? [String: Any],
           let data = custom["a"] as? [String: Any] {
            return parseFlatPayload(data)
        }
        if let data = userInfo["data"] as? [String: Any] {
            return parseFlatPayload(data)
        }
        return nil
    }

    private static func parseFlatPayload(_ payload: [AnyHashable: Any]) -> (petId: UUID, messageId: UUID)? {
        guard let petRaw = payload["pet_id"] as? String,
              let messageRaw = payload["message_id"] as? String,
              let petId = UUID(uuidString: petRaw),
              let messageId = UUID(uuidString: messageRaw) else {
            return nil
        }
        return (petId, messageId)
    }
}

// MARK: - OneSignal → widget/chat refresh

/// Immutable listener retained for OneSignal's weak refs; hops to MainActor before touching app state.
private final class OneSignalPushBridge: NSObject, OSNotificationClickListener, OSNotificationLifecycleListener, @unchecked Sendable {
    func onClick(event: OSNotificationClickEvent) {
        refreshFromNotification(event.notification)
    }

    func onWillDisplay(event: OSNotificationWillDisplayEvent) {
        refreshFromNotification(event.notification)
    }

    private func refreshFromNotification(_ notification: OSNotification) {
        var userInfo: [AnyHashable: Any] = notification.rawPayload
        if let additional = notification.additionalData {
            for (key, value) in additional {
                userInfo[key] = value
            }
        }
        Task { @MainActor in
            _ = await PushNotificationHandler.handle(userInfo: userInfo)
        }
    }
}
