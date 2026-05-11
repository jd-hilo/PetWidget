import Foundation

// MARK: - Settings persona (pet vs mock user preview)

enum SettingsPersona: String, CaseIterable, Identifiable {
    case pet = "pet"
    case mockUser = "mock_user"

    var id: String { rawValue }

    var segmentTitle: String {
        switch self {
        case .pet: return "Pet"
        case .mockUser: return "Mock user"
        }
    }
}

// MARK: - UserDefaults keys + helpers

enum MockUserSettings {
    enum Keys {
        static let persona = "settings_persona"
        static let displayName = "mock_user_display_name"
        static let email = "mock_user_email"
        static let verboseLogs = "mock_user_verbose_logs"
        static let debugSprites = "mock_user_debug_sprites"
    }

    static var persona: SettingsPersona {
        guard let raw = UserDefaults.standard.string(forKey: Keys.persona),
              let value = SettingsPersona(rawValue: raw) else { return .pet }
        return value
    }

    static var isVerboseLoggingEnabled: Bool {
#if DEBUG
        UserDefaults.standard.bool(forKey: Keys.verboseLogs)
#else
        false
#endif
    }

    static var isDebugSpritesUserDefaultEnabled: Bool {
#if DEBUG
        UserDefaults.standard.bool(forKey: Keys.debugSprites)
#else
        false
#endif
    }

    static func logVerbose(_ message: @autoclosure () -> String) {
#if DEBUG
        guard isVerboseLoggingEnabled else { return }
        print("[Petmoji][verbose] \(message())")
#endif
    }
}
