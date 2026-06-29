import SwiftUI

// MARK: - Widget Setup View

struct WidgetSetupView: View {
    @Environment(\.petmojiPalette) private var palette

    let onNext: () -> Void
    var onCancel: (() -> Void)?
    /// Primary button label. Defaults to the onboarding wording; settings passes its own.
    var ctaTitle: String = "next: location tracking →"
    /// Helper line under the CTA. Pass `nil` to hide (e.g. when shown from settings).
    var subtitle: String? = "You can always add this later from settings"

    private let steps: [WidgetSetupStep] = [
        WidgetSetupStep(
            number: 1,
            title: "Long-press the Home Screen",
            description: "Hold any empty area until the apps start to jiggle."
        ),
        WidgetSetupStep(
            number: 2,
            title: "Tap the + button",
            description: "You'll find it in the top-left corner of the screen."
        ),
        WidgetSetupStep(
            number: 3,
            title: "Search for \"Petmoji\"",
            description: "Look it up in the widget gallery."
        ),
        WidgetSetupStep(
            number: 4,
            title: "Add your widget",
            description: "Pick a favorite layout, then tap Add Widget."
        )
    ]

    private static let stepRowHeight: CGFloat = 48
    private static let stepSpacing: CGFloat = 12

    private func videoMaxHeight(in availableHeight: CGFloat) -> CGFloat {
        let stepsBlockHeight = CGFloat(steps.count) * Self.stepRowHeight
            + CGFloat(steps.count - 1) * Self.stepSpacing
        let chrome: CGFloat = 8 + 12
        return max(120, availableHeight - stepsBlockHeight - chrome)
    }

    var body: some View {
        ZStack {
            PMSageScreenBackdrop()

            GeometryReader { geo in
                let contentWidth = geo.size.width - 48
                let maxVideoHeight = videoMaxHeight(in: geo.size.height)

                VStack(alignment: .leading, spacing: 12) {
                    OnboardingLoopingVideoPlayer(
                        resourceName: "WidgetScreenDemo",
                        maxWidth: contentWidth,
                        maxHeight: maxVideoHeight,
                        accessibilityLabel: "Widget setup walkthrough video"
                    )

                    VStack(spacing: Self.stepSpacing) {
                        ForEach(steps) { step in
                            WidgetSetupStepRow(step: step)
                                .frame(height: Self.stepRowHeight)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 12) {
            VStack(spacing: 12) {
                PMSageCTAButton(
                    title: ctaTitle,
                    action: onNext
                )

                if let subtitle {
                    Text(subtitle)
                        .font(.bodyS)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                if let onCancel {
                    PMOnboardingCancelButton(action: onCancel)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
            .background(Color.clear)
        }
        .pmOnboardingScreenTitle("set up the widget")
    }
}

// MARK: - Step Model

private struct WidgetSetupStep: Identifiable {
    let number: Int
    let title: String
    let description: String

    var id: Int { number }
}

// MARK: - Step Row

private struct WidgetSetupStepRow: View {
    @Environment(\.petmojiPalette) private var palette

    let step: WidgetSetupStep

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(step.number)")
                .font(.bodyM.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(palette.accent, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.bodyL)
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(step.description)
                    .font(.bodyS)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
