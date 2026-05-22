import Foundation

// MARK: - User profile (public.profiles)

struct UserProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var fullName: String
    var email: String
    var phone: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case phone
    }
}

// MARK: - Sign-up auth errors

enum SignUpAuthError: LocalizedError {
    case noSession
    case invalidCredentials
    case emailAlreadyExists
    case weakPassword
    case rateLimited
    case network
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .noSession:
            return "You're not signed in. Please sign in again."
        case .invalidCredentials:
            return "Email or password is incorrect."
        case .emailAlreadyExists:
            return "An account with this email already exists. Sign in instead."
        case .weakPassword:
            return "Password must be at least \(AuthPasswordConfig.minLength) characters."
        case .rateLimited:
            return "Too many attempts. Wait a minute and try again."
        case .network:
            return "Couldn't reach the server. Check your connection and try again."
        case .unknown(let message):
            return message
        }
    }

    static func from(_ error: Error) -> SignUpAuthError {
        if let mapped = error as? SignUpAuthError { return mapped }

        let raw = error.localizedDescription
        let message = raw.lowercased()

        if message.contains("already") && (message.contains("registered") || message.contains("exists")) {
            return .emailAlreadyExists
        }
        if message.contains("invalid login") || message.contains("invalid credentials")
            || message.contains("invalid email or password") {
            return .invalidCredentials
        }
        if message.contains("weak password") || message.contains("password should be")
            || message.contains("at least") && message.contains("character") {
            return .weakPassword
        }
        if message.contains("rate") || message.contains("too many") || message.contains("429") {
            return .rateLimited
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return .network
            default:
                break
            }
        }
        return .unknown(raw)
    }
}
