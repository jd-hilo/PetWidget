import SwiftUI

// MARK: - Home Location Setup View

struct HomeLocationSetupView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.petmojiPalette) private var palette
    @ObservedObject private var locationService = LocationService.shared

    var pet: Pet?
    let onDone: () -> Void
    var onCancel: (() -> Void)?

    @State private var isSavingHome = false
    @State private var homeSaved = false
    @State private var skippedHome = false
    @State private var homeError: String?
    @State private var showLocationConsentPrompt = false

    private var resolvedPet: Pet? {
        pet ?? appState.currentPet ?? appState.availablePets.first
    }

    private var canFinish: Bool {
        resolvedPet != nil && !isSavingHome
    }

    var body: some View {
        ZStack {
            PMSageScreenBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    HomeLocationHeroPlaceholder()
                        .padding(.top, 8)

                    (
                        Text("Set your home location so your pet can notice when you leave and send you ")
                            .foregroundStyle(palette.textPrimary)
                        + Text("personalized updates")
                            .foregroundStyle(palette.accentDark)
                        + Text(".")
                            .foregroundStyle(palette.textPrimary)
                    )
                    .font(.bodyL)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 12) {
                        if homeSaved {
                            Label("Home location saved", systemImage: "checkmark.circle.fill")
                                .font(.bodyM)
                                .foregroundStyle(palette.accentDark)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(palette.elevatedCardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(palette.elevatedCardStroke, lineWidth: 1.2)
                                )
                        } else if !skippedHome {
                            Button(action: { saveHomeFromCurrentLocation() }) {
                                HomeLocationOptionRow(isSaving: isSavingHome)
                            }
                            .buttonStyle(.plain)
                            .disabled(resolvedPet == nil || isSavingHome)

                            Button("Skip for now") {
                                skippedHome = true
                                homeError = nil
                            }
                            .font(.bodyM)
                            .foregroundStyle(palette.textSecondary)
                            .frame(maxWidth: .infinity)
                        }

                        if let homeError {
                            Text(homeError)
                                .font(.bodyS)
                                .foregroundStyle(.red.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if locationService.needsAlwaysForLeaveHomeAlerts {
                            Text("Choose Always Allow for location so your pet can react when you leave home in the background.")
                                .font(.bodyS)
                                .foregroundStyle(palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(spacing: 12) {
                        PMSageCTAButton(
                            title: isSavingHome ? "saving home…" : "done, let's go →",
                            action: finishOnboarding,
                            isEnabled: canFinish
                        )

                        if let onCancel {
                            PMOnboardingCancelButton(action: onCancel)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .pmOnboardingScreenTitle("where is home?")
        .alert("Enable leave-home reactions?", isPresented: $showLocationConsentPrompt) {
            Button("Use Current Location") {
                saveHomeFromCurrentLocation(finishAfterSave: true)
            }
            Button("Not Now", role: .cancel) {
                skippedHome = true
                homeError = nil
                onDone()
            }
        } message: {
            Text("Petmoji will save this spot as home so your pet can react when you leave and come back. You can turn this off later in Settings.")
        }
    }

    private func finishOnboarding() {
        if homeSaved || skippedHome {
            onDone()
        } else {
            showLocationConsentPrompt = true
        }
    }

    private func saveHomeFromCurrentLocation(finishAfterSave: Bool = false) {
        guard let resolvedPet else {
            homeError = "Create your pet first, then set home."
            return
        }
        homeError = nil
        isSavingHome = true
        Task {
            defer { isSavingHome = false }
            do {
                try await locationService.saveCurrentLocationAsHome(
                    petId: resolvedPet.id,
                    petName: resolvedPet.name
                ) { lat, lng in
                    appState.updatePetHome(petId: resolvedPet.id, lat: lat, lng: lng)
                }
                homeSaved = true
                if finishAfterSave {
                    onDone()
                }
            } catch {
                homeError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

// MARK: - Hero Placeholder

private struct HomeLocationHeroPlaceholder: View {
    @Environment(\.petmojiPalette) private var palette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.elevatedCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(palette.elevatedCardStroke, lineWidth: 1.2)
                )

            Image(systemName: "location.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(palette.accent.opacity(0.85))
        }
        .frame(maxWidth: 280)
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Location tracking illustration placeholder")
    }
}

// MARK: - Location Option Row

private struct HomeLocationOptionRow: View {
    @Environment(\.petmojiPalette) private var palette

    let isSaving: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(palette.accentDark)
                .frame(width: 44, height: 44)
                .background(palette.accent.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(isSaving ? "Saving home…" : "Use current location as home")
                    .font(.bodyL)
                    .foregroundStyle(palette.textPrimary)
                Text("Pinpoints your current coordinates")
                    .font(.bodyS)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 8)

            if isSaving {
                ProgressView()
                    .tint(palette.accentDark)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .padding(16)
        .background(palette.elevatedCardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(palette.elevatedCardStroke, lineWidth: 1.2)
        )
    }
}
