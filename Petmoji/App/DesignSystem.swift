import SwiftUI

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
                .foregroundStyle(isSelected ? Color.pmSecondary : Color(hex: "#5B45C9"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    isSelected ? Color.pmSecondary.opacity(0.2) : Color.pmSecondaryLight,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.pmSecondary : Color.clear, lineWidth: 1.5)
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
                    .foregroundStyle(isSelected ? .white : Color.pmTextPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Color.black : Color.pmCardAlt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
