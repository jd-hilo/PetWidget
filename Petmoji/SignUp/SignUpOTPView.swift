import SwiftUI

// MARK: - OTP step (one hidden TextField + visual digit boxes)

struct SignUpOTPStepView: View {
    @Environment(\.petmojiPalette) private var palette
    @ObservedObject var draft: SignUpDraft
    let email: String

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("enter the code we sent to")
                    .font(.titleL)
                    .foregroundStyle(palette.accentDark)

                Text(email.trimmingCharacters(in: .whitespaces))
                    .font(.bodyL)
                    .foregroundStyle(palette.textPrimary)
            }

            ZStack {
                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { index in
                        otpDisplayBox(at: index)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isInputFocused = true
                }

                // Single real input — drives all six boxes via `draft.otpCode`
                TextField("", text: otpBinding)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isInputFocused)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .opacity(0.02)
                    .tint(palette.accent)
                    .accessibilityLabel("Verification code")
            }

            Text("check your inbox — this is a preview, any 6-digit code works")
                .font(.bodyM)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isInputFocused = true
            }
        }
    }

    private var otpBinding: Binding<String> {
        Binding(
            get: { draft.otpCode },
            set: { draft.applyOTPInput($0) }
        )
    }

    private func otpDisplayBox(at index: Int) -> some View {
        let character = draft.otpCharacter(at: index)
        let isFilled = !character.isEmpty
        let isCurrent = index == draft.otpCode.count && draft.otpCode.count < 6

        return Text(character)
            .font(.titleL)
            .foregroundStyle(palette.textPrimary)
            .frame(width: 44, height: 52)
            .background(palette.chromeButtonFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isCurrent && isInputFocused ? palette.accent : palette.border,
                        lineWidth: isCurrent && isInputFocused ? 2 : 1.5
                    )
            )
            .animation(.easeOut(duration: 0.15), value: isFilled)
            .animation(.easeOut(duration: 0.15), value: isCurrent)
    }
}
