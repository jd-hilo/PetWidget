import WidgetKit
import SwiftUI

// MARK: - Widget Bundle

@main
struct PetmojiWidgetBundle: WidgetBundle {
    var body: some Widget {
        PetWidget()
    }
}

// MARK: - Widget Definition

struct PetWidget: Widget {
    let kind: String = "PetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PetWidgetProvider()) { entry in
            PetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Petmoji")
        .description("Your pet's reactions, right on your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
