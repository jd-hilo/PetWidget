import UserNotifications
import WidgetKit

/// Runs when a remote push with `mutable-content: 1` arrives — even if the main app is killed.
/// Writes the pet message into the app group and asks WidgetKit to reload so the home-screen
/// widget can update without waiting for the user to open Petmoji.
final class NotificationService: UNNotificationServiceExtension {
    private static let appGroupSuiteName = "group.com.petmoji.app"

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        writeWidgetSnapshot(from: request.content)
        WidgetCenter.shared.reloadAllTimelines()

        contentHandler(bestAttemptContent ?? request.content)
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func writeWidgetSnapshot(from content: UNNotificationContent) {
        let userInfo = content.userInfo
        let data = Self.additionalData(from: userInfo)

        let petName = content.title.isEmpty
            ? (data["pet_name"] as? String)
            : content.title
        let message = content.body.isEmpty
            ? (data["message"] as? String)
            : content.body

        guard let petName, !petName.isEmpty,
              let message, !message.isEmpty else {
            return
        }

        let petId = (data["pet_id"] as? String)
            ?? (userInfo["pet_id"] as? String)
        let expression = (data["expression"] as? String)
            ?? (userInfo["expression"] as? String)
            ?? "happy"
        let messageId = (data["message_id"] as? String)
            ?? (userInfo["message_id"] as? String)
            ?? UUID().uuidString
        let spriteURL = (data["sprite_url"] as? String)
            ?? (userInfo["sprite_url"] as? String)

        let defaults = UserDefaults(suiteName: Self.appGroupSuiteName)
        let signature = [messageId, petId ?? "", petName, message, expression, spriteURL ?? ""]
            .joined(separator: "|")

        defaults?.set(petId, forKey: "widget_pet_id")
        defaults?.set(petId, forKey: "pet_id")
        defaults?.set(petName, forKey: "pet_name")
        defaults?.set(message, forKey: "widget_message")
        defaults?.set(expression, forKey: "widget_expression")
        if let spriteURL {
            defaults?.set(spriteURL, forKey: "widget_sprite_url")
        }
        defaults?.set(signature, forKey: "widget_snapshot_signature")
        defaults?.synchronize()
    }

    /// OneSignal nests custom `data` under a few possible keys depending on SDK/payload version.
    private static func additionalData(from userInfo: [AnyHashable: Any]) -> [String: Any] {
        if let custom = userInfo["custom"] as? [String: Any],
           let nested = custom["a"] as? [String: Any] {
            return nested
        }
        if let data = userInfo["data"] as? [String: Any] {
            return data
        }
        return userInfo.reduce(into: [String: Any]()) { result, pair in
            if let key = pair.key as? String {
                result[key] = pair.value
            }
        }
    }
}
