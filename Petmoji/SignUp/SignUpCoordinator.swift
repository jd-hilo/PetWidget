import SwiftUI

// MARK: - Sign-up coordinator

struct SignUpCoordinator: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.petmojiPalette) private var palette
    @StateObject private var draft = SignUpDraft()
    @State private var step: SignUpStep = .name
    @FocusState private var focusedStep: SignUpStep?

    private var completedSteps: [SignUpStep] {
        draft.completedSteps(before: step)
    }

    private var scrollAnchorID: String {
        switch step {
        case .otp: return "signup-active-otp"
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

                        activeStepContent
                            .id(scrollAnchorID)
                            .transition(activeStepTransition)

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
                    isEnabled: draft.isValid(for: step)
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
            }
            .pmSageScreenBackground()
        }
        .tint(palette.toolbarTint)
    }

    @ViewBuilder
    private var activeStepContent: some View {
        if step == .otp {
            SignUpOTPStepView(
                draft: draft,
                email: draft.email.trimmingCharacters(in: .whitespaces)
            )
        } else {
            SignUpActiveStepView(
                draft: draft,
                step: step,
                focusedStep: $focusedStep
            )
        }
    }

    private var activeStepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }

    private var ctaTitle: String {
        switch step {
        case .otp: return "verify →"
        case .phone: return "continue →"
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
        guard newStep != .otp else {
            focusedStep = nil
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            focusedStep = newStep
        }
    }

    private func goToStep(_ target: SignUpStep) {
        focusedStep = nil
        if target.rawValue < SignUpStep.otp.rawValue {
            draft.applyOTPInput("")
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            step = target
        }
        focusActiveStep(target)
    }

    private func advance() {
        guard draft.isValid(for: step) else { return }
        focusedStep = nil

        if step == .otp {
            appState.completeSignUp(from: draft)
            return
        }

        guard let next = SignUpStep(rawValue: step.rawValue + 1) else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            step = next
        }
    }
}
