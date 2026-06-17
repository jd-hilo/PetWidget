import SwiftUI

// MARK: - OTP rules (must match Supabase project OTP length)

enum SignUpOTPConfig {
    static let length = 6
    static let resendCooldownSeconds = 60
}

// MARK: - Sign-up steps

enum SignUpStep: Int, CaseIterable, Hashable {
    case name = 0
    case email = 1
    case otp = 2

    var progressIndex: Int { rawValue }

    static let fieldSteps: [SignUpStep] = [.name, .email]
}

// MARK: - Sign-up draft

@MainActor
final class SignUpDraft: ObservableObject {
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var otpCode: String = ""

    var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    var isOTPValid: Bool {
        otpCode.count == SignUpOTPConfig.length && otpCode.allSatisfy(\.isNumber)
    }

    func isValid(for step: SignUpStep) -> Bool {
        switch step {
        case .name: return isNameValid
        case .email: return isEmailValid
        case .otp: return isOTPValid
        }
    }

    func summary(for step: SignUpStep) -> String? {
        switch step {
        case .name:
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        case .email:
            let trimmed = email.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        case .otp:
            return isOTPValid ? String(repeating: "•", count: SignUpOTPConfig.length) : nil
        }
    }

    func summaryLabel(for step: SignUpStep) -> String {
        switch step {
        case .name: return "name"
        case .email: return "email"
        case .otp: return "verification code"
        }
    }

    /// Steps before `step` that have a displayable summary (for the compact list).
    func completedSteps(before step: SignUpStep) -> [SignUpStep] {
        let candidates: [SignUpStep] = step == .otp
            ? SignUpStep.fieldSteps
            : SignUpStep.allCases.filter { $0.rawValue < step.rawValue }
        return candidates.filter { summary(for: $0) != nil }
    }

    func clearOTP() {
        otpCode = ""
    }
}
