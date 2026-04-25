import SwiftUI

// MARK: - Personality Builder View (step wizard)

struct PersonalityBuilderView: View {
    @ObservedObject var draft: OnboardingDraft
    let onNext: () -> Void

    private static let totalSteps = 5
    /// Rough per-step estimate for “time left” copy (personality flow).
    private static let estimatedSecondsPerStep = 11

    @State private var activeStep: Int = 0
    /// Highest step index the user has advanced to; they can jump back to any step ≤ this.
    @State private var maxUnlockedStep: Int = 0
    @State private var isReviewScreen: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            wizardHeader

            PersonalityWizardStepper(
                activeStep: isReviewScreen ? Self.totalSteps : activeStep,
                maxUnlockedStep: maxUnlockedStep,
                furthestProgressStep: max(maxUnlockedStep, activeStep),
                isReviewComplete: isReviewScreen,
                totalSteps: Self.totalSteps,
                onSelectStep: { index in
                    guard index <= maxUnlockedStep else { return }
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        isReviewScreen = false
                        activeStep = index
                    }
                }
            )
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Group {
                if isReviewScreen {
                    PersonalityReviewSummary(draft: draft) { step in
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                            isReviewScreen = false
                            activeStep = step
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                } else {
                    currentStepCard
                        .id(activeStep)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.88), value: activeStep)
            .animation(.spring(response: 0.4, dampingFraction: 0.88), value: isReviewScreen)

            Spacer(minLength: 16)
        }
        .padding(.top, 8)
        .safeAreaInset(edge: .bottom) {
            bottomBar
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
                .background(Color.clear)
        }
        .pmSageScreenBackground()
    }

    // MARK: - Header & progress

    private var wizardHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("who are they, really?")
                .font(.displayL)
                .foregroundStyle(Color.pmSageAccentDark)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if isReviewScreen {
                    Text("review & generate")
                        .font(.bodyM)
                        .foregroundStyle(Color.pmSageTextSecondary)
                } else {
                    Text("step \(activeStep + 1) of \(Self.totalSteps)")
                        .font(.bodyM)
                        .bold()
                        .foregroundStyle(Color.pmSageAccentDark)
                    Text("·")
                        .foregroundStyle(Color.pmSageTextSecondary)
                    Text("~\(secondsRemainingEstimate)s left")
                        .font(.bodyM)
                        .foregroundStyle(Color.pmSageTextSecondary)
                }
            }

            Text("about \(Self.totalSteps * Self.estimatedSecondsPerStep)s total")
                .font(.bodyS)
                .foregroundStyle(Color.pmSageTextSecondary.opacity(0.9))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
    }

    private var secondsRemainingEstimate: Int {
        let stepsLeftIncludingCurrent = Self.totalSteps - activeStep
        return max(0, stepsLeftIncludingCurrent * Self.estimatedSecondsPerStep)
    }

    // MARK: - Step content

    @ViewBuilder
    private var currentStepCard: some View {
        switch activeStep {
        case 0:
            PersonalitySection(
                title: "boy or girl?",
                gradient: [Color.pmSageWashSoft, Color.pmSageWashDeep]
            ) {
                GenderPickerView(selectedGender: $draft.gender)
            }
        case 1:
            PersonalitySection(
                title: "pick 3 words that describe them",
                gradient: [Color.pmSageWashAltSoft, Color.pmSageWashAltDeep]
            ) {
                TraitGridView(selectedTraits: $draft.selectedTraits)
            }
        case 2:
            PersonalitySection(
                title: "energy level",
                gradient: [Color.pmSageWashMid, Color.pmSageWashDeep]
            ) {
                EnergySliderView(value: $draft.energyLevel)
            }
        case 3:
            PersonalitySection(
                title: "biggest enemy",
                gradient: [Color.pmClayLight, Color.pmClayMid],
                titleColor: Color.pmClayDark
            ) {
                EnemyGridView(selectedEnemy: $draft.biggestEnemy)
            }
        case 4:
            PersonalitySection(
                title: "general vibe",
                gradient: [Color.pmSageSurface, Color.pmSageWashDeep]
            ) {
                MoodSelectorView(selectedMood: $draft.baseMood)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Bottom actions

    @ViewBuilder
    private var bottomBar: some View {
        if isReviewScreen {
            VStack(spacing: 12) {
                PMSageCTAButton(
                    title: "generate sprites →",
                    action: onNext,
                    isEnabled: draft.isPersonalityStepValid
                )
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        isReviewScreen = false
                        activeStep = Self.totalSteps - 1
                    }
                } label: {
                    Text("back to last step")
                        .font(.bodyM)
                        .foregroundStyle(Color.pmSageAccentDark)
                }
                .buttonStyle(.plain)
            }
        } else {
            VStack(spacing: 12) {
                PMSageCTAButton(
                    title: activeStep == Self.totalSteps - 1 ? "review →" : "continue →",
                    action: advanceWizard,
                    isEnabled: canContinueFromActiveStep
                )

                if activeStep > 0 {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                            activeStep -= 1
                        }
                    } label: {
                        Text("previous step")
                            .font(.bodyM)
                            .foregroundStyle(Color.pmSageAccentDark)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var canContinueFromActiveStep: Bool {
        switch activeStep {
        case 0: return true
        case 1: return draft.selectedTraits.count == 3
        case 2, 3, 4: return true
        default: return false
        }
    }

    private func advanceWizard() {
        guard canContinueFromActiveStep else { return }
        if activeStep < Self.totalSteps - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                activeStep += 1
                maxUnlockedStep = max(maxUnlockedStep, activeStep)
            }
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                isReviewScreen = true
            }
        }
    }
}

// MARK: - Stepper (tap completed / current steps to go back)

private struct PersonalityWizardStepper: View {
    let activeStep: Int
    let maxUnlockedStep: Int
    /// Fills the bar through the furthest step reached (does not shrink when revisiting earlier steps).
    let furthestProgressStep: Int
    let isReviewComplete: Bool
    let totalSteps: Int
    let onSelectStep: (Int) -> Void

    private let labels = ["gender", "traits", "energy", "enemy", "mood"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                let segment = width / CGFloat(totalSteps)
                let filledSegments = isReviewComplete
                    ? totalSteps
                    : min(totalSteps, furthestProgressStep + 1)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.pmSageSegmentMuted.opacity(0.55))
                        .frame(height: 4)

                    Capsule()
                        .fill(Color.pmSageAccent)
                        .frame(
                            width: segment * CGFloat(filledSegments),
                            height: 4
                        )
                        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: furthestProgressStep)
                        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isReviewComplete)
                }
            }
            .frame(height: 4)

            HStack(spacing: 0) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    let tappable = index <= maxUnlockedStep
                    let isCurrent = !isReviewComplete && index == activeStep
                    let isDone = !isReviewComplete && !isCurrent && index <= maxUnlockedStep
                    let isLocked = index > maxUnlockedStep

                    Button {
                        onSelectStep(index)
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    isReviewComplete || isCurrent
                                        ? (isReviewComplete ? Color.pmSageAccentDark : Color.white)
                                        : (isDone ? Color.pmSageAccentDark : Color.pmSageTextSecondary.opacity(0.45))
                                )
                                .frame(width: 22, height: 22)
                                .background(
                                    Circle()
                                        .fill(
                                            isReviewComplete
                                                ? Color.pmSageSurface
                                                : (isCurrent ? Color.pmSageAccent : (isDone ? Color.pmSageSurface : Color.clear))
                                        )
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.pmSageBorder.opacity(isLocked ? 0.35 : 0.9), lineWidth: 1)
                                )

                            Text(labels[index])
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(
                                    isLocked ? Color.pmSageTextSecondary.opacity(0.35) : Color.pmSageTextSecondary
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(!tappable)
                }
            }
        }
    }
}

// MARK: - Review summary

private struct PersonalityReviewSummary: View {
    @ObservedObject var draft: OnboardingDraft
    let onEditStep: (Int) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("here’s what we’ve got")
                    .font(.titleL)
                    .foregroundStyle(Color.pmSageAccentDark)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                VStack(spacing: 0) {
                    reviewRow(title: "gender", value: draft.gender.displayName, step: 0)
                    reviewRow(title: "traits", value: traitSummary, step: 1)
                    reviewRow(title: "energy", value: "\(Int(draft.energyLevel))/10", step: 2)
                    reviewRow(title: "enemy", value: draft.biggestEnemy.displayName, step: 3)
                    reviewRow(title: "vibe", value: draft.baseMood.displayName, step: 4, showDivider: false)
                }
                .pmSageCard(cornerRadius: 20)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private var traitSummary: String {
        draft.selectedTraits
            .sorted { $0.displayName < $1.displayName }
            .map(\.displayName)
            .joined(separator: ", ")
    }

    private func reviewRow(title: String, value: String, step: Int, showDivider: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.bodyS)
                        .foregroundStyle(Color.pmSageTextSecondary)
                    Text(value)
                        .font(.bodyL)
                        .foregroundStyle(Color.pmSageTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button("edit") {
                    onEditStep(step)
                }
                .font(.bodyS)
                .bold()
                .foregroundStyle(Color.pmSageAccent)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .contentShape(Rectangle())

            if showDivider {
                Divider()
                    .background(Color.pmSageBorder.opacity(0.5))
                    .padding(.leading, 18)
            }
        }
    }
}

// MARK: - Section Container

struct PersonalitySection<Content: View>: View {
    let title: String
    let gradient: [Color]
    var titleColor: Color = Color.pmSageAccentDark
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.titleL)
                    .foregroundStyle(titleColor)
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
            .pmSageCard(cornerRadius: 20)
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
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
            Slider(value: $value, in: 1...10, step: 1) {
                EmptyView()
            }
            .tint(
                LinearGradient(
                    colors: [Color.pmSageAccent, Color.pmSageAccentDark, Color.pmClay],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            HStack {
                Text("professional napper")
                    .font(.bodyS)
                    .foregroundStyle(Color.pmSageTextSecondary)
                Spacer()
                Text("absolute chaos")
                    .font(.bodyS)
                    .foregroundStyle(Color.pmSageTextSecondary)
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
