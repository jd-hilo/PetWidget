import Foundation

// MARK: - App group keys (mirrors PetWidgetProvider)

enum WidgetSnapshotSync {
    static let appGroupSuiteName = "group.com.petmoji.app"

    enum Keys {
        static let petName = "pet_name"
        static let message = "widget_message"
        static let expression = "widget_expression"
        static let spriteURL = "widget_sprite_url"
    }

    @MainActor
    static func writeFromPet(_ pet: Pet, message: PetMessage) {
        let spriteURL = pet.expressions[message.expression] ?? pet.expressions[.happy]
        let defaults = UserDefaults(suiteName: appGroupSuiteName)
        defaults?.set(pet.name, forKey: Keys.petName)
        defaults?.set(message.content, forKey: Keys.message)
        defaults?.set(message.expression.rawValue, forKey: Keys.expression)
        defaults?.set(spriteURL, forKey: Keys.spriteURL)
        WidgetReloader.reload()
    }
}
