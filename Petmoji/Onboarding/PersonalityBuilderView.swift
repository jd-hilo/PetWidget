import SwiftUI

// MARK: - Personality Builder View (step wizard)

struct PersonalityBuilderView: View {
    @Environment(\.petmojiPalette) private var palette
    @ObservedObject var draft: OnboardingDraft
    let onNext: () -> Void
    var onCancel: (() -> Void)?

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
                .foregroundStyle(palette.accentDark)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if isReviewScreen {
                    Text("review & generate")
                        .font(.bodyM)
                        .foregroundStyle(palette.textSecondary)
                } else {
                    Text("step \(activeStep + 1) of \(Self.totalSteps)")
                        .font(.bodyM)
                        .bold()
                        .foregroundStyle(palette.accentDark)
                    Text("·")
                        .foregroundStyle(palette.textSecondary)
                    Text("~\(secondsRemainingEstimate)s left")
                        .font(.bodyM)
                        .foregroundStyle(palette.textSecondary)
                }
            }

            Text("about \(Self.totalSteps * Self.estimatedSecondsPerStep)s total")
                .font(.bodyS)
                .foregroundStyle(palette.textSecondary.opacity(0.9))
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
                gradient: [palette.washSoft, palette.washDeep]
            ) {
                GenderPickerView(selectedGender: $draft.gender)
            }
        case 1:
            PersonalitySection(
                title: "pick 3 words that describe them",
                gradient: [palette.washAltSoft, palette.washAltDeep]
            ) {
                TraitGridView(selectedTraits: $draft.selectedTraits)
            }
        case 2:
            PersonalitySection(
                title: "energy level",
                gradient: [palette.washMid, palette.washDeep]
            ) {
                EnergySliderView(value: $draft.energyLevel)
            }
        case 3:
            PersonalitySection(
                title: "what sets them off?",
                gradient: [Color.pmClayLight, Color.pmClayMid],
                titleColor: Color.pmClayDark
            ) {
                TriggerSelectorView(
                    selectedTriggers: $draft.selectedTriggers,
                    customTrigger: $draft.customTrigger
                )
            }
        case 4:
            PersonalitySection(
                title: "general vibe",
                gradient: [palette.surface, palette.washDeep]
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
                if let onCancel {
                    PMOnboardingCancelButton(action: onCancel)
                }
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        isReviewScreen = false
                        activeStep = Self.totalSteps - 1
                    }
                } label: {
                        Text("back to last step")
                        .font(.bodyM)
                        .foregroundStyle(palette.accentDark)
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
                if let onCancel {
                    PMOnboardingCancelButton(action: onCancel)
                }

                if activeStep > 0 {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                            activeStep -= 1
                        }
                    } label: {
                        Text("previous step")
                            .font(.bodyM)
                            .foregroundStyle(palette.accentDark)
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
        case 2, 4: return true
        case 3: return draft.isTriggersStepValid
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
    @Environment(\.petmojiPalette) private var palette

    let activeStep: Int
    let maxUnlockedStep: Int
    /// Fills the bar through the furthest step reached (does not shrink when revisiting earlier steps).
    let furthestProgressStep: Int
    let isReviewComplete: Bool
    let totalSteps: Int
    let onSelectStep: (Int) -> Void

    private let labels = ["gender", "traits", "energy", "triggers", "mood"]

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
                        .fill(palette.segmentMuted.opacity(0.55))
                        .frame(height: 4)

                    Capsule()
                        .fill(palette.accent)
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
                                        ? (isReviewComplete ? palette.accentDark : Color.white)
                                        : (isDone ? palette.accentDark : palette.textSecondary.opacity(0.45))
                                )
                                .frame(width: 22, height: 22)
                                .background(
                                    Circle()
                                        .fill(
                                            isReviewComplete
                                                ? palette.surface
                                                : (isCurrent ? palette.accent : (isDone ? palette.surface : Color.clear))
                                        )
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(palette.border.opacity(isLocked ? 0.35 : 0.9), lineWidth: 1)
                                )

                            Text(labels[index])
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(
                                    isLocked ? palette.textSecondary.opacity(0.35) : palette.textSecondary
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
    @Environment(\.petmojiPalette) private var palette
    @ObservedObject var draft: OnboardingDraft
    let onEditStep: (Int) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("here’s what we’ve got")
                    .font(.titleL)
                    .foregroundStyle(palette.accentDark)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                VStack(spacing: 0) {
                    reviewRow(title: "gender", value: draft.gender.displayName, step: 0)
                    reviewRow(title: "traits", value: traitSummary, step: 1)
                    reviewRow(title: "energy", value: "\(Int(draft.energyLevel))/10", step: 2)
                    reviewRow(title: "triggers", value: draft.triggersReviewSummary, step: 3)
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
                        .foregroundStyle(palette.textSecondary)
                    Text(value)
                        .font(.bodyL)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button("edit") {
                    onEditStep(step)
                }
                .font(.bodyS)
                .bold()
                .foregroundStyle(palette.accent)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .contentShape(Rectangle())

            if showDivider {
                Divider()
                    .background(palette.border.opacity(0.5))
                    .padding(.leading, 18)
            }
        }
    }
}

// MARK: - Section Container

struct PersonalitySection<Content: View>: View {
    @Environment(\.petmojiPalette) private var palette

    let title: String
    let gradient: [Color]
    var titleColor: Color?
    @ViewBuilder let content: () -> Content

    init(title: String, gradient: [Color], titleColor: Color? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.gradient = gradient
        self.titleColor = titleColor
        self.content = content
    }

    private var resolvedTitleColor: Color {
        titleColor ?? palette.accentDark
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.titleL)
                    .foregroundStyle(resolvedTitleColor)
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
    @Environment(\.petmojiPalette) private var palette
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
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                Text("absolute chaos")
                    .font(.bodyS)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }
}

// MARK: - Trigger Selector

private enum TriggerSelectorConfig {
    static let maxPresetSelections = 3
    static let maxCustomLength = 40
}

struct TriggerSelectorView: View {
    @Environment(\.petmojiPalette) private var palette
    @Binding var selectedTriggers: Set<PetTrigger>
    @Binding var customTrigger: String

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("pick up to \(TriggerSelectorConfig.maxPresetSelections) (or add your own below)")
                .font(.bodyS)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(PetTrigger.allCases, id: \.self) { trigger in
                    PMChip(
                        label: trigger.displayName,
                        isSelected: selectedTriggers.contains(trigger)
                    ) {
                        toggleTrigger(trigger)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("something else?")
                    .font(.bodyM)
                    .bold()
                    .foregroundStyle(palette.accentDark)

                TextField("e.g. skateboards, squirrels...", text: $customTrigger)
                    .font(.bodyL)
                    .foregroundStyle(palette.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .tint(palette.accent)
                    .onChange(of: customTrigger) { _, newValue in
                        if newValue.count > TriggerSelectorConfig.maxCustomLength {
                            customTrigger = String(newValue.prefix(TriggerSelectorConfig.maxCustomLength))
                        }
                    }
                    .padding(14)
                    .background(palette.chromeButtonFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(palette.border, lineWidth: 1.5)
                    )

                Text("\(customTrigger.count)/\(TriggerSelectorConfig.maxCustomLength)")
                    .font(.bodyS)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func toggleTrigger(_ trigger: PetTrigger) {
        if selectedTriggers.contains(trigger) {
            selectedTriggers.remove(trigger)
        } else if selectedTriggers.count < TriggerSelectorConfig.maxPresetSelections {
            selectedTriggers.insert(trigger)
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
