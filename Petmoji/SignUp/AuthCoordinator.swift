import SwiftUI

// MARK: - Auth entry (sign up vs sign in)

enum AuthMode {
    case signUp
    case signIn
}

struct AuthCoordinator: View {
    @State private var mode: AuthMode = .signUp

    var body: some View {
        Group {
            switch mode {
            case .signUp:
                SignUpCoordinator(onSwitchToSignIn: { mode = .signIn })
            case .signIn:
                SignInView(onSwitchToSignUp: { mode = .signUp })
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: mode)
    }
}
