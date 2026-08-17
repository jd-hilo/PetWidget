import SwiftUI

// MARK: - Notification permission (user-driven, post-aha)

struct NotificationPermissionView: View {
    @Environment(\.petmojiPalette) private var palette

    var petName: String = "your pet"
    let onNext: () -> Void
    var onCancel: (() -> Void)?

    @State private var isRequesting = false
    @State private var alreadyAuthorized = false
    @State private var titleHeight: CGFloat = 0

    private var displayName: String {
        let trimmed = petName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "your pet" : trimmed
    }

    private func demoMaxHeight(in availableHeight: CGFloat) -> CGFloat {
        let subtextAndTop: CGFloat = 48
        return max(140, availableHeight - subtextAndTop - 8)
    }

    var body: some View {
        ZStack {
            PMSageScreenBackdrop()

            GeometryReader { geo in
                let contentWidth = geo.size.width - 48
                let demoMaxHeight = demoMaxHeight(in: geo.size.height)

                VStack(alignment: .leading, spacing: 8) {
                    Spacer(minLength: 0)

                    Text("want \(displayName) to text you?")
                        .font(.titleL)
                        .foregroundStyle(palette.accentDark)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .background(
                            GeometryReader { titleGeo in
                                Color.clear
                                    .preference(key: NotificationTitleHeightKey.self, value: titleGeo.size.height)
                            }
                        )

                    Text(subtitle)
                        .font(.bodyS)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 20)

                    LocationNotificationDemoMockup(
                        petName: displayName == "your pet" ? "Mochi" : displayName,
                        kind: .checkIn,
                        maxWidth: contentWidth,
                        maxHeight: demoMaxHeight
                    )

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .offset(y: -((titleHeight + 8) / 2))
                .onPreferenceChange(NotificationTitleHeightKey.self) { titleHeight = $0 }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 8) {
            VStack(spacing: 8) {
                PMSageCTAButton(
                    title: primaryTitle,
                    action: handlePrimary,
                    isEnabled: !isRequesting
                )

                if !alreadyAuthorized {
                    Button("not now") {
                        AnalyticsService.capture(AnalyticsEvent.notificationPermissionSkipped)
                        onNext()
                    }
                    .font(.bodyM)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .disabled(isRequesting)
                }

                if let onCancel {
                    PMOnboardingCancelButton(action: onCancel)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
            .background(Color.clear)
        }
        .pmOnboardingScreenTitle("", titleTopPadding: 0)
        .task {
            alreadyAuthorized = await MessageScheduler.shared.isNotificationAuthorized()
        }
    }

    private var subtitle: String {
        if alreadyAuthorized {
            return "you're all set — \(displayName) can send check-ins here."
        }
        return "that's how check-ins show up on your lock screen."
    }

    private var primaryTitle: String {
        if isRequesting { return "one sec…" }
        if alreadyAuthorized { return "continue →" }
        return "allow \(displayName) to text me"
    }

    private func handlePrimary() {
        if alreadyAuthorized {
            onNext()
            return
        }
        isRequesting = true
        Task {
            defer { isRequesting = false }
            let granted = await MessageScheduler.shared.requestNotificationPermission()
            AnalyticsService.capture(
                granted
                    ? AnalyticsEvent.notificationPermissionGranted
                    : AnalyticsEvent.notificationPermissionDenied
            )
            onNext()
        }
    }
}

private struct NotificationTitleHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
