import SwiftUI

// MARK: - Personality Builder View

struct PersonalityBuilderView: View {
    @ObservedObject var draft: OnboardingDraft
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("who are they, really?")
                        .font(.displayL)
                        .foregroundStyle(Color.pmTextPrimary)
                    Text("this takes about 60 seconds")
                        .font(.bodyM)
                        .foregroundStyle(Color.pmTextSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

                // Section 0: Gender
                PersonalitySection(
                    title: "boy or girl?",
                    gradient: [Color(hex: "#D4F0FF"), Color(hex: "#C2E8FF")]
                ) {
                    GenderPickerView(selectedGender: $draft.gender)
                }

                // Section 1: Traits
                PersonalitySection(
                    title: "pick 3 words that describe them",
                    gradient: [Color(hex: "#FFE4D4"), Color(hex: "#FFD0BC")]
                ) {
                    TraitGridView(selectedTraits: $draft.selectedTraits)
                }

                // Section 2: Energy
                PersonalitySection(
                    title: "energy level",
                    gradient: [Color(hex: "#D4EDFF"), Color(hex: "#C2E4FF")]
                ) {
                    EnergySliderView(value: $draft.energyLevel)
                }

                // Section 3: Biggest Enemy
                PersonalitySection(
                    title: "biggest enemy",
                    gradient: [Color(hex: "#FFD4D4"), Color(hex: "#FFBCBC")]
                ) {
                    EnemyGridView(selectedEnemy: $draft.biggestEnemy)
                }

                // Section 4: Base Mood
                PersonalitySection(
                    title: "general vibe",
                    gradient: [Color(hex: "#E4D4FF"), Color(hex: "#D0C2FF")]
                ) {
                    MoodSelectorView(selectedMood: $draft.baseMood)
                }

                Spacer(minLength: 120)
            }
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            PMPrimaryButton(
                title: "generate sprites →",
                action: onNext,
                isEnabled: draft.isPersonalityStepValid
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
            .background(Color.pmBackground.opacity(0.95))
        }
    }
}

// MARK: - Section Container

struct PersonalitySection<Content: View>: View {
    let title: String
    let gradient: [Color]
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Gradient header
            Text(title)
                .font(.titleL)
                .foregroundStyle(Color.pmTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing)
                        .opacity(0.75)
                )

            content()
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .pmCard(cornerRadius: 20, backgroundColor: Color.pmCardAlt)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - Trait Grid

struct TraitGridView: View {
    @Binding var selectedTraits: Set<PersonalityTrait>

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(PersonalityTrait.allCases, id: \.self) { trait in
                PMTraitPill(
                    trait: trait,
                    isSelected: selectedTraits.contains(trait)
                ) {
                    if selectedTraits.contains(trait) {
                        selectedTraits.remove(trait)
                    } else if selectedTraits.count < 3 {
                        selectedTraits.insert(trait)
                    }
                }
            }
        }
    }
}

// MARK: - Energy Slider

struct EnergySliderView: View {
    @Binding var value: Double

    var body: some View {
        VStack(spacing: 12) {
            // Custom gradient slider
            Slider(value: $value, in: 1...10, step: 1) {
                EmptyView()
            }
            .tint(
                LinearGradient(
                    colors: [Color(hex: "#C8F06E"), Color(hex: "#FFE566"), Color(hex: "#FF6B35")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            HStack {
                Text("professional napper")
                    .font(.bodyS)
                    .foregroundStyle(Color.pmTextSecondary)
                Spacer()
                Text("absolute chaos")
                    .font(.bodyS)
                    .foregroundStyle(Color.pmTextSecondary)
            }
        }
    }
}

// MARK: - Enemy Grid

struct EnemyGridView: View {
    @Binding var selectedEnemy: Enemy

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Enemy.allCases, id: \.self) { enemy in
                PMChip(
                    label: enemy.displayName,
                    isSelected: selectedEnemy == enemy
                ) {
                    selectedEnemy = enemy
                }
            }
        }
    }
}

// MARK: - Gender Picker

struct GenderPickerView: View {
    @Binding var selectedGender: PetGender

    var body: some View {
        HStack(spacing: 12) {
            ForEach(PetGender.allCases, id: \.self) { gender in
                PMChip(
                    label: gender.displayName,
                    isSelected: selectedGender == gender
                ) {
                    selectedGender = gender
                }
            }
        }
    }
}

// MARK: - Mood Selector

struct MoodSelectorView: View {
    @Binding var selectedMood: BaseMood

    var body: some View {
        VStack(spacing: 10) {
            ForEach(BaseMood.allCases, id: \.self) { mood in
                PMChip(
                    label: mood.displayName,
                    isSelected: selectedMood == mood
                ) {
                    selectedMood = mood
                }
            }
        }
    }
}
