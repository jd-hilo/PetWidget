import WidgetKit
import SwiftUI

// MARK: - Widget Entry View

struct PetWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: PetWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: PetWidgetEntry

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {

                // Name pill — top right
                HStack {
                    Spacer()
                    Text(entry.petName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                Spacer()

                // Sprite — centered
                WidgetSpriteView(image: entry.spriteImage)
                    .frame(width: 88, height: 88)

                Spacer()

                // Message + chat icon — bottom row
                HStack(alignment: .bottom, spacing: 8) {
                    Text(entry.message)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "message.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.black.opacity(0.25), in: Circle())
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .containerBackground(for: .widget) {
            blurredBackground
        }
    }

    private var blurredBackground: some View {
        ZStack {
            // Frosted glass — blurs the wallpaper behind the widget
            Rectangle().fill(.ultraThinMaterial)

            // Expression colour tint at 50% so wallpaper still reads through
            Color(hex: entry.expression.accentHex).opacity(0.50)

            // Blurred sprite glow for depth
            WidgetSpriteView(image: entry.spriteImage)
                .scaleEffect(2.0)
                .blur(radius: 20)
                .opacity(0.15)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: PetWidgetEntry

    var body: some View {
        ZStack {
            HStack(spacing: 0) {

                // Sprite left
                WidgetSpriteView(image: entry.spriteImage)
                    .frame(width: 110, height: 110)
                    .padding(.leading, 12)

                // Right column
                VStack(alignment: .leading, spacing: 8) {

                    // Name pill top-right
                    HStack {
                        Spacer()
                        Text(entry.petName)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())
                    }

                    Spacer()

                    // Message
                    Text(entry.message)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    // Chat icon bottom-right
                    HStack {
                        Spacer()
                        Image(systemName: "message.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.black.opacity(0.25), in: Circle())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .containerBackground(for: .widget) {
            blurredBackground
        }
    }

    private var blurredBackground: some View {
        ZStack {
            Color(hex: entry.expression.accentHex)

            RadialGradient(
                colors: [.white.opacity(0.35), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 200
            )

            WidgetSpriteView(image: entry.spriteImage)
                .scaleEffect(2.0)
                .blur(radius: 20)
                .opacity(0.3)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Widget Sprite View (uses pre-fetched UIImage — AsyncImage is unreliable in widgets)

struct WidgetSpriteView: View {
    let image: UIImage?

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Text("🐾")
                .font(.system(size: 40))
        }
    }
}

// MARK: - Color Helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    PetWidget()
} timeline: {
    PetWidgetEntry.placeholder
}

#Preview(as: .systemMedium) {
    PetWidget()
} timeline: {
    PetWidgetEntry.placeholder
}
