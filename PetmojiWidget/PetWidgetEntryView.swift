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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                WidgetSpriteView(image: entry.spriteImage)
                    .frame(width: 98, height: 98)
                Spacer()
                WidgetPawBadge(size: 27)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Spacer(minLength: 8)

            WidgetNameFeelingBlock(
                petName: entry.petName,
                expression: entry.expression,
                nameFontSize: 12,
                feelingFontSize: 11
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .containerBackground(for: .widget) {
            blurredBackground
        }
        .widgetURL(URL(string: "petmoji://chat"))
    }

    private var blurredBackground: some View {
        ZStack {
            // Frosted glass — blurs the wallpaper behind the widget
            Rectangle().fill(.ultraThinMaterial)

            // Expression colour tint at 50% so wallpaper still reads through
            Color(hex: entry.expression.accentHex).opacity(0.50)

            // Blurred sprite glow for depth
            WidgetSpriteView(image: entry.spriteImage, knockoutWhiteMatte: false)
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
        HStack(spacing: 6) {
            // Sprite left
            WidgetSpriteView(image: entry.spriteImage)
                .frame(width: 136, height: 136)
                .padding(.leading, 10)
                .padding(.vertical, 10)

            // Right column
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    WidgetNameFeelingBlock(
                        petName: entry.petName,
                        expression: entry.expression,
                        nameFontSize: 13,
                        feelingFontSize: 12
                    )
                    Spacer(minLength: 8)
                    WidgetPawBadge(size: 28)
                }

                Text(entry.message)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.trailing, 12)
            .padding(.vertical, 12)
        }
        .containerBackground(for: .widget) {
            blurredBackground
        }
        .widgetURL(URL(string: "petmoji://chat"))
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

            WidgetSpriteView(image: entry.spriteImage, knockoutWhiteMatte: false)
                .scaleEffect(2.0)
                .blur(radius: 20)
                .opacity(0.3)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Shared Widget Blocks

struct WidgetPawBadge: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "pawprint.fill")
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(.black.opacity(0.25), in: Circle())
    }
}

struct WidgetNameFeelingBlock: View {
    let petName: String
    let expression: WidgetExpression
    let nameFontSize: CGFloat
    let feelingFontSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("• \(petName)")
                .font(.system(size: nameFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text("Feeling \(expression.displayName)")
                .font(.system(size: feelingFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(1)
        }
    }
}

// MARK: - Widget Sprite View (uses pre-fetched UIImage — AsyncImage is unreliable in widgets)

struct WidgetSpriteView: View {
    let image: UIImage?
    /// When true, near-white matte pixels are converted to transparency without darkening colors.
    var knockoutWhiteMatte: Bool = true

    var body: some View {
        Group {
            if let image {
                if knockoutWhiteMatte {
                    spriteCore(processedImage(from: image))
                } else {
                    spriteCore(image)
                }
            } else {
                Text("🐾")
                    .font(.system(size: 40))
            }
        }
    }

    private func spriteCore(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .renderingMode(.original)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
    }

    private func processedImage(from image: UIImage) -> UIImage {
        guard let knockedOut = image.knockingOutNearWhite(threshold: 0.93, softness: 0.08) else {
            return image
        }
        return knockedOut
    }
}

private extension WidgetExpression {
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
}

private extension UIImage {
    /// Converts near-white matte/background pixels to transparent alpha.
    func knockingOutNearWhite(threshold: CGFloat, softness: CGFloat) -> UIImage? {
        guard let source = cgImage else { return nil }
        let width = source.width
        let height = source.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(source, in: rect)
        guard let data = context.data else { return nil }

        let pixelBuffer = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
        let effectiveSoftness = max(softness, 0.0001)
        let lowerBound = max(0, threshold - effectiveSoftness)

        for index in stride(from: 0, to: width * height * bytesPerPixel, by: bytesPerPixel) {
            let red = CGFloat(pixelBuffer[index]) / 255.0
            let green = CGFloat(pixelBuffer[index + 1]) / 255.0
            let blue = CGFloat(pixelBuffer[index + 2]) / 255.0
            let alpha = CGFloat(pixelBuffer[index + 3]) / 255.0

            let minChannel = min(red, green, blue)
            if minChannel <= lowerBound {
                continue
            }

            let fade: CGFloat
            if minChannel >= threshold {
                fade = 0
            } else {
                fade = (threshold - minChannel) / (threshold - lowerBound)
            }

            pixelBuffer[index + 3] = UInt8(max(0, min(1, alpha * fade)) * 255.0)
        }

        guard let outputCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: outputCGImage, scale: scale, orientation: imageOrientation)
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
