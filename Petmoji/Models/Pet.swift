import Foundation

// MARK: - Pet Model

struct Pet: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    var name: String
    var species: Species
    var gender: PetGender
    var expressions: ExpressionMap
    var personalityTraits: [PersonalityTrait]
    var energyLevel: Int            // 1–10
    var biggestEnemy: Enemy
    var baseMood: BaseMood
    var homeLat: Double?
    var homeLng: Double?
    var timezone: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case species
        case gender
        case expressions
        case personalityTraits = "personality_traits"
        case energyLevel = "energy_level"
        case biggestEnemy = "biggest_enemy"
        case baseMood = "base_mood"
        case homeLat = "home_lat"
        case homeLng = "home_lng"
        case timezone
        case createdAt = "created_at"
    }
}

// MARK: - Sub-types

enum Species: String, Codable, CaseIterable {
    case dog, cat, other
    var displayName: String { rawValue.capitalized }
}

enum PetGender: String, Codable, CaseIterable {
    case boy, girl
    var displayName: String { rawValue.capitalized }
}

struct ExpressionMap: Codable, Equatable {
    var happy: String?
    var sleepy: String?
    var mad: String?
    var excited: String?
    var missesYou: String?
    var judging: String?

    enum CodingKeys: String, CodingKey {
        case happy, sleepy, mad, excited
        case missesYou = "misses_you"
        case judging
    }

    subscript(expression: PetExpression) -> String? {
        switch expression {
        case .happy: return happy
        case .sleepy: return sleepy
        case .mad: return mad
        case .excited: return excited
        case .missesYou: return missesYou
        case .judging: return judging
        }
    }
}

enum PetExpression: String, Codable, CaseIterable {
    case happy, sleepy, mad, excited
    case missesYou = "misses_you"
    case judging

    var displayName: String {
        switch self {
        case .happy: return "Happy"
        case .sleepy: return "Sleepy"
        case .mad: return "Mad"
        case .excited: return "Excited"
        case .missesYou: return "Misses You"
        case .judging: return "Judging"
        }
    }

    var accentColor: String {
        switch self {
        case .happy: return "#FFE566"
        case .sleepy: return "#A8C4E0"
        case .mad: return "#FF8A7A"
        case .excited: return "#C8F06E"
        case .missesYou: return "#F2B8CB"
        case .judging: return "#C9BDD4"
        }
    }

    var promptModifier: String {
        switch self {
        case .happy: return "smiling, bright eyes, happy expression"
        case .sleepy: return "half-closed eyes, drowsy, yawning"
        case .mad: return "furrowed brow, grumpy expression, crossed arms implied"
        case .excited: return "wide eyes, open mouth, ears perked up"
        case .missesYou: return "sad eyes, droopy ears, looking up with longing"
        case .judging: return "one eyebrow raised, unimpressed stare, side-eye"
        }
    }
}

enum PersonalityTrait: String, Codable, CaseIterable {
    case dramatic, lazy, chaotic, sweet, judgy, needy
    case aloof, hyper, foodie, anxious, mischievous, stoic

    var displayName: String { rawValue.capitalized }
}

enum Enemy: String, Codable, CaseIterable {
    case vacuumCleaner = "vacuum cleaner"
    case mailman
    case bathTime = "bath time"
    case otherPets = "other pets"
    case ownReflection = "their own reflection"
    case beingIgnored = "being ignored"

    var displayName: String { rawValue.capitalized }
}

enum BaseMood: String, Codable, CaseIterable {
    case chill
    case mildlySuspicious = "mildly suspicious"
    case emotionallyFragile = "emotionally fragile"
    case unimpressed

    var displayName: String { rawValue.capitalized }
}

// MARK: - Draft (used during onboarding)

struct PetDraft {
    var photos: [Data] = []
    var name: String = ""
    var species: Species = .cat
    var personalityTraits: Set<PersonalityTrait> = []
    var energyLevel: Double = 5.0
    var biggestEnemy: Enemy = .vacuumCleaner
    var baseMood: BaseMood = .chill

    var isValid: Bool {
        !photos.isEmpty && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
