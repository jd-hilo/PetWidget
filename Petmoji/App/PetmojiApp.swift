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
                .preferredColorScheme(.light)
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
            || MockUserSettings.isDebugSpritesUserDefaultEnabled
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

    var body: some View {
        Group {
            if shouldSkipOnboardingToWidgetSetup && appState.currentPet == nil {
                NavigationStack {
                    WidgetSetupView {
#if DEBUG
                        appState.setPet(makeDebugRogerPet(useMockSprites: shouldUseMockSprites))
#endif
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
            } else if appState.currentPet != nil {
                NavigationStack {
                    PetHomeView()
                }
            } else {
                OnboardingCoordinator()
            }
        }
        .task {
            if !shouldSkipOnboardingToReveal && !shouldSkipOnboardingToWidgetSetup {
                await appState.loadCurrentPet()
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

    // MARK: - Mock user / developer preview (DEBUG Settings UI)

    @Published var settingsPersona: SettingsPersona = .pet
    @Published var mockUserDisplayName: String = ""
    @Published var mockUserEmail: String = ""
    @Published var mockUserVerboseLogs: Bool = false
    @Published var mockUserDebugSprites: Bool = false

    private let supabase = SupabaseService.shared
    private var expressionSyncTask: Task<Void, Never>?

    init() {
        loadMockUserSettingsFromUserDefaults()
    }

    private func loadMockUserSettingsFromUserDefaults() {
        let d = UserDefaults.standard
        if let raw = d.string(forKey: MockUserSettings.Keys.persona),
           let p = SettingsPersona(rawValue: raw) {
            settingsPersona = p
        } else {
            settingsPersona = .pet
        }
        mockUserDisplayName = d.string(forKey: MockUserSettings.Keys.displayName) ?? ""
        mockUserEmail = d.string(forKey: MockUserSettings.Keys.email) ?? ""
        mockUserVerboseLogs = d.bool(forKey: MockUserSettings.Keys.verboseLogs)
        mockUserDebugSprites = d.bool(forKey: MockUserSettings.Keys.debugSprites)
    }

    func setSettingsPersona(_ value: SettingsPersona) {
        settingsPersona = value
        UserDefaults.standard.set(value.rawValue, forKey: MockUserSettings.Keys.persona)
    }

    func setMockUserDisplayName(_ value: String) {
        mockUserDisplayName = value
        UserDefaults.standard.set(value, forKey: MockUserSettings.Keys.displayName)
    }

    func setMockUserEmail(_ value: String) {
        mockUserEmail = value
        UserDefaults.standard.set(value, forKey: MockUserSettings.Keys.email)
    }

    func setMockUserVerboseLogs(_ value: Bool) {
        mockUserVerboseLogs = value
        UserDefaults.standard.set(value, forKey: MockUserSettings.Keys.verboseLogs)
    }

    func setMockUserDebugSprites(_ value: Bool) {
        mockUserDebugSprites = value
        UserDefaults.standard.set(value, forKey: MockUserSettings.Keys.debugSprites)
    }

    func loadCurrentPet() async {
        isLoading = true
        defer { isLoading = false }
        do {
            currentPet = try await supabase.fetchCurrentPet()
        } catch {
            // No pet yet — show onboarding
        }
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
    }

    /// After kicking off `generate-sprites`, the edge function returns once
    /// the `happy` base sprite is ready and continues to fill in the other 5
    /// expressions in the background (writing each to `pets.expressions`).
    /// This polls the row and merges new expressions into `currentPet` as they
    /// arrive, so the UI updates without a manual refresh.
    func startSyncingExpressions(petId: UUID) {
        expressionSyncTask?.cancel()
        expressionSyncTask = Task { [weak self] in
            guard let self else { return }
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
    }
}
