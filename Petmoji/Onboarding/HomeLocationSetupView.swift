import SwiftUI

// MARK: - Home Location Setup View

struct HomeLocationSetupView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.petmojiPalette) private var palette
    @ObservedObject private var locationService = LocationService.shared

    var pet: Pet?
    let onDone: () -> Void
    var onCancel: (() -> Void)?

    @State private var isSettingUp = false
    @State private var homeSaved = false
    @State private var skippedHome = false
    @State private var homeError: String?

    private var resolvedPet: Pet? {
        pet ?? appState.currentPet ?? appState.availablePets.first
    }

    private var canFinish: Bool {
        (homeSaved || skippedHome) && !isSettingUp
    }

    private func videoMaxHeight(in availableHeight: CGFloat) -> CGFloat {
        let subtextAndTop: CGFloat = 48
        return max(140, availableHeight - subtextAndTop - 8)
    }

    var body: some View {
        ZStack {
            PMSageScreenBackdrop()

            GeometryReader { geo in
                let contentWidth = geo.size.width - 48
                let maxVideoHeight = videoMaxHeight(in: geo.size.height)

                VStack(alignment: .leading, spacing: 8) {
                    Text("turn on location and notifications for the best experience")
                        .font(.bodyS)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    OnboardingLoopingVideoPlayer(
                        resourceName: "NotificationDemo",
                        maxWidth: contentWidth,
                        maxHeight: maxVideoHeight,
                        accessibilityLabel: "Location and notification setup walkthrough video"
                    )

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 8) {
            VStack(spacing: 8) {
                if let homeError {
                    Text(homeError)
                        .font(.bodyS)
                        .foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }

                if !skippedHome {
                    LocationTrackingPrimaryButton(
                        title: locationButtonTitle,
                        subtitle: locationButtonSubtitle,
                        isLoading: isSettingUp,
                        isEnabled: !homeSaved,
                        action: enableLocationTracking
                    )
                    .disabled(isSettingUp || resolvedPet == nil || homeSaved)
                }

                PMSageCTAButton(
                    title: "done, let's go →",
                    action: onDone,
                    isEnabled: canFinish
                )

                if !homeSaved && !skippedHome {
                    Button("Skip for now") {
                        skippedHome = true
                        homeError = nil
                    }
                    .font(.bodyM)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity)
                } else {
                    Text("You can always turn this on later in settings")
                        .font(.bodyS)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                if let onCancel {
                    PMOnboardingCancelButton(action: onCancel)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
            .background(Color.clear)
        }
        .pmOnboardingScreenTitle("want me to message when you leave home?", titleTopPadding: 8)
    }

    private var locationButtonTitle: String {
        if isSettingUp { return "setting up location…" }
        if homeSaved { return "home location saved" }
        return "turn on location tracking"
    }

    private var locationButtonSubtitle: String? {
        guard homeSaved else { return nil }
        return "update home in Settings anytime"
    }

    private func enableLocationTracking() {
        guard let resolvedPet else {
            homeError = "Create your pet first, then set home."
            return
        }
        homeError = nil
        isSettingUp = true
        Task {
            defer { isSettingUp = false }
            do {
                try await locationService.requestOnboardingLocationThenNotifications()

                let status = locationService.authorizationStatus
                guard status == .authorizedWhenInUse || status == .authorizedAlways else {
                    homeError = HomeLocationError.permissionDenied.errorDescription
                    return
                }

                try await locationService.saveCurrentLocationAsHome(
                    petId: resolvedPet.id,
                    petName: resolvedPet.name,
                    requestPermissions: false
                ) { lat, lng in
                    appState.updatePetHome(petId: resolvedPet.id, lat: lat, lng: lng)
                }
                homeSaved = true
                homeError = nil
            } catch let error as HomeLocationError {
                homeError = error.errorDescription
            } catch {
                homeError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

// MARK: - Primary Button

private struct LocationTrackingPrimaryButton: View {
    @Environment(\.petmojiPalette) private var palette

    let title: String
    let subtitle: String?
    let isLoading: Bool
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.buttonFont)
                        .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.bodyS)
                        .foregroundStyle(.white.opacity(isEnabled ? 0.85 : 0.75))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule(style: .continuous)
                    .fill(isEnabled ? palette.accent : palette.accent.opacity(0.55))
            )
            .shadow(
                color: isEnabled
                    ? palette.accentDark.opacity(palette.visualStyle == .widgetGlass ? 0.45 : 0.28)
                    : .clear,
                radius: 10,
                x: 0,
                y: 6
            )
        }
        .buttonStyle(.plain)
        .allowsHitTesting(isEnabled && !isLoading)
    }
}
