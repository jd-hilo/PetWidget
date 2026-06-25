import SwiftUI

// MARK: - Location notification demo mockup

struct LocationNotificationDemoMockup: View {
    let petName: String
    let maxWidth: CGFloat
    let maxHeight: CGFloat

    private static let deviceAspectRatio: CGFloat = 9.0 / 19.5
    private static let deviceScale: CGFloat = 0.82
    /// Canonical design size; the whole mockup is laid out at this size and then
    /// scaled to fit, so fonts, padding, and the Dynamic Island stay proportional.
    private static let referenceWidth: CGFloat = 360
    private static let staggerDelay: Duration = .milliseconds(550)
    private static let holdDuration: Duration = .seconds(3)

    @State private var visibleCount = 0
    @State private var isFadingOut = false
    @State private var animationTask: Task<Void, Never>?

    private var notifications: [DemoNotification] {
        [
            DemoNotification(timestamp: "now", message: "wait… you're leaving me??"),
            DemoNotification(timestamp: "1h ago", message: "it's been an hour. just saying."),
            DemoNotification(timestamp: "3h ago", message: "ok so you're NEVER coming back"),
        ]
    }

    private var fittedSize: CGSize {
        let width = maxWidth
        let heightFromWidth = width / Self.deviceAspectRatio
        let base: CGSize
        if heightFromWidth <= maxHeight {
            base = CGSize(width: width, height: heightFromWidth)
        } else {
            let height = maxHeight
            base = CGSize(width: height * Self.deviceAspectRatio, height: height)
        }
        return CGSize(width: base.width * Self.deviceScale, height: base.height * Self.deviceScale)
    }

    var body: some View {
        let referenceHeight = Self.referenceWidth / Self.deviceAspectRatio
        let scale = fittedSize.width / Self.referenceWidth

        iPhoneLockScreenMockup(
            petName: petName,
            notifications: notifications,
            visibleCount: visibleCount,
            isFadingOut: isFadingOut
        )
        .frame(width: Self.referenceWidth, height: referenceHeight)
        .scaleEffect(scale)
        .frame(width: fittedSize.width, height: fittedSize.height)
        .frame(maxWidth: .infinity)
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of Petmoji notifications when you leave home")
        .onAppear { startAnimationLoop() }
        .onDisappear { stopAnimationLoop() }
    }

    private func startAnimationLoop() {
        stopAnimationLoop()
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                visibleCount = 0
                isFadingOut = false

                for index in notifications.indices {
                    try? await Task.sleep(for: index == 0 ? .milliseconds(200) : Self.staggerDelay)
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        visibleCount = index + 1
                    }
                }

                try? await Task.sleep(for: Self.holdDuration)
                guard !Task.isCancelled else { return }

                withAnimation(.easeOut(duration: 0.35)) {
                    isFadingOut = true
                }

                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
            }
        }
    }

    private func stopAnimationLoop() {
        animationTask?.cancel()
        animationTask = nil
    }
}

// MARK: - iPhone lock screen

private struct iPhoneLockScreenMockup: View {
    let petName: String
    let notifications: [DemoNotification]
    let visibleCount: Int
    let isFadingOut: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.black.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1.5)
                )

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(lockScreenWallpaper)
                .padding(6)
                .overlay {
                    lockScreenContent
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                }
                .padding(6)
        }
    }

    private var lockScreenWallpaper: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.pmSageWashDeep,
                Color.pmSageAccent.opacity(0.55),
                Color.pmSageAccentDark.opacity(0.75),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var lockScreenContent: some View {
        VStack(spacing: 0) {
            dynamicIsland
                .padding(.top, 10)

            lockScreenClock
                .padding(.top, 18)

            notificationStack
                .padding(.horizontal, 10)
                .padding(.top, 20)

            Spacer(minLength: 0)
        }
    }

    private var dynamicIsland: some View {
        Capsule(style: .continuous)
            .fill(Color.black)
            .frame(width: 118, height: 36)
    }

    private var lockScreenClock: some View {
        VStack(spacing: 6) {
            Text("9:41")
                .font(.system(size: 74, weight: .thin, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)

            Text("Tuesday, June 24")
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
        }
    }

    private var notificationStack: some View {
        VStack(spacing: 10) {
            ForEach(Array(notifications.enumerated()), id: \.offset) { index, notification in
                if index < visibleCount {
                    IOSNotificationBanner(
                        petName: petName,
                        notification: notification
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .opacity(isFadingOut ? 0 : 1)
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: visibleCount)
        .animation(.easeOut(duration: 0.35), value: isFadingOut)
    }
}

// MARK: - Notification banner

private struct IOSNotificationBanner: View {
    let petName: String
    let notification: DemoNotification

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("Petmoji")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .textCase(.uppercase)

                Spacer(minLength: 8)

                Text(notification.timestamp)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
            }

            HStack(alignment: .top, spacing: 11) {
                Image("PetmojiAppIcon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(petName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(notification.message)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Model

private struct DemoNotification {
    let timestamp: String
    let message: String
}
