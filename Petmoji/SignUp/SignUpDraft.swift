import SwiftUI

// MARK: - Password rules (must match Supabase project minimum)

enum AuthPasswordConfig {
    static let minLength = 6
}

// MARK: - Sign-up steps

enum SignUpStep: Int, CaseIterable, Hashable {
    case name = 0
    case email = 1
    case phone = 2
    case password = 3

    var progressIndex: Int { rawValue }

    static let fieldSteps: [SignUpStep] = [.name, .email, .phone]
}

// MARK: - Sign-up draft

@MainActor
final class SignUpDraft: ObservableObject {
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var phone: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""

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

    var isPasswordValid: Bool {
        password.count >= AuthPasswordConfig.minLength
            && password == confirmPassword
    }

    func isValid(for step: SignUpStep) -> Bool {
        switch step {
        case .name: return isNameValid
        case .email: return isEmailValid
        case .phone: return isPhoneValid
        case .password: return isPasswordValid
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
        case .password:
            return isPasswordValid ? String(repeating: "•", count: min(password.count, 8)) : nil
        }
    }

    func summaryLabel(for step: SignUpStep) -> String {
        switch step {
        case .name: return "full name"
        case .email: return "email"
        case .phone: return "phone"
        case .password: return "password"
        }
    }

    /// Steps before `step` that have a displayable summary (for the compact list).
    func completedSteps(before step: SignUpStep) -> [SignUpStep] {
        let candidates: [SignUpStep] = step == .password
            ? SignUpStep.fieldSteps
            : SignUpStep.allCases.filter { $0.rawValue < step.rawValue }
        return candidates.filter { summary(for: $0) != nil }
    }
}
