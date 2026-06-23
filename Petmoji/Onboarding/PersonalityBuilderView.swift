import SwiftUI

// MARK: - Onboarding layout

private enum OnboardingLayout {
    static let horizontalPadding: CGFloat = 16
    static let cardPadding: CGFloat = 18
    static let cardCornerRadius: CGFloat = 22
    static let contentSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 10
}

// MARK: - Personality Builder View (step wizard)

struct PersonalityBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.petmojiPalette) private var palette
    @ObservedObject var draft: OnboardingDraft
    var initialActiveStep: Int = 0
    var initialIsReviewScreen: Bool = false
    let onNext: () -> Void
    var onCancel: (() -> Void)?
    var onProgressChange: ((_ activeStep: Int, _ isReview: Bool) -> Void)? = nil

    private static let totalSteps = 5

    @State private var activeStep: Int = 0
    @State private var isReviewScreen: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        mainStepContent
                            .padding(.horizontal, OnboardingLayout.horizontalPadding)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.4, dampingFraction: 0.88), value: activeStep)
            .animation(.spring(response: 0.4, dampingFraction: 0.88), value: isReviewScreen)
        }
        .safeAreaInset(edge: .bottom) {
            bottomBarPadded
        }
        .pmSageScreenBackground()
        .onAppear {
            activeStep = initialActiveStep
            isReviewScreen = initialIsReviewScreen
        }
    }

    @ViewBuilder
    private var mainStepContent: some View {
        Group {
            if isReviewScreen {
                PersonalityReviewSummary(draft: draft) { step in
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        isReviewScreen = false
                        activeStep = step
                        notifyProgressChange()
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
    }

    private var bottomBarPadded: some View {
        bottomBar
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, onCancel != nil ? 10 : 34)
    }

    // MARK: - Step header

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(currentScreenTitle)
                .font(.displayL)
                .foregroundStyle(palette.accentDark)
                .fixedSize(horizontal: false, vertical: true)

            if !isReviewScreen {
                Text("step \(activeStep + 1) of \(Self.totalSteps)")
                    .font(.bodyM)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 10)
    }

    private var currentScreenTitle: String {
        if isReviewScreen {
            return "here’s what we’ve got"
        }
        switch activeStep {
        case 0: return "boy or girl?"
        case 1: return "pick 3 words that describe them"
        case 2: return "energy level"
        case 3: return "what sets them off?"
        case 4: return "general vibe"
        default: return ""
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var currentStepCard: some View {
        switch activeStep {
        case 0:
            PersonalitySection {
                GenderPickerView(selectedGender: $draft.gender)
            }
        case 1:
            PersonalitySection {
                TraitGridView(selectedTraits: $draft.selectedTraits)
            }
        case 2:
            PersonalitySection {
                EnergySliderView(value: $draft.energyLevel)
            }
        case 3:
            PersonalitySection {
                TriggerSelectorView(
                    selectedTriggers: $draft.selectedTriggers,
                    customTrigger: $draft.customTrigger
                )
            }
        case 4:
            PersonalitySection {
                MoodSelectorView(selectedMood: $draft.baseMood)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Bottom actions

    private var bottomBarSpacing: CGFloat {
        onCancel != nil ? 8 : 12
    }

    @ViewBuilder
    private var bottomBar: some View {
        if isReviewScreen {
            VStack(spacing: bottomBarSpacing) {
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
                        notifyProgressChange()
                    }
                } label: {
                        Text("back to last step")
                        .font(.bodyM)
                        .foregroundStyle(palette.accentDark)
                }
                .buttonStyle(.plain)
            }
        } else {
            VStack(spacing: bottomBarSpacing) {
                PMSageCTAButton(
                    title: activeStep == Self.totalSteps - 1 ? "review →" : "continue →",
                    action: advanceWizard,
                    isEnabled: canContinueFromActiveStep
                )
                if let onCancel {
                    PMOnboardingCancelButton(action: onCancel)
                }

                Button {
                    if activeStep > 0 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                            activeStep -= 1
                            notifyProgressChange()
                        }
                    } else {
                        dismiss()
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
                notifyProgressChange()
            }
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                isReviewScreen = true
                notifyProgressChange()
            }
        }
    }

    private func notifyProgressChange() {
        onProgressChange?(activeStep, isReviewScreen)
    }
}

// MARK: - Review summary

private struct PersonalityReviewSummary: View {
    @Environment(\.petmojiPalette) private var palette
    @ObservedObject var draft: OnboardingDraft
    let onEditStep: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            reviewRow(title: "gender", value: draft.gender.displayName, step: 0)
            reviewRow(title: "traits", value: traitSummary, step: 1)
            reviewRow(title: "energy", value: "\(Int(draft.energyLevel))/10", step: 2)
            reviewRow(title: "triggers", value: draft.triggersReviewSummary, step: 3)
            reviewRow(title: "vibe", value: draft.baseMood.displayName, step: 4, showDivider: false)
        }
        .pmSageCard(cornerRadius: OnboardingLayout.cardCornerRadius)
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
                        .font(.bodyM)
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
                .font(.bodyM)
                .bold()
                .foregroundStyle(palette.accent)
            }
            .padding(.horizontal, 20)
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
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(OnboardingLayout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pmSageCard(cornerRadius: OnboardingLayout.cardCornerRadius)
    }
}

// MARK: - Trait Grid

struct TraitGridView: View {
    @Binding var selectedTraits: Set<PersonalityTrait>

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: OnboardingLayout.contentSpacing) {
            ForEach(PersonalityTrait.allCases, id: \.self) { trait in
                PMTraitPill(
                    trait: trait,
                    isSelected: selectedTraits.contains(trait),
                    isProminent: true
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
        VStack(spacing: OnboardingLayout.sectionSpacing) {
            Slider(value: $value, in: 1...10, step: 1) {
                EmptyView()
            }
            .controlSize(.large)
            .tint(
                LinearGradient(
                    colors: [Color.pmSageAccent, Color.pmSageAccentDark, Color.pmClay],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            HStack {
                Text("professional napper")
                    .font(.bodyM)
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                Text("absolute chaos")
                    .font(.bodyM)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Trigger Selector

private enum TriggerSelectorConfig {
    static let maxPresetSelections = 3
    static let maxCustomLength = 40

    static let featuredTriggers: [PetTrigger] = [
        .doorbell,
        .strangers,
        .otherPets,
        .beingIgnored,
        .loneliness,
        .bathTime,
    ]
}

struct TriggerSelectorView: View {
    @Environment(\.petmojiPalette) private var palette
    @Binding var selectedTriggers: Set<PetTrigger>
    @Binding var customTrigger: String

    @State private var showsAllTriggers = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var visibleTriggers: [PetTrigger] {
        showsAllTriggers ? Array(PetTrigger.allCases) : TriggerSelectorConfig.featuredTriggers
    }

    private var hiddenSelectedTriggers: Bool {
        let featured = Set(TriggerSelectorConfig.featuredTriggers)
        return selectedTriggers.contains { !featured.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.sectionSpacing) {
            VStack(alignment: .leading, spacing: OnboardingLayout.contentSpacing) {
                Text("pick up to \(TriggerSelectorConfig.maxPresetSelections)")
                    .font(.bodyL)
                    .bold()
                    .foregroundStyle(palette.accentDark)

                LazyVGrid(columns: columns, spacing: OnboardingLayout.contentSpacing) {
                    ForEach(visibleTriggers, id: \.self) { trigger in
                        PMChip(
                            label: trigger.displayName,
                            isSelected: selectedTriggers.contains(trigger),
                            isProminent: true
                        ) {
                            toggleTrigger(trigger)
                        }
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        showsAllTriggers.toggle()
                    }
                } label: {
                    Text(showsAllTriggers ? "collapse" : "expand to show more")
                        .font(.bodyL)
                        .foregroundStyle(palette.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            Divider()
                .background(palette.border.opacity(0.5))

            VStack(alignment: .leading, spacing: OnboardingLayout.contentSpacing) {
                Text("something else?")
                    .font(.bodyL)
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
                    .padding(16)
                    .background(palette.chromeButtonFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(palette.border, lineWidth: 1.5)
                    )

                Text("\(customTrigger.count)/\(TriggerSelectorConfig.maxCustomLength)")
                    .font(.bodyM)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .onAppear { expandIfNeeded() }
        .onChange(of: selectedTriggers) { _, _ in expandIfNeeded() }
    }

    private func expandIfNeeded() {
        if hiddenSelectedTriggers {
            showsAllTriggers = true
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
        HStack(spacing: OnboardingLayout.contentSpacing) {
            ForEach(PetGender.allCases, id: \.self) { gender in
                PMChip(
                    label: gender.displayName,
                    isSelected: selectedGender == gender,
                    isProminent: true
                ) {
                    selectedGender = gender
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Mood Selector

struct MoodSelectorView: View {
    @Binding var selectedMood: BaseMood

    var body: some View {
        VStack(spacing: OnboardingLayout.contentSpacing) {
            ForEach(BaseMood.allCases, id: \.self) { mood in
                PMChip(
                    label: mood.displayName,
                    isSelected: selectedMood == mood,
                    isProminent: true
                ) {
                    selectedMood = mood
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
