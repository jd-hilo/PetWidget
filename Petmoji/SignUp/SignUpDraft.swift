import SwiftUI

// MARK: - Sign-up steps

enum SignUpStep: Int, CaseIterable, Hashable {
    case name = 0
    case email = 1
    case phone = 2
    case otp = 3

    var progressIndex: Int { rawValue }

    static let fieldSteps: [SignUpStep] = [.name, .email, .phone]
}

// MARK: - Sign-up draft

@MainActor
final class SignUpDraft: ObservableObject {
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var phone: String = ""
    /// Single backing string for OTP (avoids multi-TextField / array-mutation freezes).
    @Published var otpCode: String = ""

    var phoneDigitsOnly: String {
        phone.filter(\.isNumber)
    }

    var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    var isPhoneValid: Bool {
        phoneDigitsOnly.count >= 10
    }

    var isOTPValid: Bool {
        otpCode.count == 6
    }

    /// Character at index for the visual OTP boxes (empty string if none).
    func otpCharacter(at index: Int) -> String {
        guard index >= 0, index < otpCode.count else { return "" }
        let i = otpCode.index(otpCode.startIndex, offsetBy: index)
        return String(otpCode[i])
    }

    func isValid(for step: SignUpStep) -> Bool {
        switch step {
        case .name: return isNameValid
        case .email: return isEmailValid
        case .phone: return isPhoneValid
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
        case .phone:
            return phoneDigitsOnly.count >= 10 ? phone : nil
        case .otp:
            return isOTPValid ? otpCode : nil
        }
    }

    func summaryLabel(for step: SignUpStep) -> String {
        switch step {
        case .name: return "full name"
        case .email: return "email"
        case .phone: return "phone"
        case .otp: return "code"
        }
    }

    /// Steps before `step` that have a displayable summary (for the compact list).
    func completedSteps(before step: SignUpStep) -> [SignUpStep] {
        let candidates: [SignUpStep] = step == .otp ? SignUpStep.fieldSteps : SignUpStep.allCases.filter { $0.rawValue < step.rawValue }
        return candidates.filter { summary(for: $0) != nil }
    }

    func applyOTPInput(_ raw: String) {
        let digits = raw.filter(\.isNumber)
        otpCode = String(digits.prefix(6))
    }
}
