import SwiftUI

// MARK: - Onboarding Context

enum OnboardingContext {
    case firstPet
    case additionalPet(onDismiss: () -> Void)

    var isAdditionalPet: Bool {
        if case .additionalPet = self { return true }
        return false
    }

    func dismissAdditionalPet() {
        if case .additionalPet(let onDismiss) = self {
            onDismiss()
        }
    }
}

// MARK: - Onboarding Coordinator

struct OnboardingCoordinator: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.petmojiPalette) private var palette
    @StateObject private var draft = OnboardingDraft()
    @State private var path: [OnboardingStep] = []
    @State private var showDiscardPetConfirm = false
    @State private var isDiscardingPet = false

    var context: OnboardingContext = .firstPet

    enum OnboardingStep: Hashable {
        case personality
        case spriteReveal
        case widgetSetup
    }

    private var pendingPetId: UUID? {
        draft.completedPet?.id
    }

    private var additionalPetCancelAction: (() -> Void)? {
        guard context.isAdditionalPet else { return nil }
        return { handleCancelTapped() }
    }

    private var progressTotal: Int {
        context.isAdditionalPet ? 3 : 4
    }

    var body: some View {
        NavigationStack(path: $path) {
            PhotoPickerView(
                draft: draft,
                onNext: { path.append(.personality) },
                onCancel: additionalPetCancelAction
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .pmOnboardingToolbar(total: progressTotal, current: 0, balancedBackButton: false)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .personality:
                    PersonalityBuilderView(
                        draft: draft,
                        onNext: { path.append(.spriteReveal) },
                        onCancel: additionalPetCancelAction
                    )
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .pmOnboardingToolbar(total: progressTotal, current: 1, balancedBackButton: true)
                    .toolbarBackground(.hidden, for: .navigationBar)

                case .spriteReveal:
                    ExpressionRevealView(
                        draft: draft,
                        context: context,
                        onComplete: handleRevealComplete,
                        onCancel: additionalPetCancelAction
                    )
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .pmOnboardingToolbar(total: progressTotal, current: 2, balancedBackButton: false)
                    .navigationBarBackButtonHidden(true)

                case .widgetSetup:
                    WidgetSetupView(
                        pet: draft.completedPet,
                        onDone: finishWidgetSetup,
                        onCancel: additionalPetCancelAction
                    )
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .pmOnboardingToolbar(total: progressTotal, current: 3, balancedBackButton: false)
                    .navigationBarBackButtonHidden(true)
                }
            }
        }
        .tint(palette.toolbarTint)
        .alert("Discard this pet?", isPresented: $showDiscardPetConfirm) {
            Button("Discard", role: .destructive) {
                Task { await discardPendingPetAndDismiss() }
            }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Your new pet will be removed and you'll return home.")
        }
        .disabled(isDiscardingPet)
    }

    private func handleCancelTapped() {
        if pendingPetId != nil {
            showDiscardPetConfirm = true
        } else {
            dismissFlow()
        }
    }

    private func dismissFlow() {
        context.dismissAdditionalPet()
    }

    private func handleRevealComplete(_ pet: Pet) {
        draft.completedPet = pet
        if context.isAdditionalPet {
            Task {
                await appState.loadPets(showLoading: false)
                context.dismissAdditionalPet()
            }
        } else {
            path.append(.widgetSetup)
        }
    }

    @MainActor
    private func discardPendingPetAndDismiss() async {
        guard let petId = pendingPetId else {
            dismissFlow()
            return
        }
        isDiscardingPet = true
        appState.stopSyncingExpressions()
        try? await SupabaseService.shared.deletePet(petId: petId)
        appState.removePetLocally(petId: petId)
        draft.completedPet = nil
        isDiscardingPet = false
        dismissFlow()
    }

    private func finishWidgetSetup() {
        if appState.currentPet == nil, let pet = draft.completedPet {
            appState.setPet(pet)
            appState.startSyncingExpressions(petId: pet.id)
        }
        appState.setHasCompletedOnboarding(true)
    }
}

// MARK: - Onboarding Draft (shared state)

@MainActor
final class OnboardingDraft: ObservableObject {
    @Published var photos: [UIImage] = []
    @Published var photoData: [Data] = []
    @Published var name: String = ""
    @Published var species: Species = .dog
    @Published var gender: PetGender = .boy
    @Published var selectedTraits: Set<PersonalityTrait> = []
    @Published var energyLevel: Double = 5.0
    @Published var selectedTriggers: Set<PetTrigger> = []
    @Published var customTrigger: String = ""
    @Published var baseMood: BaseMood = .chill
    @Published var completedPet: Pet?
    @Published var generatedExpressions: ExpressionMap = ExpressionMap()

    var isPhotoStepValid: Bool { !photos.isEmpty }
    var isPersonalityStepValid: Bool {
        selectedTraits.count == 3 && isTriggersStepValid
    }
}
