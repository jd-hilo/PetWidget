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
                WidgetBoundSpriteCircle(
                    image: entry.spriteImage,
                    size: 72,
                    diskFill: AnyShapeStyle(Color.clear),
                    showsBorder: false,
                    knockoutWhiteMatte: true,
                    knockoutDarkMatte: true,
                    spriteScale: 1.24
                )
                Spacer()
                WidgetPawBadge(size: 35)
            }
            .padding(.horizontal, 2)
            .padding(.top, 2)

            Spacer(minLength: 8)

            WidgetNameFeelingBlock(
                petName: entry.petName,
                expression: entry.expression,
                nameFontSize: 12,
                feelingFontSize: 17,
                dotColor: Color(hex: entry.expression.accentHex)
            )
            .padding(.horizontal, 2)
            .padding(.bottom, 2)
        }
        .containerBackground(for: .widget) {
            WidgetTranslucentBackground()
        }
        .widgetURL(URL(string: "petmoji://chat"))
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: PetWidgetEntry

    var body: some View {
        HStack(spacing: 6) {
            WidgetBoundSpriteCircle(
                image: entry.spriteImage,
                size: 136,
                diskFill: AnyShapeStyle(Color.clear),
                showsBorder: false,
                knockoutWhiteMatte: true,
                knockoutDarkMatte: true,
                spriteScale: 1.24
            )
            .padding(.leading, 4)
            .padding(.vertical, 4)

            // Right column
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    WidgetNameFeelingBlock(
                        petName: entry.petName,
                        expression: entry.expression,
                        nameFontSize: 13,
                        feelingFontSize: 12,
                        dotColor: Color(hex: entry.expression.accentHex)
                    )
                    Spacer(minLength: 8)
                    WidgetPawBadge(size: 32)
                }

                Text(entry.message)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.trailing, 6)
            .padding(.vertical, 6)
        }
        .containerBackground(for: .widget) {
            WidgetTranslucentBackground()
        }
        .widgetURL(URL(string: "petmoji://chat"))
    }
}

// MARK: - Shared backgrounds

/// Stock-style translucent widget surface + faint paw texture (small + medium).
private struct WidgetTranslucentBackground: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            PawPatternOverlay(symbolPointSize: 10)
                .opacity(0.032)
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
            // .background(.black.opacity(0.25), in: Circle())
    }
}

// Faint, staggered grid of paw prints used as a decorative widget background.
struct PawPatternOverlay: View {
    /// Smaller symbols + slightly wider spacing keeps the pattern from competing with content.
    var symbolPointSize: CGFloat = 10
    private var tile: CGFloat { max(24, symbolPointSize * 2.2) }

    var body: some View {
        Canvas { context, size in
            guard let symbol = context.resolveSymbol(id: 0) else { return }

            let cols = Int(ceil(size.width / tile)) + 2
            let rows = Int(ceil(size.height / tile)) + 2

            for row in 0..<rows {
                for col in 0..<cols {
                    let xOffset = (row % 2 == 0) ? 0 : tile / 2
                    let x = CGFloat(col) * tile + xOffset - tile / 2
                    let y = CGFloat(row) * tile - tile / 2
                    let rotation = Angle.degrees(row % 2 == 0 ? -10 : 12)

                    var ctx = context
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: rotation)
                    ctx.draw(symbol, at: .zero, anchor: .center)
                }
            }
        } symbols: {
            Image(systemName: "pawprint.fill")
                .font(.system(size: symbolPointSize, weight: .light))
                .foregroundStyle(.white)
                .tag(0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct WidgetNameFeelingBlock: View {
    let petName: String
    let expression: WidgetExpression
    let nameFontSize: CGFloat
    let feelingFontSize: CGFloat
    var dotColor: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2){
                Text("•")
                    .font(.system(size: nameFontSize + 14, weight: .bold, design: .rounded))
                    .foregroundStyle(dotColor)
                    .shadow(color: dotColor.opacity(0.45), radius: 1, x: 0, y: 0)
                    .shadow(color: dotColor.opacity(0.28), radius: 3, x: 0, y: 0)
                    .shadow(color: dotColor.opacity(0.16), radius: 6, x: 0, y: 0)
                    .offset(y: 3)
                Text(petName.uppercased())
                    .font(.system(size: nameFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .lineLimit(1)

            Text("\(expression.displayName)!")
                .font(.system(size: feelingFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(1)
        }
    }
}

struct WidgetBoundSpriteCircle: View {
    let image: UIImage?
    let size: CGFloat
    /// Avatar backing; accept any `ShapeStyle` so callers can pass `Color` or a `Material`.
    var diskFill: AnyShapeStyle = AnyShapeStyle(Color.white)
    var borderColor: Color = Color(hex: "#7FA687")
    /// When false, no ring is drawn (sprite is still circularly clipped).
    var showsBorder: Bool = true
    /// When true, knocks out near-white matte/background pixels (typical for sprites on a white card).
    var knockoutWhiteMatte: Bool = false
    /// When true, knocks out near-black backdrop pixels in the sprite (for sprites that ship with a dark matte).
    var knockoutDarkMatte: Bool = false
    /// Zoom inside the circular clip before masking to the circle.
    var spriteScale: CGFloat = 1.2

    var body: some View {
        ZStack {
            Circle()
                .fill(diskFill)

            WidgetSpriteView(
                image: image,
                knockoutWhiteMatte: knockoutWhiteMatte,
                knockoutDarkMatte: knockoutDarkMatte
            )
            .frame(width: size, height: size)
            .scaleEffect(spriteScale)
            .clipShape(Circle())
        }
        .frame(width: size, height: size)
        .overlay {
            if showsBorder {
                Circle()
                    .strokeBorder(borderColor, lineWidth: 1.6)
            }
        }
    }
}

// MARK: - Widget Sprite View (uses pre-fetched UIImage — AsyncImage is unreliable in widgets)

struct WidgetSpriteView: View {
    let image: UIImage?
    /// When true, near-white matte pixels are converted to transparency without darkening colors.
    var knockoutWhiteMatte: Bool = true
    /// When true, near-black backdrop pixels are converted to transparency (for sprites with a dark matte).
    var knockoutDarkMatte: Bool = false

    var body: some View {
        Group {
            if let image {
                if knockoutWhiteMatte || knockoutDarkMatte {
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
        var working = image
        if knockoutWhiteMatte,
           let knockedOut = working.knockingOutEdgeConnectedMatte(
               matteThreshold: 0.93,
               softness: 0.11,
               maxChroma: 0.065
           ) {
            working = knockedOut
        }
        if knockoutDarkMatte,
           let knockedOut = working.knockingOutNearBlack(threshold: 0.08, softness: 0.06) {
            working = knockedOut
        }
        return working
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
    /// Removes **edge-connected** near-white matte: BFS from image borders through pixels that are
    /// bright (`min(r,g,b) ≥ matteThreshold - softness`) **and** nearly achromatic
    /// (`max(r,g,b) - min(r,g,b) ≤ maxChroma`). That stops the flood from walking into golden fur,
    /// which shares high brightness but has real color separation across channels.
    func knockingOutEdgeConnectedMatte(
        matteThreshold: CGFloat,
        softness: CGFloat,
        maxChroma: CGFloat = 0.065
    ) -> UIImage? {
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
        let matteFloor = max(0, matteThreshold - max(softness, 0.0001))
        let cellCount = width * height

        func pixelIndex(_ x: Int, _ y: Int) -> Int { (y * width + x) * bytesPerPixel }

        func isMatteCandidate(_ x: Int, _ y: Int) -> Bool {
            let o = pixelIndex(x, y)
            let r = CGFloat(pixelBuffer[o]) / 255.0
            let g = CGFloat(pixelBuffer[o + 1]) / 255.0
            let b = CGFloat(pixelBuffer[o + 2]) / 255.0
            let minC = min(r, g, b)
            let maxC = max(r, g, b)
            let chroma = maxC - minC
            return minC >= matteFloor && chroma <= maxChroma
        }

        var visited = [Bool](repeating: false, count: cellCount)
        var queue = [Int]()
        queue.reserveCapacity(min(cellCount / 4, 4096))

        func enqueue(_ x: Int, _ y: Int) {
            guard x >= 0, x < width, y >= 0, y < height else { return }
            let flat = y * width + x
            guard !visited[flat], isMatteCandidate(x, y) else { return }
            visited[flat] = true
            queue.append(flat)
        }

        for x in 0..<width {
            enqueue(x, 0)
            enqueue(x, height - 1)
        }
        for y in 0..<height {
            enqueue(0, y)
            enqueue(width - 1, y)
        }

        var head = 0
        while head < queue.count {
            let flat = queue[head]
            head += 1
            let x = flat % width
            let y = flat / width
            enqueue(x + 1, y)
            enqueue(x - 1, y)
            enqueue(x, y + 1)
            enqueue(x, y - 1)
        }

        for flat in 0..<cellCount where visited[flat] {
            let o = flat * bytesPerPixel
            pixelBuffer[o] = 0
            pixelBuffer[o + 1] = 0
            pixelBuffer[o + 2] = 0
            pixelBuffer[o + 3] = 0
        }

        guard let outputCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: outputCGImage, scale: scale, orientation: imageOrientation)
    }

    /// Converts near-black backdrop pixels to transparent alpha.
    func knockingOutNearBlack(threshold: CGFloat, softness: CGFloat) -> UIImage? {
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
        let upperBound = min(1, threshold + effectiveSoftness)

        for index in stride(from: 0, to: width * height * bytesPerPixel, by: bytesPerPixel) {
            let red = CGFloat(pixelBuffer[index]) / 255.0
            let green = CGFloat(pixelBuffer[index + 1]) / 255.0
            let blue = CGFloat(pixelBuffer[index + 2]) / 255.0
            let alpha = CGFloat(pixelBuffer[index + 3]) / 255.0

            let maxChannel = max(red, green, blue)
            if maxChannel >= upperBound {
                continue
            }

            let fade: CGFloat
            if maxChannel <= threshold {
                fade = 0
            } else {
                fade = (maxChannel - threshold) / (upperBound - threshold)
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
