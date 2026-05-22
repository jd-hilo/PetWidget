import SwiftUI
import UserNotifications

@main
struct PetmojiApp: App {
    @StateObject private var appState = AppState()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .onOpenURL { url in
                    guard url.scheme?.lowercased() == "petmoji" else { return }
                    if url.host?.lowercased() == "chat" {
                        appState.pendingWidgetDeepLink = .openChat
                    }
                }
        }
    }
}

// MARK: - App Delegate (APNs registration)

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task {
            try? await SupabaseService.shared.registerDeviceToken(token)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error)")
    }

    // Handle silent push → reload widget
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task {
            await refreshWidgetData()
            completionHandler(.newData)
        }
    }

    @MainActor
    private func refreshWidgetData() async {
        // Fetch latest message and update shared UserDefaults for widget
        guard let pet = try? await SupabaseService.shared.fetchCurrentPet(),
              let message = try? await SupabaseService.shared.fetchLatestMessage(for: pet.id) else {
            WidgetReloader.reload()
            return
        }

        WidgetSnapshotSync.writeFromPet(pet, message: message)
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var debugDraft = OnboardingDraft()

    private var shouldSkipOnboardingToReveal: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-skipOnboardingToReveal")
#else
        false
#endif
    }

    private var shouldUseMockSprites: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-mockSprites")
#else
        false
#endif
    }

    private var shouldSkipOnboardingToWidgetSetup: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-skipOnboardingToWidgetSetup")
#else
        false
#endif
    }

    private var shouldSkipSignUp: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-skipSignUp")
#else
        false
#endif
    }

    var body: some View {
        Group {
            if shouldSkipOnboardingToWidgetSetup && appState.currentPet == nil {
                NavigationStack {
                    WidgetSetupView {
#if DEBUG
                        appState.setPet(makeDebugRogerPet(useMockSprites: shouldUseMockSprites))
#endif
                        appState.setHasCompletedOnboarding(true)
                    }
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .pmOnboardingToolbar(total: 4, current: 3, balancedBackButton: false)
                    .navigationBarBackButtonHidden(true)
                }
            } else if shouldSkipOnboardingToReveal {
                DebugRevealFlowView(
                    draft: debugDraft,
                    onSetPet: appState.setPet(_:),
                    useMockSprites: shouldUseMockSprites
                )
            } else if appState.currentPet != nil, appState.hasCompletedOnboarding {
                NavigationStack {
                    PetHomeView()
                }
            } else if appState.isLoading {
                Color.clear
                    .pmSageScreenBackground()
            } else if !appState.hasCompletedSignUp && !shouldSkipSignUp {
                AuthCoordinator()
            } else {
                OnboardingCoordinator()
            }
        }
        .environment(\.petmojiPalette, PetmojiPalette.palette(for: appState.visualStyle))
        .preferredColorScheme(appState.visualStyle == .widgetGlass ? .dark : .light)
        .task {
            if !shouldSkipOnboardingToReveal && !shouldSkipOnboardingToWidgetSetup {
                await appState.bootstrap()
            }
        }
    }

#if DEBUG
    private func makeDebugRogerPet(useMockSprites: Bool) -> Pet {
        Pet(
            id: UUID(),
            userId: UUID(),
            name: "Roger",
            species: .dog,
            gender: .boy,
            expressions: useMockSprites ? debugTesterExpressions() : ExpressionMap(),
            personalityTraits: [.dramatic, .mischievous, .sweet],
            energyLevel: 7,
            biggestEnemy: .vacuumCleaner,
            baseMood: .mildlySuspicious,
            homeLat: nil,
            homeLng: nil,
            timezone: TimeZone.current.identifier,
            createdAt: Date()
        )
    }

    private func debugTesterExpressions() -> ExpressionMap {
        let bundled = ExpressionMap(
            happy: debugBundleSpriteURL(named: "tester_happy"),
            sleepy: debugBundleSpriteURL(named: "tester_sleepy"),
            mad: debugBundleSpriteURL(named: "tester_mad"),
            excited: debugBundleSpriteURL(named: "tester_excited"),
            missesYou: debugBundleSpriteURL(named: "tester_misses_you"),
            judging: debugBundleSpriteURL(named: "tester_judging")
        )
        let hasAllBundled = [
            bundled.happy, bundled.sleepy, bundled.mad,
            bundled.excited, bundled.missesYou, bundled.judging
        ].allSatisfy { $0 != nil }
        guard hasAllBundled else {
            return ExpressionMap(
                happy: "https://placehold.co/400x400/CDE6C8/2F5D46?text=happy",
                sleepy: "https://placehold.co/400x400/DCE9D7/2F5D46?text=sleepy",
                mad: "https://placehold.co/400x400/BBD8B3/2F5D46?text=mad",
                excited: "https://placehold.co/400x400/CDE6C8/2F5D46?text=excited",
                missesYou: "https://placehold.co/400x400/DCE9D7/2F5D46?text=misses+you",
                judging: "https://placehold.co/400x400/BBD8B3/2F5D46?text=judging"
            )
        }
        return bundled
    }

    private func debugBundleSpriteURL(named resourceName: String) -> String? {
        if let pngURL = Bundle.main.url(forResource: resourceName, withExtension: "png") {
            return pngURL.absoluteString
        }
        if let jpgURL = Bundle.main.url(forResource: resourceName, withExtension: "jpg") {
            return jpgURL.absoluteString
        }
        if let jpegURL = Bundle.main.url(forResource: resourceName, withExtension: "jpeg") {
            return jpegURL.absoluteString
        }
        if let webpURL = Bundle.main.url(forResource: resourceName, withExtension: "webp") {
            return webpURL.absoluteString
        }
        return nil
    }
#endif
}

private struct DebugRevealFlowView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var draft: OnboardingDraft
    let onSetPet: (Pet) -> Void
    let useMockSprites: Bool

    @State private var path: [Step] = []

    private enum Step: Hashable {
        case widgetSetup
    }

    var body: some View {
        NavigationStack(path: $path) {
            ExpressionRevealView(
                draft: draft,
                onComplete: { pet in
                    onSetPet(pet)
                    path.append(.widgetSetup)
                },
                skipGenerationForDebug: true,
                useMockSpritesForDebug: useMockSprites
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .pmOnboardingToolbar(total: 4, current: 2, balancedBackButton: false)
            .navigationBarBackButtonHidden(true)
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .widgetSetup:
                    WidgetSetupView {
                        if let pet = draft.completedPet {
                            onSetPet(pet)
                        }
                        appState.setHasCompletedOnboarding(true)
                    }
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .pmOnboardingToolbar(total: 4, current: 3, balancedBackButton: false)
                    .navigationBarBackButtonHidden(true)
                }
            }
        }
    }
}

enum PendingWidgetDeepLink: Equatable {
    case none
    case openChat
}

@MainActor
final class AppState: ObservableObject {
    @Published var currentPet: Pet?
    @Published var isLoading = false
    @Published var pendingWidgetDeepLink = PendingWidgetDeepLink.none

    // MARK: - User account cache (profiles + local prefs)

    @Published var settingsPersona: SettingsPersona = .pet
    @Published var hasCompletedSignUp: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var userDisplayName: String = ""
    @Published var userEmail: String = ""
    @Published var userPhone: String = ""

    @Published var visualStyle: AppVisualStyle = .classic

    private let supabase = SupabaseService.shared
    private var expressionSyncTask: Task<Void, Never>?

    /// While set, Stage B may still be writing expressions for this pet — used for Settings thumbnails.
    @Published private(set) var expressionSyncPetId: UUID?

    init() {
        loadUserSettingsFromUserDefaults()
        loadAppearanceFromUserDefaults()
    }

    private func loadAppearanceFromUserDefaults() {
        let d = UserDefaults.standard
        if d.object(forKey: MockUserSettings.Keys.darkMode) != nil {
            visualStyle = d.bool(forKey: MockUserSettings.Keys.darkMode) ? .widgetGlass : .classic
            return
        }
        if let raw = d.string(forKey: MockUserSettings.legacyVisualStyleKey),
           let style = AppVisualStyle(rawValue: raw) {
            visualStyle = style
            d.set(style == .widgetGlass, forKey: MockUserSettings.Keys.darkMode)
            d.removeObject(forKey: MockUserSettings.legacyVisualStyleKey)
            return
        }
        visualStyle = .classic
    }

    func setVisualStyle(_ value: AppVisualStyle) {
        visualStyle = value
        UserDefaults.standard.set(value == .widgetGlass, forKey: MockUserSettings.Keys.darkMode)
    }

    var isDarkModeEnabled: Bool {
        visualStyle == .widgetGlass
    }

    func setDarkModeEnabled(_ enabled: Bool) {
        setVisualStyle(enabled ? .widgetGlass : .classic)
    }

    private func loadUserSettingsFromUserDefaults() {
        let d = UserDefaults.standard
        if let raw = d.string(forKey: MockUserSettings.Keys.persona) {
            settingsPersona = SettingsPersona(storedRawValue: raw)
        } else {
            settingsPersona = .pet
        }
        hasCompletedSignUp = d.bool(forKey: MockUserSettings.Keys.signupCompleted)
        hasCompletedOnboarding = d.bool(forKey: MockUserSettings.Keys.onboardingCompleted)
        userDisplayName = d.string(forKey: MockUserSettings.Keys.displayName) ?? ""
        userEmail = d.string(forKey: MockUserSettings.Keys.email) ?? ""
        userPhone = d.string(forKey: MockUserSettings.Keys.phone) ?? ""
    }

    func setUserDisplayName(_ value: String) {
        userDisplayName = value
        UserDefaults.standard.set(value, forKey: MockUserSettings.Keys.displayName)
    }

    func setUserEmail(_ value: String) {
        userEmail = value
        UserDefaults.standard.set(value, forKey: MockUserSettings.Keys.email)
    }

    func setUserPhone(_ value: String) {
        userPhone = value
        UserDefaults.standard.set(value, forKey: MockUserSettings.Keys.phone)
    }

    func setSettingsPersona(_ value: SettingsPersona) {
        settingsPersona = value
        UserDefaults.standard.set(value.rawValue, forKey: MockUserSettings.Keys.persona)
    }

    func refreshProfileIfNeeded() async {
        if let profile = try? await supabase.fetchProfile() {
            applyProfileCache(profile)
        }
    }

    func setHasCompletedSignUp(_ value: Bool) {
        hasCompletedSignUp = value
        UserDefaults.standard.set(value, forKey: MockUserSettings.Keys.signupCompleted)
    }

    func setHasCompletedOnboarding(_ value: Bool) {
        hasCompletedOnboarding = value
        UserDefaults.standard.set(value, forKey: MockUserSettings.Keys.onboardingCompleted)
    }

    func bootstrap() async {
        if await supabase.restoreSessionIfPresent() {
            await restoreAuthenticatedSession()
        } else {
            await loadCurrentPet()
        }
    }

    /// After sign-in or session restore: fetch pet first (routes to home when present), then profile cache.
    func restoreAuthenticatedSession(showLoading: Bool = true) async {
        await loadCurrentPet(showLoading: showLoading)
        await hydrateFromProfile()
    }

    func hydrateFromProfile() async {
        if let profile = try? await supabase.fetchProfile() {
            applyProfileCache(profile)
            setHasCompletedSignUp(true)
            return
        }
        if let session = try? await supabase.client.auth.session,
           let email = session.user.email, !email.isEmpty {
            setUserEmail(email)
            setHasCompletedSignUp(true)
        }
    }

    private func applyProfileCache(_ profile: UserProfile) {
        setUserDisplayName(profile.fullName)
        setUserEmail(profile.email)
        if let phone = profile.phone {
            setUserPhone(phone)
        }
    }

    func completeSignUp(from draft: SignUpDraft) async {
        let name = draft.name.trimmingCharacters(in: .whitespaces)
        let email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        setUserDisplayName(name)
        setUserEmail(email)
        setUserPhone(draft.phoneDigitsOnly)
        setHasCompletedSignUp(true)
    }

    func loadCurrentPet(showLoading: Bool = true) async {
        if showLoading { isLoading = true }
        defer { if showLoading { isLoading = false } }
        do {
            currentPet = try await supabase.fetchCurrentPet()
            if currentPet != nil {
                setHasCompletedOnboarding(true)
            }
            syncHomeGeofenceFromCurrentPet()
        } catch {
            // No pet yet — show onboarding
        }
    }

    func updateCurrentPetHome(lat: Double, lng: Double) {
        guard var pet = currentPet else { return }
        pet.homeLat = lat
        pet.homeLng = lng
        currentPet = pet
    }

    func syncHomeGeofenceFromCurrentPet() {
        guard let pet = currentPet,
              let lat = pet.homeLat,
              let lng = pet.homeLng else { return }
        LocationService.shared.syncHomeGeofence(
            lat: lat,
            lng: lng,
            petId: pet.id,
            petName: pet.name
        )
    }

    func setPet(_ pet: Pet) {
        currentPet = pet
    }

    /// Pets the user can switch between (stub: single pet until multi-pet backend exists).
    var availablePets: [Pet] {
        [currentPet].compactMap { $0 }
    }

    func selectPet(_ pet: Pet) {
        currentPet = pet
    }

    func resetForOnboarding() async {
        stopSyncingExpressions()
        try? await SupabaseService.shared.client.auth.signOut()
        currentPet = nil
        setHasCompletedOnboarding(false)
    }

    /// Clears session, pet, and cached profile so the app returns to sign-in.
    func signOut() async {
        stopSyncingExpressions()
        try? await SupabaseService.shared.client.auth.signOut()
        currentPet = nil
        setHasCompletedOnboarding(false)
        setHasCompletedSignUp(false)
        setUserDisplayName("")
        setUserEmail("")
        setUserPhone("")
    }

    /// After kicking off `generate-sprites`, the edge function returns once
    /// the `happy` base sprite is ready and continues to fill in the other 5
    /// expressions in the background (writing each to `pets.expressions`).
    /// This polls the row and merges new expressions into `currentPet` as they
    /// arrive, so the UI updates without a manual refresh.
    func startSyncingExpressions(petId: UUID) {
        expressionSyncTask?.cancel()
        expressionSyncPetId = petId
        expressionSyncTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.expressionSyncPetId = nil }
            do {
                for try await partial in self.supabase.observePetExpressions(petId: petId) {
                    if Task.isCancelled { return }
                    if var pet = self.currentPet, pet.id == petId {
                        pet.expressions = partial
                        self.currentPet = pet
                    }
                }
            } catch {
                print("[AppState] expression sync ended with error: \(error)")
            }
        }
    }

    func stopSyncingExpressions() {
        expressionSyncTask?.cancel()
        expressionSyncTask = nil
        expressionSyncPetId = nil
    }
}
