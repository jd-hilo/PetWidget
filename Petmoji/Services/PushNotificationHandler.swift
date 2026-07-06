import UIKit

// MARK: - Handles silent push → fetch message → deliver with avatar

enum PushNotificationHandler {
    static let lastDeliveredMessageIdKey = "last_delivered_message_id"

    @MainActor
    static func handle(userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        guard let (petId, messageId) = PushNotificationService.parsePetMessagePayload(userInfo) else {
            await PetMessageDelivery.refreshWidgetFromServer()
            return .noData
        }

        if UserDefaults.standard.string(forKey: lastDeliveredMessageIdKey) == messageId.uuidString {
            await PetMessageDelivery.refreshWidgetFromServer()
            return .noData
        }

        guard let pet = try? await SupabaseService.shared.fetchPet(by: petId),
              let message = try? await SupabaseService.shared.fetchMessage(by: messageId) else {
            await PetMessageDelivery.refreshWidgetFromServer()
            return .failed
        }

        PetMessageDelivery.deliver(pet: pet, message: message)
        return .newData
    }
}
