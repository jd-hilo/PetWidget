import SwiftUI

// MARK: - Sign in

struct SignInView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.petmojiPalette) private var palette

    var onSwitchToSignUp: () -> Void = {}

    private enum Step {
        case email
        case otp
        case password
    }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var otpCode = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?
    @State private var isSubmitting = false
    @State private var authError: String?
    @State private var resendCooldownRemaining = 0
    @State private var resendCooldownTask: Task<Void, Never>?

    private let supabase = SupabaseService.shared

    private enum Field {
        case email
        case password
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDemoAccount: Bool {
        AppReviewDemoAccount.matches(trimmedEmail)
    }

    private var isEmailStepValid: Bool {
        trimmedEmail.contains("@") && trimmedEmail.contains(".")
    }

    private var isOTPStepValid: Bool {
        otpCode.count == SignUpOTPConfig.length && otpCode.allSatisfy(\.isNumber)
    }

    private var isPasswordStepValid: Bool {
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isFormValid: Bool {
        switch step {
        case .email: return isEmailStepValid
        case .otp: return isOTPStepValid
        case .password: return isPasswordStepValid
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    switch step {
                    case .email:
                        emailStepContent
                    case .otp:
                        otpStepContent
                    case .password:
                        passwordStepContent
                    }

                    if let authError {
                        PMAuthErrorBanner(message: authError)
                    }

                    signUpLink

                    Spacer(minLength: 120)
                }
                .padding(.top, 8)
                .padding(.horizontal, 24)
                .animation(.spring(response: 0.45, dampingFraction: 0.86), value: step)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if step == .otp || step == .password {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Edit email") {
                            goBackToEmail()
                        }
                        .font(.bodyM)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PMSageCTAButton(
                    title: ctaTitle,
                    action: advance,
                    isEnabled: isFormValid && !isSubmitting
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
            }
            .pmSageScreenBackground()
            .onAppear {
                focusedField = .email
            }
            .onDisappear {
                resendCooldownTask?.cancel()
                resendCooldownTask = nil
            }
        }
        .tint(palette.toolbarTint)
    }

    private var emailStepContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("welcome back")
                .font(.displayL)
                .foregroundStyle(palette.accentDark)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("enter email...", text: $email)
                .font(.titleL)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.textPrimary)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.continue)
                .tint(palette.accent)
                .pmSignInFieldChrome()
        }
    }

    private var otpStepContent: some View {
        EmailOTPFieldView(
            code: $otpCode,
            email: email,
            title: "enter the code we sent to your email",
            resendCooldownRemaining: resendCooldownRemaining,
            isResendDisabled: isSubmitting,
            onResend: { resendOTP() }
        )
    }

    private var passwordStepContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("enter your password")
                .font(.displayL)
                .foregroundStyle(palette.accentDark)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(maskedEmail(trimmedEmail))
                .font(.bodyM)
                .foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            SecureField("password", text: $password)
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
                .onSubmit {
                    if isFormValid && !isSubmitting {
                        advance()
                    }
                }
        }
    }

    private var ctaTitle: String {
        if isSubmitting {
            switch step {
            case .email: return isDemoAccount ? "continuing…" : "sending code…"
            case .otp, .password: return "signing in…"
            }
        }
        switch step {
        case .email: return isDemoAccount ? "continue →" : "send code →"
        case .otp, .password: return "sign in →"
        }
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

    private func advance() {
        guard isFormValid, !isSubmitting else { return }
        focusedField = nil
        authError = nil

        switch step {
        case .email:
            if isDemoAccount {
                advanceToDemoPasswordStep()
            } else {
                Task { await sendOTPAndAdvance() }
            }
        case .otp, .password:
            Task { await verifyAndSignIn() }
        }
    }

    private func advanceToDemoPasswordStep() {
        password = ""
        otpCode = ""
        stopResendCooldown()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            step = .password
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            focusedField = .password
        }
    }

    private func sendOTPAndAdvance() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await supabase.sendEmailOTP(email: trimmedEmail, shouldCreateUser: false)
            otpCode = ""
            startResendCooldown()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                step = .otp
            }
        } catch {
            authError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func resendOTP() {
        guard !isSubmitting, resendCooldownRemaining == 0 else { return }
        authError = nil
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                try await supabase.sendEmailOTP(email: trimmedEmail, shouldCreateUser: false)
                otpCode = ""
                startResendCooldown()
            } catch {
                authError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func verifyAndSignIn() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            if step == .password || isDemoAccount {
                _ = try await supabase.signInWithPassword(email: trimmedEmail, password: password)
            } else {
                _ = try await supabase.verifyEmailOTP(email: trimmedEmail, token: otpCode)
            }
            await appState.restoreAuthenticatedSession(showLoading: false)
            AnalyticsService.capture(AnalyticsEvent.signInCompleted)
        } catch {
            authError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func goBackToEmail() {
        authError = nil
        otpCode = ""
        password = ""
        stopResendCooldown()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            step = .email
        }
        focusedField = .email
    }

    private func startResendCooldown() {
        resendCooldownTask?.cancel()
        resendCooldownRemaining = SignUpOTPConfig.resendCooldownSeconds
        resendCooldownTask = Task { @MainActor in
            while resendCooldownRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                resendCooldownRemaining -= 1
            }
        }
    }

    private func stopResendCooldown() {
        resendCooldownTask?.cancel()
        resendCooldownTask = nil
        resendCooldownRemaining = 0
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
