import Foundation
import Supabase

// MARK: - Claude Service
// All Claude calls route through Supabase edge functions.
// The Claude API key never lives in the app binary.

final class ClaudeService: @unchecked Sendable {
    static let shared = ClaudeService()
    private static let historyLimit = 20
    private init() {}

    func chatReply(
        petId: UUID,
        userMessage: String,
        conversationHistory: [ChatMessage],
        ownerName: String? = nil,
        isOpening: Bool = false
    ) async throws -> ClaudeMessageResponse {
        struct ChatRequest: Encodable {
            let petId: String
            let message: String
            let history: [HistoryMessage]
            let ownerName: String?
            let isOpening: Bool
            enum CodingKeys: String, CodingKey {
                case petId = "pet_id"
                case message
                case history
                case ownerName = "owner_name"
                case isOpening = "is_opening"
            }
        }
        struct HistoryMessage: Encodable {
            let role: String
            let content: String
        }

        let history = conversationHistory.suffix(Self.historyLimit).map {
            HistoryMessage(role: $0.isFromPet ? "assistant" : "user", content: $0.content)
        }

        let trimmedOwner = ownerName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let owner = (trimmedOwner?.isEmpty == false) ? trimmedOwner : nil

        return try await SupabaseService.shared.client.functions
            .invoke(
                "chat-reply",
                options: FunctionInvokeOptions(
                    body: ChatRequest(
                        petId: petId.uuidString,
                        message: userMessage,
                        history: Array(history),
                        ownerName: owner,
                        isOpening: isOpening
                    )
                )
            )
    }
}

enum ClaudeError: Error {
    case httpError
    case emptyResponse
    case parseError
}
