import Foundation

// MARK: - App group keys (mirrors PetWidgetProvider)

enum WidgetSnapshotSync {
    static let appGroupSuiteName = "group.com.petmoji.app"

    enum Keys {
        static let petId = "widget_pet_id"
        static let petName = "pet_name"
        static let message = "widget_message"
        static let expression = "widget_expression"
        static let spriteURL = "widget_sprite_url"
        /// Signature of the last-written snapshot, used to skip redundant widget reloads.
        static let snapshotSignature = "widget_snapshot_signature"
    }

    @MainActor
    static func clear() {
        let defaults = UserDefaults(suiteName: appGroupSuiteName)
        defaults?.removeObject(forKey: Keys.petId)
        defaults?.removeObject(forKey: Keys.petName)
        defaults?.removeObject(forKey: Keys.message)
        defaults?.removeObject(forKey: Keys.expression)
        defaults?.removeObject(forKey: Keys.spriteURL)
        defaults?.removeObject(forKey: Keys.snapshotSignature)
        defaults?.removeObject(forKey: "pet_id")
        defaults?.removeObject(forKey: "pet_name")
        WidgetReloader.reload()
    }

    @MainActor
    static func writeFromPet(_ pet: Pet, message: PetMessage) {
        let spriteURL = pet.expressions[message.expression] ?? pet.expressions[.happy]
        let defaults = UserDefaults(suiteName: appGroupSuiteName)

        // WidgetKit throttles timeline reloads (~40–70/day). This writer is called from
        // many hot paths (home refresh, chat replies, app-active, server refresh), so only
        // reload when the snapshot content actually changed — otherwise a genuine new-message
        // reload can be dropped because the budget was spent on redundant identical reloads.
        let signature = [
            pet.id.uuidString,
            pet.name,
            message.content,
            message.expression.rawValue,
            spriteURL ?? ""
        ].joined(separator: "|")
        let didChange = defaults?.string(forKey: Keys.snapshotSignature) != signature

        // Write the shared app-group data first, then reload, so the widget process reads
        // the new snapshot when WidgetKit re-requests the timeline.
        defaults?.set(pet.id.uuidString, forKey: Keys.petId)
        defaults?.set(pet.name, forKey: Keys.petName)
        defaults?.set(message.content, forKey: Keys.message)
        defaults?.set(message.expression.rawValue, forKey: Keys.expression)
        defaults?.set(spriteURL, forKey: Keys.spriteURL)
        defaults?.set(signature, forKey: Keys.snapshotSignature)

        if didChange {
            WidgetReloader.reload()
        }
    }
}
