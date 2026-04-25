import SwiftUI
import UIKit

// MARK: - Color Palette

extension Color {
    static let pmBackground = Color(hex: "#FFFFFF")
    static let pmCardSurface = Color(hex: "#FFFFFF")
    static let pmCardAlt = Color(hex: "#F5F5F5")
    static let pmPrimary = Color.black
    static let pmPrimaryLight = Color(hex: "#EBEBEB")
    static let pmSecondary = Color(hex: "#C9B8FF")
    static let pmSecondaryLight = Color(hex: "#EDE8FF")
    static let pmTextPrimary = Color(hex: "#1A1208")
    static let pmTextSecondary = Color(hex: "#7A6E64")
    static let pmBorder = Color(hex: "#EEE0D8")

    // Sage chrome (onboarding + warm green screens)
    static let pmSageBackground = Color(hex: "#FDFEFA")
    static let pmSageBackgroundTint = Color(hex: "#F2F4ED")
    static let pmSageSurface = Color(hex: "#F2F4ED")
    static let pmSageAccent = Color(hex: "#7E9C78")
    static let pmSageAccentDark = Color(hex: "#5F7B5A")
    static let pmSageTextPrimary = Color(hex: "#2A3128")
    static let pmSageTextSecondary = Color(hex: "#6F7A70")
    static let pmSageBorder = Color(hex: "#B8C7B2")
    static let pmSageIconTint = Color(hex: "#556B52")
    static let pmSageCardNeutral = Color(hex: "#EFECE6")
    static let pmSagePatternSymbol = Color(hex: "#8FA287")
    static let pmSageSegmentMuted = Color(hex: "#CDD7C8")
    /// Light sage washes for section headers (pair with `pmSageWashDeep*` variants).
    static let pmSageWashSoft = Color(hex: "#EEF3EC")
    static let pmSageWashMid = Color(hex: "#E4EBE0")
    static let pmSageWashDeep = Color(hex: "#D8E3D4")
    static let pmSageWashAltSoft = Color(hex: "#E8EDE4")
    static let pmSageWashAltDeep = Color(hex: "#DBE4D6")
    /// Warm clay accent (pair with sage; use sparingly).
    static let pmClay = Color(hex: "#B07D62")
    static let pmClayDark = Color(hex: "#7A5344")
    static let pmClayLight = Color(hex: "#EDD9CF")
    static let pmClayMid = Color(hex: "#D4B8A8")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Expression Colors

extension PetExpression {
    var color: Color {
        Color(hex: accentColor)
    }
}

// MARK: - Typography

extension Font {
    static func nunito(_ weight: Font.Weight, _ size: CGFloat) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let displayXL = nunito(.black, 52)
    static let displayL = nunito(.black, 40)
    static let titleL = nunito(.bold, 28)
    static let bodyL = nunito(.semibold, 17)
    static let bodyM = nunito(.regular, 15)
    static let bodyS = nunito(.regular, 13)
    static let buttonFont = nunito(.bold, 18)
    static let widgetTitle = nunito(.heavy, 14)
    static let widgetBody = nunito(.semibold, 12)
}

// MARK: - Card Style

struct PMCard: ViewModifier {
    var cornerRadius: CGFloat = 24
    var backgroundColor: Color = .pmCardSurface

    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.pmBorder, lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 4)
    }
}

extension View {
    func pmCard(cornerRadius: CGFloat = 24, backgroundColor: Color = .pmCardSurface) -> some View {
        modifier(PMCard(cornerRadius: cornerRadius, backgroundColor: backgroundColor))
    }
}

// MARK: - Sage theme (screen chrome)

/// Selected: tight shadow under the tile; unselected: soft ambient shadow.
struct PMSageSelectableTileShadowModifier: ViewModifier {
    let isSelected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isSelected {
            content
                .shadow(color: Color.black.opacity(0.30), radius: 7, x: 0, y: 11)
                .shadow(color: Color.black.opacity(0.13), radius: 2, x: 0, y: 5)
        } else {
            content
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
    }
}

/// Decorative paw and leaf symbols along the left and right screen edges.
struct PMSageEdgePattern: View {
    private struct PatternSymbol {
        let systemName: String
        let point: CGPoint
        let size: CGFloat
        let opacity: Double
        let rotation: Double
    }

    private var leftEdgeSymbols: [PatternSymbol] {
        [
            .init(systemName: "pawprint.fill", point: .init(x: 0.06, y: 0.04), size: 42, opacity: 0.46, rotation: -12),
            .init(systemName: "pawprint", point: .init(x: 0.14, y: 0.09), size: 34, opacity: 0.38, rotation: 6),
            .init(systemName: "leaf", point: .init(x: 0.05, y: 0.16), size: 40, opacity: 0.34, rotation: 22),
            .init(systemName: "leaf.fill", point: .init(x: 0.15, y: 0.21), size: 30, opacity: 0.30, rotation: -18),
            .init(systemName: "pawprint.fill", point: .init(x: 0.05, y: 0.30), size: 38, opacity: 0.40, rotation: 10),
            .init(systemName: "pawprint", point: .init(x: 0.13, y: 0.36), size: 30, opacity: 0.34, rotation: -16),
            .init(systemName: "leaf", point: .init(x: 0.04, y: 0.45), size: 42, opacity: 0.32, rotation: 28),
            .init(systemName: "leaf.fill", point: .init(x: 0.13, y: 0.54), size: 30, opacity: 0.30, rotation: -24),
            .init(systemName: "pawprint.fill", point: .init(x: 0.06, y: 0.63), size: 40, opacity: 0.42, rotation: 8),
            .init(systemName: "pawprint", point: .init(x: 0.14, y: 0.70), size: 30, opacity: 0.34, rotation: -12),
            .init(systemName: "leaf", point: .init(x: 0.04, y: 0.79), size: 40, opacity: 0.32, rotation: 20),
            .init(systemName: "pawprint.fill", point: .init(x: 0.06, y: 0.90), size: 38, opacity: 0.40, rotation: 14),
            .init(systemName: "leaf.fill", point: .init(x: 0.15, y: 0.95), size: 30, opacity: 0.28, rotation: -18)
        ]
    }

    private var rightEdgeSymbols: [PatternSymbol] {
        [
            .init(systemName: "pawprint.fill", point: .init(x: 0.94, y: 0.05), size: 40, opacity: 0.44, rotation: 14),
            .init(systemName: "pawprint", point: .init(x: 0.86, y: 0.10), size: 32, opacity: 0.36, rotation: -8),
            .init(systemName: "leaf", point: .init(x: 0.96, y: 0.18), size: 40, opacity: 0.32, rotation: -24),
            .init(systemName: "leaf.fill", point: .init(x: 0.87, y: 0.23), size: 30, opacity: 0.30, rotation: 16),
            .init(systemName: "pawprint.fill", point: .init(x: 0.95, y: 0.32), size: 38, opacity: 0.40, rotation: -10),
            .init(systemName: "pawprint", point: .init(x: 0.87, y: 0.39), size: 30, opacity: 0.34, rotation: 12),
            .init(systemName: "leaf", point: .init(x: 0.96, y: 0.48), size: 42, opacity: 0.30, rotation: -18),
            .init(systemName: "leaf.fill", point: .init(x: 0.87, y: 0.57), size: 30, opacity: 0.28, rotation: 26),
            .init(systemName: "pawprint.fill", point: .init(x: 0.94, y: 0.66), size: 38, opacity: 0.40, rotation: -8),
            .init(systemName: "pawprint", point: .init(x: 0.86, y: 0.74), size: 30, opacity: 0.34, rotation: 10),
            .init(systemName: "leaf", point: .init(x: 0.95, y: 0.83), size: 40, opacity: 0.32, rotation: -22),
            .init(systemName: "pawprint.fill", point: .init(x: 0.93, y: 0.92), size: 38, opacity: 0.40, rotation: 10),
            .init(systemName: "leaf.fill", point: .init(x: 0.86, y: 0.97), size: 28, opacity: 0.26, rotation: 20)
        ]
    }

    var body: some View {
        let screenSize = UIScreen.main.bounds.size
        ZStack {
            ForEach(Array(leftEdgeSymbols.enumerated()), id: \.offset) { _, symbol in
                decorativeSymbol(
                    symbol.systemName,
                    at: symbol.point,
                    in: screenSize,
                    size: symbol.size,
                    opacity: symbol.opacity,
                    rotation: symbol.rotation
                )
            }

            ForEach(Array(rightEdgeSymbols.enumerated()), id: \.offset) { _, symbol in
                decorativeSymbol(
                    symbol.systemName,
                    at: symbol.point,
                    in: screenSize,
                    size: symbol.size,
                    opacity: symbol.opacity,
                    rotation: symbol.rotation
                )
            }
        }
        .frame(width: screenSize.width, height: screenSize.height)
        .allowsHitTesting(false)
    }

    private func decorativeSymbol(
        _ systemName: String,
        at relativePoint: CGPoint,
        in size: CGSize,
        size iconSize: CGFloat,
        opacity: Double,
        rotation: Double
    ) -> some View {
        let absoluteX = size.width * relativePoint.x
        let absoluteY = size.height * relativePoint.y

        return Image(systemName: systemName)
            .font(.system(size: iconSize, weight: .medium))
            .foregroundStyle(Color.pmSagePatternSymbol.opacity(opacity))
            .rotationEffect(.degrees(rotation))
            .position(x: absoluteX, y: absoluteY)
    }
}

/// Full-screen sage gradient plus edge decoration (paws / leaves).
struct PMSageScreenBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.pmSageBackground, Color.pmSageBackgroundTint],
                startPoint: .top,
                endPoint: .bottom
            )
            PMSageEdgePattern()
        }
        .ignoresSafeArea()
    }
}

extension View {
    func pmSageSelectableTileShadow(isSelected: Bool) -> some View {
        modifier(PMSageSelectableTileShadowModifier(isSelected: isSelected))
    }

    /// Full-screen sage gradient plus edge decoration (paws / leaves).
    func pmSageScreenBackground() -> some View {
        background {
            PMSageScreenBackdrop()
        }
    }
}

struct PMSageCard: ViewModifier {
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.pmSageBorder, lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 4)
    }
}

extension View {
    func pmSageCard(cornerRadius: CGFloat = 24) -> some View {
        modifier(PMSageCard(cornerRadius: cornerRadius))
    }
}

struct PMSageCTAButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.buttonFont)
                .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.75))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule(style: .continuous)
                        .fill(isEnabled ? Color.pmSageAccent : Color.pmSageAccent.opacity(0.45))
                )
                .shadow(
                    color: isEnabled ? Color.pmSageAccentDark.opacity(0.28) : .clear,
                    radius: 10,
                    x: 0,
                    y: 6
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - Primary Button (Liquid Glass)

struct PMPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.buttonFont)
                .foregroundStyle(isEnabled ? Color.black : Color.pmTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background {
                    Capsule().fill(.regularMaterial)
                    Capsule().fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(isEnabled ? 0.5 : 0.2),
                                .white.opacity(isEnabled ? 0.1 : 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
                .overlay(
                    Capsule().strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.9), .white.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                )
                .shadow(color: .black.opacity(isEnabled ? 0.12 : 0.05), radius: 12, x: 0, y: 6)
        }
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

// MARK: - Trait Pill

struct PMTraitPill: View {
    let trait: PersonalityTrait
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            Text(trait.displayName)
                .font(.bodyM)
                .foregroundStyle(isSelected ? Color.pmSageAccentDark : Color.pmSageTextPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    isSelected ? Color.pmSageAccent.opacity(0.22) : Color.pmSageSurface,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.pmSageAccent : Color.pmSageBorder.opacity(0.65), lineWidth: 1.5)
                )
        }
        .buttonStyle(SpringButtonStyle())
    }
}

// MARK: - Enemy / Mood Chip

struct PMChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack {
                Text(label)
                    .font(.bodyM)
                    .foregroundStyle(isSelected ? .white : Color.pmSageTextPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                isSelected ? Color.pmSageAccent : Color.pmSageCardNeutral,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color.pmSageAccentDark.opacity(0.35) : Color.pmSageBorder.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(SpringButtonStyle())
    }
}

// MARK: - Speech Bubble Shape

struct SpeechBubbleShape: Shape {
    var cornerRadius: CGFloat = 22
    var tailHeight: CGFloat = 14
    var tailOffset: CGFloat = 28   // distance from left edge to left of tail
    var tailWidth: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        let r = cornerRadius
        let w = rect.width
        let bodyH = rect.height - tailHeight
        let tX  = tailOffset              // tail left edge x
        let tX2 = tailOffset + tailWidth  // tail right edge x

        var p = Path()

        // Start at top-left (after corner arc begins)
        p.move(to: CGPoint(x: r, y: 0))

        // Top edge →
        p.addLine(to: CGPoint(x: w - r, y: 0))
        // Top-right corner
        p.addArc(tangent1End: CGPoint(x: w, y: 0),
                 tangent2End: CGPoint(x: w, y: r), radius: r)

        // Right edge ↓
        p.addLine(to: CGPoint(x: w, y: bodyH - r))
        // Bottom-right corner
        p.addArc(tangent1End: CGPoint(x: w, y: bodyH),
                 tangent2End: CGPoint(x: w - r, y: bodyH), radius: r)

        // Bottom edge right section → tail
        p.addLine(to: CGPoint(x: tX2, y: bodyH))

        // Tail: smooth quad-curve from right → tip → left
        p.addQuadCurve(
            to: CGPoint(x: tX, y: bodyH),
            control: CGPoint(x: tX + tailWidth * 0.45, y: rect.height)
        )

        // Bottom edge left section → corner
        p.addLine(to: CGPoint(x: r, y: bodyH))
        // Bottom-left corner
        p.addArc(tangent1End: CGPoint(x: 0, y: bodyH),
                 tangent2End: CGPoint(x: 0, y: bodyH - r), radius: r)

        // Left edge ↑
        p.addLine(to: CGPoint(x: 0, y: r))
        // Top-left corner
        p.addArc(tangent1End: CGPoint(x: 0, y: 0),
                 tangent2End: CGPoint(x: r, y: 0), radius: r)

        p.closeSubpath()
        return p
    }
}

// MARK: - Speech Bubble

struct SpeechBubble: View {
    let message: String

    private let tailHeight: CGFloat = 14

    var body: some View {
        Text(message)
            .font(.bodyL)
            .foregroundStyle(Color.pmTextPrimary)
            .lineSpacing(4)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 16 + 14) // body padding + tail clearance
            .background {
                SpeechBubbleShape()
                    .fill(.regularMaterial)
                SpeechBubbleShape()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.65), .white.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                SpeechBubbleShape()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.9), Color.pmBorder.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 8)
    }
}

// MARK: - Progress Dots

struct PMProgressDots: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                if i == current {
                    Capsule()
                        .fill(Color.black)
                        .frame(width: 24, height: 8)
                } else {
                    Circle()
                        .fill(Color.pmBorder)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: current)
    }
}

// MARK: - Onboarding icon progress (icons + connectors)

/// Icons with capsules between them; the segment for the current step is darkest, completed segments are mid sage, upcoming are light.
struct PMOnboardingIconProgressBar: View {
    let total: Int
    let current: Int

    /// First half of steps use bone icons, second half use fish-bone icons (matches 4-step onboarding: photo → personality → reveal → widget).
    private let boneOutlineAsset = "boneIcon"
    private let boneFillAsset = "bonefillIcon"
    private let fishOutlineAsset = "fishBoneIcon"
    private let fishFillAsset = "fishBoneFillIcon"

    private let iconSide: CGFloat = 28
    private let connectorWidth: CGFloat = 56
    private let connectorHeight: CGFloat = 5
    private let stackSpacing: CGFloat = 8

    private let iconTint = Color.pmSageAccentDark
    private let segmentActive = Color.pmSageAccentDark
    private let segmentCompleted = Color.pmSageAccent
    private let segmentUpcoming = Color.pmSageSegmentMuted

    var body: some View {
        HStack(spacing: stackSpacing) {
            ForEach(0..<total, id: \.self) { i in
                progressIcon(at: i)

                if i < total - 1 {
                    Capsule(style: .continuous)
                        .fill(segmentColor(forSegmentLeadingFromStep: i))
                        .frame(width: connectorWidth, height: connectorHeight)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: current)
    }

    private func iconAssetName(for index: Int) -> String {
        let fishStartIndex = (total + 1) / 2
        let useFish = index >= fishStartIndex
        let useFill = index == current
        if useFish {
            return useFill ? fishFillAsset : fishOutlineAsset
        }
        return useFill ? boneFillAsset : boneOutlineAsset
    }

    @ViewBuilder
    private func progressIcon(at index: Int) -> some View {
        let name = iconAssetName(for: index)
        if let uiImage = UIImage(named: name) {
            Image(uiImage: uiImage)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: iconSide, height: iconSide)
                .foregroundStyle(iconTint)
        } else {
            Image(systemName: index >= (total + 1) / 2 ? "fish.fill" : "dog.fill")
                .font(.system(size: iconSide * 0.55, weight: .semibold))
                .foregroundStyle(iconTint)
        }
    }

    private func segmentColor(forSegmentLeadingFromStep index: Int) -> Color {
        // Segment `index` connects step `index` → `index + 1`.
        if current == total - 1 {
            return segmentActive
        }
        if index < current {
            return segmentCompleted
        }
        if index == current {
            return segmentActive
        }
        return segmentUpcoming
    }
}

// MARK: - Onboarding navigation bar (centered progress + back)

/// Hides the system back chevron (which shrinks the principal area and shifts the progress bar) and replaces it with a custom leading control plus a same-width trailing placeholder so `ToolbarItem(.principal)` stays visually centered.
struct PMOnboardingToolbarModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    let total: Int
    let current: Int
    let balancedBackButton: Bool

    private static let barButtonSlot: CGFloat = 44

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(balancedBackButton)
            .toolbar {
                if balancedBackButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.pmSageAccentDark)
                        .frame(minWidth: Self.barButtonSlot, minHeight: Self.barButtonSlot)
                        .contentShape(Rectangle())
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Color.clear
                            .frame(width: Self.barButtonSlot, height: Self.barButtonSlot)
                            .allowsHitTesting(false)
                    }
                }
                ToolbarItem(placement: .principal) {
                    PMOnboardingIconProgressBar(total: total, current: current)
                }
            }
    }
}

extension View {
    /// Progress in the nav bar principal slot. Use `balancedBackButton: true` on pushed steps so the back control does not shove the progress bar sideways.
    func pmOnboardingToolbar(total: Int, current: Int, balancedBackButton: Bool = false) -> some View {
        modifier(PMOnboardingToolbarModifier(total: total, current: current, balancedBackButton: balancedBackButton))
    }
}

// MARK: - Spring Button Style

struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: phase - 0.3),
                        .init(color: .white.opacity(0.6), location: phase),
                        .init(color: .clear, location: phase + 0.3)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .blendMode(.plusLighter)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Widget Gradient Background

struct WidgetGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(hex: "#FFF3EC"), Color(hex: "#EDE8FF")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
