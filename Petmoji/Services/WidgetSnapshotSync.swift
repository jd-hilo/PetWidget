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
    }

    @MainActor
    static func clear() {
        let defaults = UserDefaults(suiteName: appGroupSuiteName)
        defaults?.removeObject(forKey: Keys.petId)
        defaults?.removeObject(forKey: Keys.petName)
        defaults?.removeObject(forKey: Keys.message)
        defaults?.removeObject(forKey: Keys.expression)
        defaults?.removeObject(forKey: Keys.spriteURL)
        defaults?.removeObject(forKey: "pet_id")
        defaults?.removeObject(forKey: "pet_name")
        WidgetReloader.reload()
    }

    @MainActor
    static func writeFromPet(_ pet: Pet, message: PetMessage) {
        let spriteURL = pet.expressions[message.expression] ?? pet.expressions[.happy]
        let defaults = UserDefaults(suiteName: appGroupSuiteName)
        defaults?.set(pet.id.uuidString, forKey: Keys.petId)
        defaults?.set(pet.name, forKey: Keys.petName)
        defaults?.set(message.content, forKey: Keys.message)
        defaults?.set(message.expression.rawValue, forKey: Keys.expression)
        defaults?.set(spriteURL, forKey: Keys.spriteURL)
        WidgetReloader.reload()
    }
}
