import WidgetKit
import SwiftUI

// MARK: - Widget Timeline Entry

struct PetWidgetEntry: TimelineEntry {
    let date: Date
    let petName: String
    let spriteURL: String?
    let spriteImageData: Data?     // Data is Sendable; convert to UIImage at render time
    let message: String
    let expression: WidgetExpression

    static let placeholder = PetWidgetEntry(
        date: .now,
        petName: "Mochi",
        spriteURL: nil,
        spriteImageData: nil,
        message: "thinking about naps. and also snacks.",
        expression: .sleepy
    )

    var spriteImage: UIImage? {
        guard let data = spriteImageData else { return nil }
        return UIImage(data: data)
    }
}

enum WidgetExpression: String, Codable {
    case happy, sleepy, mad, excited, missesYou, judging

    var accentHex: String {
        switch self {
        case .happy:     return "#FFE566"
        case .sleepy:    return "#A8C4E0"
        case .mad:       return "#FF8A7A"
        case .excited:   return "#C8F06E"
        case .missesYou: return "#F2B8CB"
        case .judging:   return "#C9BDD4"
        }
    }

    init(from petExpression: String) {
        switch petExpression {
        case "happy":      self = .happy
        case "sleepy":     self = .sleepy
        case "mad":        self = .mad
        case "excited":    self = .excited
        case "misses_you": self = .missesYou
        case "judging":    self = .judging
        default:           self = .happy
        }
    }
}

// MARK: - Timeline Provider

struct PetWidgetProvider: @preconcurrency TimelineProvider {
    private let sharedDefaults = UserDefaults(suiteName: "group.com.petmoji.app")

    func placeholder(in context: Context) -> PetWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (PetWidgetEntry) -> Void) {
        Task {
            completion(await buildEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PetWidgetEntry>) -> Void) {
        Task {
            let entry = await buildEntry()
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 2, to: entry.date) ?? entry.date
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    // MARK: - Build entry with pre-downloaded image data

    private func buildEntry() async -> PetWidgetEntry {
        guard let name    = sharedDefaults?.string(forKey: "pet_name"),
              let message = sharedDefaults?.string(forKey: "widget_message") else {
            return .placeholder
        }

        let expressionStr = sharedDefaults?.string(forKey: "widget_expression") ?? "happy"
        let spriteURL     = sharedDefaults?.string(forKey: "widget_sprite_url")
        let imageData     = await downloadImageData(from: spriteURL)

        return PetWidgetEntry(
            date: .now,
            petName: name,
            spriteURL: spriteURL,
            spriteImageData: imageData,
            message: message,
            expression: WidgetExpression(from: expressionStr)
        )
    }

    private func downloadImageData(from urlString: String?) async -> Data? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        return try? await URLSession.shared.data(from: url).0
    }
}
