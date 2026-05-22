import SwiftUI

// MARK: - Sign in

struct SignInView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.petmojiPalette) private var palette

    var onSwitchToSignUp: () -> Void = {}

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?
    @State private var isSubmitting = false
    @State private var authError: String?

    private let supabase = SupabaseService.shared

    private enum Field {
        case email
        case password
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFormValid: Bool {
        trimmedEmail.contains("@") && trimmedEmail.contains(".") && !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text("welcome back")
                        .font(.displayL)
                        .foregroundStyle(palette.accentDark)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 12) {
                        TextField("enter email...", text: $email)
                            .font(.titleL)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(palette.textPrimary)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .tint(palette.accent)
                            .pmSignInFieldChrome()

                        SecureField("enter password...", text: $password)
                            .font(.titleL)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(palette.textPrimary)
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .tint(palette.accent)
                            .pmSignInFieldChrome()
                            .onSubmit { signIn() }
                    }

                    if let authError {
                        Text(authError)
                            .font(.bodyM)
                            .foregroundStyle(.red.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    signUpLink

                    Spacer(minLength: 120)
                }
                .padding(.top, 8)
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                PMSageCTAButton(
                    title: isSubmitting ? "signing in…" : "sign in →",
                    action: signIn,
                    isEnabled: isFormValid && !isSubmitting
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
            }
            .pmSageScreenBackground()
            .onAppear {
                focusedField = .email
            }
        }
        .tint(palette.toolbarTint)
    }

    private var signUpLink: some View {
        Button(action: onSwitchToSignUp) {
            HStack(spacing: 4) {
                Text("Don't have an account?")
                    .foregroundStyle(palette.textSecondary)
                Text("Create account")
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.accentDark)
            }
            .font(.bodyM)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private func signIn() {
        guard isFormValid, !isSubmitting else { return }
        focusedField = nil
        authError = nil
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                try await supabase.signIn(email: trimmedEmail, password: password)
                await appState.restoreAuthenticatedSession(showLoading: false)
            } catch {
                authError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

// MARK: - Field chrome

private struct PMSignInFieldChrome: ViewModifier {
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
    func pmSignInFieldChrome() -> some View {
        modifier(PMSignInFieldChrome())
    }
}
