import SwiftUI

// MARK: - Field chrome

private struct PMSignUpFieldChrome: ViewModifier {
    @Environment(\.petmojiPalette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(palette.chromeButtonFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(palette.border, lineWidth: 1.5)
            )
    }
}

private extension View {
    func pmSignUpFieldChrome() -> some View {
        modifier(PMSignUpFieldChrome())
    }
}

// MARK: - Completed steps (compact list, tappable to edit)

struct SignUpCompletedSummaryList: View {
    @Environment(\.petmojiPalette) private var palette
    @ObservedObject var draft: SignUpDraft
    let completedSteps: [SignUpStep]
    let onEditStep: (SignUpStep) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(completedSteps, id: \.self) { completed in
                if let value = draft.summary(for: completed) {
                    summaryRow(
                        step: completed,
                        label: draft.summaryLabel(for: completed),
                        value: value
                    ) {
                        onEditStep(completed)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: completedSteps)
    }

    private func summaryRow(step: SignUpStep, label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .font(.bodyM)
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.textSecondary)

                Text(value)
                    .font(summaryValueFont(for: step))
                    .foregroundStyle(palette.accentDark)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.washSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(palette.border.opacity(0.55), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(SignUpSummaryRowButtonStyle())
        .accessibilityLabel("Edit \(label), \(value)")
        .accessibilityHint("Returns to this step to change your answer")
    }

    private func summaryValueFont(for step: SignUpStep) -> Font {
        switch step {
        case .name: return .titleL
        case .email, .phone, .otp: return .bodyL
        }
    }
}

/// Light press feedback without pill chrome.
private struct SignUpSummaryRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Active step (headline + field, slides up from below)

struct SignUpActiveStepView: View {
    @Environment(\.petmojiPalette) private var palette
    @ObservedObject var draft: SignUpDraft
    let step: SignUpStep
    @FocusState.Binding var focusedStep: SignUpStep?
    var resendCooldownRemaining: Int = 0
    var isResendDisabled: Bool = false
    var onResendOTP: (() -> Void)?

    private var headline: String {
        switch step {
        case .name: return "what's your full name?"
        case .email: return "what's your email?"
        case .phone: return "what's your phone number?"
        case .otp: return ""
        }
    }

    private var placeholder: String {
        switch step {
        case .name: return "enter full name..."
        case .email: return "enter email..."
        case .phone: return "enter phone..."
        case .otp: return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if step != .otp {
                Text(headline)
                    .font(.displayL)
                    .foregroundStyle(palette.accentDark)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            activeField
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var activeField: some View {
        switch step {
        case .name:
            TextField(placeholder, text: $draft.name)
                .font(.titleL)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.textPrimary)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($focusedStep, equals: .name)
                .submitLabel(.continue)
                .tint(palette.accent)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .pmSignUpFieldChrome()

        case .email:
            TextField(placeholder, text: $draft.email)
                .font(.titleL)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.textPrimary)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedStep, equals: .email)
                .submitLabel(.continue)
                .tint(palette.accent)
                .pmSignUpFieldChrome()

        case .phone:
            TextField(placeholder, text: $draft.phone)
                .font(.titleL)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.textPrimary)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .focused($focusedStep, equals: .phone)
                .submitLabel(.continue)
                .tint(palette.accent)
                .pmSignUpFieldChrome()

        case .otp:
            EmailOTPFieldView(
                code: $draft.otpCode,
                email: draft.email,
                resendCooldownRemaining: resendCooldownRemaining,
                isResendDisabled: isResendDisabled,
                onResend: onResendOTP
            )
        }
    }
}
