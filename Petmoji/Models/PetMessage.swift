import Foundation

struct PetMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let petId: UUID
    let content: String
    let expression: PetExpression
    let triggerType: TriggerType
    let scheduledFor: Date
    var sentAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case petId = "pet_id"
        case content
        case expression
        case triggerType = "trigger_type"
        case scheduledFor = "scheduled_for"
        case sentAt = "sent_at"
    }
}

enum TriggerType: String, Codable {
    case scheduled
    case leftHome = "left_home"
    case returned
    case beenGone2h = "been_gone_2h"
    case beenGone6h = "been_gone_6h"
    case chatReply = "chat_reply"
}

// MARK: - Claude API response

struct ClaudeMessageResponse: Codable {
    let message: String
    let expression: PetExpression
}

// MARK: - Chat message (in-memory, not persisted)

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let content: String
    let isFromPet: Bool
    let expression: PetExpression?
    let timestamp: Date

    init(
        id: UUID = UUID(),
        content: String,
        isFromPet: Bool,
        expression: PetExpression?,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.isFromPet = isFromPet
        self.expression = expression
        self.timestamp = timestamp
    }
}
