import Foundation

struct ChatHistoryStore {
    private static let keyPrefix = "chat_history_"

    static func loadHistory(for petId: UUID) -> [ChatMessage] {
        let key = historyKey(for: petId)

        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }

        do {
            return try JSONDecoder().decode([ChatMessage].self, from: data)
        } catch {
            UserDefaults.standard.removeObject(forKey: key)
            return []
        }
    }

    static func saveHistory(_ messages: [ChatMessage], for petId: UUID) {
        let key = historyKey(for: petId)

        guard !messages.isEmpty else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }

        do {
            let data = try JSONEncoder().encode(messages)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            assertionFailure("Failed to save chat history for pet \(petId): \(error)")
        }
    }

    static func clearHistory(for petId: UUID) {
        UserDefaults.standard.removeObject(forKey: historyKey(for: petId))
    }

    private static func historyKey(for petId: UUID) -> String {
        keyPrefix + petId.uuidString
    }
}
