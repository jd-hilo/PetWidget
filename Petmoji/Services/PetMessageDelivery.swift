import Foundation
import UserNotifications

// MARK: - Delivers generated pet messages to widget + notifications

enum PetMessageDelivery {
    /// Writes the latest message to the widget snapshot, chat history, and posts a user-visible notification.
    @MainActor
    static func deliver(pet: Pet, message: PetMessage) {
        ChatHistoryStore.appendPetMessage(message)
        WidgetSnapshotSync.writeFromPet(pet, message: message)
        postNotification(petName: pet.name, message: message)
        NotificationCenter.default.post(
            name: .petMessageDelivered,
            object: nil,
            userInfo: ["pet_id": pet.id.uuidString]
        )
    }

    /// Refreshes the widget from the latest server message for the widget pet (app group id).
    @MainActor
    static func refreshWidgetFromServer() async {
        let defaults = UserDefaults(suiteName: WidgetSnapshotSync.appGroupSuiteName)
        guard let raw = defaults?.string(forKey: WidgetSnapshotSync.Keys.petId),
              let petId = UUID(uuidString: raw) else { return }

        await ChatHistoryStore.mergeServerMessages(for: petId)

        guard let pet = try? await SupabaseService.shared.fetchPet(by: petId),
              let message = try? await SupabaseService.shared.fetchLatestMessage(for: petId) else {
            WidgetReloader.reload()
            return
        }
        ChatHistoryStore.appendPetMessage(message)
        WidgetSnapshotSync.writeFromPet(pet, message: message)
    }

    private static func postNotification(petName: String, message: PetMessage) {
        let content = UNMutableNotificationContent()
        content.title = petName
        content.body = message.content
        content.sound = .default
        content.userInfo = [
            "pet_id": message.petId.uuidString,
            "trigger": message.triggerType.rawValue,
        ]

        let request = UNNotificationRequest(
            identifier: "pet_message_\(message.id.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

#if DEBUG
extension PetMessageDelivery {
    enum TestMessageError: LocalizedError {
        case noPet

        var errorDescription: String? {
            switch self {
            case .noPet: return "No pet loaded. Open the app with a pet first."
            }
        }
    }

    /// Generates a real Claude message via `location-event` and delivers it to the widget + notification.
    @MainActor
    static func sendTestMessage(appState: AppState, event: String = "been_gone_2h") async throws -> String {
        guard let pet = appState.widgetPet ?? appState.currentPet ?? appState.pets.first else {
            throw TestMessageError.noPet
        }
        let message = try await SupabaseService.shared.reportLocationEvent(petId: pet.id, event: event)
        guard let updatedPet = try await SupabaseService.shared.fetchPet(by: pet.id) else {
            throw TestMessageError.noPet
        }
        deliver(pet: updatedPet, message: message)
        return message.content
    }
}
#endif
