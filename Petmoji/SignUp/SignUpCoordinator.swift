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

    var onSwitchToSignIn: () -> Void = {}

    private let supabase = SupabaseService.shared

    private var completedSteps: [SignUpStep] {
        draft.completedSteps(before: step)
    }

    private var scrollAnchorID: String {
        switch step {
        case .password: return "signup-active-password"
        case .phone: return "signup-active-phone"
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
                            focusedStep: $focusedStep
                        )
                        .id(scrollAnchorID)
                        .transition(activeStepTransition)

                        if let authError {
                            Text(authError)
                                .font(.bodyM)
                                .foregroundStyle(.red.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
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
            case .password: return "creating account…"
            default: return "continue →"
            }
        }
        switch step {
        case .password: return "create account →"
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            focusedStep = newStep
        }
    }

    private func goToStep(_ target: SignUpStep) {
        focusedStep = nil
        authError = nil
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
        case .password:
            Task { await signUpAndComplete() }
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

    private func signUpAndComplete() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await supabase.signUp(email: trimmedEmail, password: draft.password)
            try await supabase.upsertProfile(
                fullName: draft.name,
                email: trimmedEmail,
                phone: draft.phoneDigitsOnly
            )
            await appState.completeSignUp(from: draft)
        } catch {
            authError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
