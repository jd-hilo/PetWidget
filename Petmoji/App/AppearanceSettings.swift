import Foundation

// MARK: - App visual style (Classic sage vs widget-aligned glass)

enum AppVisualStyle: String, CaseIterable, Identifiable {
    case classic
    case widgetGlass

    var id: String { rawValue }
}
