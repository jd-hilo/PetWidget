import SwiftUI

// MARK: - Sign-up coordinator

struct SignUpCoordinator: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.petmojiPalette) private var palette
    @StateObject private var draft = SignUpDraft()
    @State private var step: SignUpStep = .name
    @FocusState private var focusedStep: SignUpStep?
    @State private var isSubmitting = false
    @State private var authError: String?
    @State private var resendCooldownRemaining = 0
    @State private var resendCooldownTask: Task<Void, Never>?

    var onSwitchToSignIn: () -> Void = {}

    private let supabase = SupabaseService.shared

    private var completedSteps: [SignUpStep] {
        draft.completedSteps(before: step)
    }

    private var scrollAnchorID: String {
        switch step {
        case .otp: return "signup-active-otp"
        case .email: return "signup-active-email"
        case .name: return "signup-active-name"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        if !completedSteps.isEmpty {
                            SignUpCompletedSummaryList(
                                draft: draft,
                                completedSteps: completedSteps,
                                onEditStep: goToStep
                            )
                            .id("signup-summary")
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        SignUpActiveStepView(
                            draft: draft,
                            step: step,
                            focusedStep: $focusedStep,
                            resendCooldownRemaining: resendCooldownRemaining,
                            isResendDisabled: isSubmitting,
                            onResendOTP: resendOTP
                        )
                        .id(scrollAnchorID)
                        .transition(activeStepTransition)

                        if let authError {
                            PMAuthErrorBanner(message: authError)
                        }

                        signInLink

                        Spacer(minLength: 120)
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 24)
                    .animation(.spring(response: 0.45, dampingFraction: 0.86), value: step)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: step) { _, newStep in
                    scrollToActiveStep(proxy: proxy)
                    focusActiveStep(newStep)
                }
                .onAppear {
                    focusedStep = .name
                }
                .onDisappear {
                    resendCooldownTask?.cancel()
                    resendCooldownTask = nil
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    PMOnboardingIconProgressBar(
                        total: SignUpStep.allCases.count,
                        current: step.progressIndex
                    )
                }
            }
            .safeAreaInset(edge: .bottom) {
                PMSageCTAButton(
                    title: ctaTitle,
                    action: advance,
                    isEnabled: draft.isValid(for: step) && !isSubmitting
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
            }
            .pmSageScreenBackground()
        }
        .tint(palette.toolbarTint)
    }

    private var signInLink: some View {
        Button(action: onSwitchToSignIn) {
            HStack(spacing: 4) {
                Text("Already have an account?")
                    .foregroundStyle(palette.textSecondary)
                Text("Sign in")
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.accentDark)
            }
            .font(.bodyM)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private var activeStepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }

    private var ctaTitle: String {
        if isSubmitting {
            switch step {
            case .email: return "sending code…"
            case .otp: return "verifying…"
            default: return "continue →"
            }
        }
        switch step {
        case .email: return "send code →"
        case .otp: return "verify →"
        default: return "continue →"
        }
    }

    private func scrollToActiveStep(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                proxy.scrollTo(scrollAnchorID, anchor: .bottom)
            }
        }
    }

    private func focusActiveStep(_ newStep: SignUpStep) {
        guard newStep != .otp else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            focusedStep = newStep
        }
    }

    private func goToStep(_ target: SignUpStep) {
        focusedStep = nil
        authError = nil
        if target.rawValue <= SignUpStep.email.rawValue {
            draft.clearOTP()
            stopResendCooldown()
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            step = target
        }
        focusActiveStep(target)
    }

    private func advance() {
        guard draft.isValid(for: step), !isSubmitting else { return }
        focusedStep = nil
        authError = nil

        switch step {
        case .email:
            Task { await sendOTPAndAdvance() }
        case .otp:
            Task { await verifyOTPAndComplete() }
        default:
            guard let next = SignUpStep(rawValue: step.rawValue + 1) else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                step = next
            }
        }
    }

    private var trimmedEmail: String {
        draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sendOTPAndAdvance() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await supabase.sendEmailOTP(email: trimmedEmail, shouldCreateUser: true)
            startResendCooldown()
            draft.clearOTP()
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
                try await supabase.sendEmailOTP(email: trimmedEmail, shouldCreateUser: true)
                startResendCooldown()
                draft.clearOTP()
            } catch {
                authError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func verifyOTPAndComplete() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await supabase.verifyEmailOTP(email: trimmedEmail, token: draft.otpCode)
            try await supabase.upsertProfile(
                fullName: draft.name,
                email: trimmedEmail,
                phone: nil
            )
            await appState.completeSignUp(from: draft)
        } catch {
            authError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
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
}
