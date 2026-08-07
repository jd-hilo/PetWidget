import Foundation

// MARK: - App Store review demo account

/// Allowlisted sign-in that skips email OTP (account cannot receive mail).
/// Credentials for App Review Notes: see Linear HIL-96 / HIL-97.
enum AppReviewDemoAccount {
    /// Exact email of the Supabase user Apple reviewers use.
    static let email = "apple@test.com"

    static func matches(_ rawEmail: String) -> Bool {
        rawEmail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == email
    }
}
