import SwiftUI

// MARK: - Shared 6-digit OTP input

struct EmailOTPFieldView: View {
    @Environment(\.petmojiPalette) private var palette
    @Binding var code: String
    let email: String
    var resendCooldownRemaining: Int = 0
    var isResendDisabled: Bool = false
    var onResend: (() -> Void)?

    @FocusState private var isFocused: Bool

    private var digits: [Character] {
        Array(code.prefix(SignUpOTPConfig.length))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("enter the code we sent to your email")
                .font(.displayL)
                .foregroundStyle(palette.accentDark)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(maskedEmail(email))
                .font(.bodyM)
                .foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isFocused)
                    .opacity(0.01)
                    .frame(width: 1, height: 1)
                    .onChange(of: code) { _, newValue in
                        let filtered = String(newValue.filter(\.isNumber).prefix(SignUpOTPConfig.length))
                        if filtered != newValue {
                            code = filtered
                        }
                    }

                HStack(spacing: 10) {
                    ForEach(0..<SignUpOTPConfig.length, id: \.self) { index in
                        otpBox(at: index)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }

            if let onResend {
                Button(action: onResend) {
                    if resendCooldownRemaining > 0 {
                        Text("Resend code in \(resendCooldownRemaining)s")
                            .font(.bodyS)
                            .foregroundStyle(palette.textSecondary)
                    } else {
                        Text("Resend code")
                            .font(.bodyS)
                            .fontWeight(.semibold)
                            .foregroundStyle(palette.accentDark)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isResendDisabled || resendCooldownRemaining > 0)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFocused = true
            }
        }
    }

    private func otpBox(at index: Int) -> some View {
        let character: Character? = index < digits.count ? digits[index] : nil
        let isActive = index == digits.count && isFocused

        return Text(character.map(String.init) ?? " ")
            .font(.titleL.monospacedDigit())
            .foregroundStyle(palette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(palette.chromeButtonFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isActive ? palette.accent : palette.border,
                        lineWidth: isActive ? 2 : 1.5
                    )
            )
    }

    private func maskedEmail(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let atIndex = trimmed.firstIndex(of: "@") else { return trimmed }
        let local = trimmed[..<atIndex]
        let domain = trimmed[atIndex...]
        if local.count <= 1 {
            return "\(local)\(domain)"
        }
        return "\(local.prefix(1))***\(domain)"
    }
}
