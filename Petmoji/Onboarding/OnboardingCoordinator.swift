import SwiftUI

// MARK: - Onboarding Coordinator

struct OnboardingCoordinator: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var draft = OnboardingDraft()
    @State private var path: [OnboardingStep] = []

    enum OnboardingStep: Hashable {
        case personality
        case spriteReveal
        case widgetSetup
    }

    var body: some View {
        NavigationStack(path: $path) {
            PhotoPickerView(draft: draft) {
                path.append(.personality)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    PMOnboardingIconProgressBar(total: 4, current: 0)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .personality:
                    PersonalityBuilderView(draft: draft) {
                        path.append(.spriteReveal)
                    }
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            PMOnboardingIconProgressBar(total: 4, current: 1)
                        }
                    }
                    .toolbarBackground(Color.pmBackground, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)

                case .spriteReveal:
                    ExpressionRevealView(draft: draft) { pet in
                        draft.completedPet = pet
                        path.append(.widgetSetup)
                    }
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            PMOnboardingIconProgressBar(total: 4, current: 2)
                        }
                    }
                    .navigationBarBackButtonHidden(true)

                case .widgetSetup:
                    WidgetSetupView {
                        if let pet = draft.completedPet {
                            appState.setPet(pet)
                        }
                    }
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            PMOnboardingIconProgressBar(total: 4, current: 3)
                        }
                    }
                    .navigationBarBackButtonHidden(true)
                }
            }
        }
        .tint(Color.pmTextPrimary)
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
    @Published var biggestEnemy: Enemy = .vacuumCleaner
    @Published var baseMood: BaseMood = .chill
    @Published var completedPet: Pet?
    @Published var generatedExpressions: ExpressionMap = ExpressionMap()

    var isPhotoStepValid: Bool { !photos.isEmpty }
    var isPersonalityStepValid: Bool { !selectedTraits.isEmpty }
}
