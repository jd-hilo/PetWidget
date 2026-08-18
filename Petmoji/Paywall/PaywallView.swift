import RevenueCat
import SwiftUI

// MARK: - Plan

enum PaywallPlan: String, CaseIterable, Identifiable {
    case lifetime
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: return "Monthly"
        case .lifetime: return "Lifetime"
        }
    }

    var badge: String? {
        switch self {
        case .monthly: return nil
        case .lifetime: return "Best Value"
        }
    }
}

private struct PaywallBenefit: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

// MARK: - Paywall

struct PaywallView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.petmojiPalette) private var palette
    @Environment(\.openURL) private var openURL

    /// Called after a successful purchase or restore that unlocks Pro.
    var onUnlocked: () -> Void
    /// When false, stay on the paywall even if the user already has Pro (DEBUG previews).
    var allowsAutoUnlock: Bool = true

    @State private var selectedPlan: PaywallPlan = .lifetime
    @State private var offerings: Offerings?
    @State private var isLoadingOfferings = true
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let benefits: [PaywallBenefit] = [
        PaywallBenefit(
            icon: "square.grid.2x2.fill",
            title: "Home screen widget",
            detail: "Keep your petmoji on your lock & home screens"
        ),
        PaywallBenefit(
            icon: "message.fill",
            title: "Unlimited pet messages",
            detail: "Hear from your pet whenever you need a nudge"
        ),
        PaywallBenefit(
            icon: "bell.badge.fill",
            title: "Smart check-ins",
            detail: "Location-aware nudges when you leave home"
        ),
        PaywallBenefit(
            icon: "sparkles",
            title: "All moods & expressions",
            detail: "Unlock every face your pet can make"
        ),
    ]

    private var selectedPackage: Package? {
        guard let offerings else { return nil }
        return SubscriptionService.package(for: selectedPlan, offerings: offerings)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .padding(.top, 12)

                    VStack(spacing: 8) {
                        Text("unlock petmoji")
                            .font(.displayL)
                            .foregroundStyle(palette.accentDark)
                            .multilineTextAlignment(.center)

                        Text("keep your pet close — messages, widgets, and more")
                            .font(.bodyM)
                            .bold()
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(benefits) { benefit in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: benefit.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(palette.accent)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(palette.accent.opacity(0.18))
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(benefit.title)
                                        .font(.bodyL)
                                        .foregroundStyle(palette.textPrimary)
                                    Text(benefit.detail)
                                        .font(.bodyS)
                                        .foregroundStyle(palette.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
            }

            planCard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pmSageScreenBackground()
        .background(PaywallDisableInteractivePop())
        .overlay {
            if isPurchasing || isLoadingOfferings {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                }
            }
        }
        .alert("Something went wrong", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
        .task {
            await loadOfferings()
            if allowsAutoUnlock, appState.isPro {
                onUnlocked()
            }
        }
        .onAppear {
            AnalyticsService.capture(AnalyticsEvent.paywallViewed)
        }
    }

    private var planCard: some View {
        VStack(spacing: 14) {
            VStack(spacing: 18) {
                ForEach(PaywallPlan.allCases) { plan in
                    planRow(plan)
                }
            }

            PMSageCTAButton(
                title: "continue →",
                action: { Task { await purchaseSelected() } },
                isEnabled: !isPurchasing && !isLoadingOfferings && selectedPackage != nil
            )

            HStack(spacing: 20) {
                footerLink("Restore Purchases") {
                    Task { await restore() }
                }
                footerLink("Terms") {
                    if let url = AppLegalLinks.termsURL { openURL(url) }
                }
                footerLink("Privacy") {
                    if let url = AppLegalLinks.privacyURL { openURL(url) }
                }
            }
            .padding(.top, 2)

            Text(subscriptionLegalCopy)
                .font(.bodyS)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }

    private func planRow(_ plan: PaywallPlan) -> some View {
        let isSelected = selectedPlan == plan
        let priceLabel = livePriceLabel(for: plan)

        return Button {
            selectedPlan = plan
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? palette.accent : palette.sageCardStroke,
                            lineWidth: isSelected ? 0 : 1.5
                        )
                        .background(
                            Circle()
                                .fill(isSelected ? palette.accent : Color.clear)
                        )
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(planDisplayTitle(for: plan))
                        .font(.bodyL)
                        .foregroundStyle(palette.textPrimary)
                    if let subtitle = planSubtitle(for: plan) {
                        Text(subtitle)
                            .font(.bodyS)
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                }

                Spacer(minLength: 8)

                Text(priceLabel)
                    .font(.bodyL)
                    .foregroundStyle(palette.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? palette.accent : palette.sageCardStroke,
                        lineWidth: isSelected ? 2.5 : 1.5
                    )
            )
            .overlay(alignment: .topTrailing) {
                if let badge = plan.badge {
                    Text(badge)
                        .font(.nunito(.bold, 11))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(palette.accent))
                        .offset(x: -10, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }

    private func footerLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.bodyS)
            .foregroundStyle(palette.textSecondary)
            .buttonStyle(.plain)
            .disabled(isPurchasing)
    }

    private func storeProduct(for plan: PaywallPlan) -> StoreProduct? {
        guard let offerings else { return nil }
        return SubscriptionService.package(for: plan, offerings: offerings)?.storeProduct
    }

    private func planDisplayTitle(for plan: PaywallPlan) -> String {
        let title = storeProduct(for: plan)?.localizedTitle.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? plan.title : title
    }

    private func planSubtitle(for plan: PaywallPlan) -> String? {
        guard let product = storeProduct(for: plan) else { return nil }
        if let trial = freeTrialPhrase(for: product) {
            return trial
        }
        if let period = product.subscriptionPeriod {
            return "Auto-renews every \(periodPhrase(period))"
        }
        return "One-time purchase"
    }

    private func livePriceLabel(for plan: PaywallPlan) -> String {
        guard let product = storeProduct(for: plan) else { return "—" }
        let price = product.localizedPriceString
        if let period = product.subscriptionPeriod {
            return "\(price)/\(periodUnitSuffix(period))"
        }
        return price
    }

    private var subscriptionLegalCopy: String {
        var lines: [String] = []

        if let monthly = storeProduct(for: .monthly) {
            let title = monthly.localizedTitle.isEmpty ? "Petmoji Pro Monthly" : monthly.localizedTitle
            let price = monthly.localizedPriceString
            let term = monthly.subscriptionPeriod.map(periodPhrase) ?? "month"
            var line = "\(title) is an auto-renewable subscription. Price: \(price) per \(term)."
            if let trial = freeTrialPhrase(for: monthly) {
                line += " \(trial)."
            }
            lines.append(line)
        }

        if let lifetime = storeProduct(for: .lifetime) {
            let title = lifetime.localizedTitle.isEmpty ? "Petmoji Pro Lifetime" : lifetime.localizedTitle
            lines.append("\(title) is a one-time purchase of \(lifetime.localizedPriceString) and does not auto-renew.")
        }

        lines.append(
            "Payment is charged to your Apple ID account at confirmation of purchase. Auto-renewable subscriptions renew unless canceled at least 24 hours before the end of the current period. Your account is charged for renewal within 24 hours prior to the end of the current period. Manage or cancel in Settings → Apple ID → Subscriptions."
        )
        return lines.joined(separator: "\n\n")
    }

    private func freeTrialPhrase(for product: StoreProduct) -> String? {
        guard let intro = product.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let totalUnits = intro.subscriptionPeriod.value * intro.numberOfPeriods
        return "Includes a \(countPhrase(totalUnits, unit: intro.subscriptionPeriod.unit)) free trial"
    }

    private func periodPhrase(_ period: SubscriptionPeriod) -> String {
        countPhrase(period.value, unit: period.unit)
    }

    private func periodUnitSuffix(_ period: SubscriptionPeriod) -> String {
        switch period.unit {
        case .day: return period.value == 1 ? "day" : "\(period.value)d"
        case .week: return period.value == 1 ? "wk" : "\(period.value)wk"
        case .month: return period.value == 1 ? "mo" : "\(period.value)mo"
        case .year: return period.value == 1 ? "yr" : "\(period.value)yr"
        @unknown default: return "mo"
        }
    }

    private func countPhrase(_ value: Int, unit: SubscriptionPeriod.Unit) -> String {
        let name: String
        switch unit {
        case .day: name = value == 1 ? "day" : "days"
        case .week: name = value == 1 ? "week" : "weeks"
        case .month: name = value == 1 ? "month" : "months"
        case .year: name = value == 1 ? "year" : "years"
        @unknown default: name = "month"
        }
        return "\(value) \(name)"
    }

    private func loadOfferings() async {
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }
        do {
            offerings = try await SubscriptionService.fetchOfferings()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func purchaseSelected() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let currentOfferings: Offerings
            if let offerings {
                currentOfferings = offerings
            } else {
                currentOfferings = try await SubscriptionService.fetchOfferings()
                offerings = currentOfferings
            }
            guard let package = SubscriptionService.package(for: selectedPlan, offerings: currentOfferings) else {
                throw SubscriptionError.missingPackage
            }
            let info = try await SubscriptionService.purchase(package: package)
            appState.applyProStatus(SubscriptionService.isPro(from: info))
            if appState.isPro {
                AnalyticsService.capture(
                    AnalyticsEvent.subscriptionPurchased,
                    properties: [
                        "plan": selectedPlan.rawValue,
                        "product_id": package.storeProduct.productIdentifier,
                    ]
                )
                AnalyticsService.trackSubscriptionPeriod(from: info, plan: selectedPlan.rawValue)
                onUnlocked()
            } else {
                errorMessage = "Purchase finished, but Pro isn’t active yet. Try Restore Purchases."
                showError = true
            }
        } catch {
            if SubscriptionService.isUserCancelled(error) { return }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func restore() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let info = try await SubscriptionService.restorePurchases()
            appState.applyProStatus(SubscriptionService.isPro(from: info))
            if appState.isPro {
                AnalyticsService.capture(AnalyticsEvent.subscriptionRestored)
                AnalyticsService.trackSubscriptionPeriod(from: info)
                onUnlocked()
            } else {
                errorMessage = "No active subscription found for this Apple ID."
                showError = true
            }
        } catch {
            if SubscriptionService.isUserCancelled(error) { return }
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Block swipe-back

private struct PaywallDisableInteractivePop: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        Controller()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    private final class Controller: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}
