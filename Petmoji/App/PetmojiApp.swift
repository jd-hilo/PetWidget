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
                        let petId = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                            .queryItems?
                            .first(where: { $0.name == "petId" })?
                            .value
                            .flatMap(UUID.init(uuidString:))
                        appState.pendingWidgetDeepLink = .openChat(petId: petId)
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
        let defaults = UserDefaults.standard
        let widgetPetId: UUID? = {
            guard let raw = defaults.string(forKey: MockUserSettings.Keys.widgetPetId) else { return nil }
            return UUID(uuidString: raw)
        }()

        let pets = (try? await SupabaseService.shared.fetchAllPets()) ?? []
        let widgetPet = widgetPetId.flatMap { id in pets.first { $0.id == id } } ?? pets.first

        guard let pet = widgetPet,
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
            } else if appState.isBootstrapping || appState.isLoading {
                BrandLandingView(mode: .loading)
            } else if !appState.isAuthenticated && !shouldSkipSignUp {
                if !appState.hasSeenWelcome {
                    BrandLandingView(mode: .welcome) {
                        appState.setHasSeenWelcome(true)
                    }
                } else {
                    AuthCoordinator()
                }
            } else if appState.isAuthenticated, !appState.pets.isEmpty, appState.hasCompletedOnboarding {
                NavigationStack {
                    PetHomeView()
                }
            } else if appState.isAuthenticated {
                OnboardingCoordinator()
            } else {
                AuthCoordinator()
            }
        }
        .environment(\.petmojiPalette, PetmojiPalette.palette(for: appState.visualStyle))
        .preferredColorScheme(appState.visualStyle == .widgetGlass ? .dark : .light)
        .task {
            if !shouldSkipOnboardingToReveal && !shouldSkipOnboardingToWidgetSetup {
                await appState.bootstrap()
            } else {
                appState.markBootstrapComplete()
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
            triggers: [.vacuumCleaner],
            customTrigger: nil,
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
    case openChat(petId: UUID?)
}

@MainActor
final class AppState: ObservableObject {
    static let maxPets = 2

    @Published var currentPet: Pet?
    @Published private(set) var pets: [Pet] = []
    @Published var widgetPetId: UUID?
    @Published var isLoading = false
    @Published private(set) var isBootstrapping = true
    @Published private(set) var isAuthenticated = false
    @Published var pendingWidgetDeepLink = PendingWidgetDeepLink.none

    // MARK: - User account cache (profiles + local prefs)

    @Published var settingsPersona: SettingsPersona = .pet
    @Published var hasCompletedSignUp: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var hasSeenWelcome: Bool = false
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
        hasSeenWelcome = d.bool(forKey: MockUserSettings.Keys.hasSeenWelcome)
        userDisplayName = d.string(forKey: MockUserSettings.Keys.displayName) ?? ""
        userEmail = d.string(forKey: MockUserSettings.Keys.email) ?? ""
        userPhone = d.string(forKey: MockUserSettings.Keys.phone) ?? ""
        if let raw = d.string(forKey: MockUserSettings.Keys.widgetPetId) {
            widgetPetId = UUID(uuidString: raw)
        }
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

    func setHasSeenWelcome(_ value: Bool) {
        hasSeenWelcome = value
        UserDefaults.standard.set(value, forKey: MockUserSettings.Keys.hasSeenWelcome)
    }

    func markBootstrapComplete() {
        isBootstrapping = false
    }

    func bootstrap() async {
        defer { isBootstrapping = false }
        if await supabase.restoreSessionIfPresent() {
            isAuthenticated = true
            await restoreAuthenticatedSession()
        } else {
            applyUnauthenticatedState()
        }
    }

    /// Clears in-memory app data when there is no Supabase session (stale UserDefaults must not unlock the app).
    func applyUnauthenticatedState() {
        isAuthenticated = false
        stopSyncingExpressions()
        currentPet = nil
        pets = []
        setWidgetPetId(nil)
        setHasCompletedSignUp(false)
    }

    /// After sign-in or session restore: fetch pets first (routes to home when present), then profile cache.
    func restoreAuthenticatedSession(showLoading: Bool = true) async {
        isAuthenticated = true
        await loadPets(showLoading: showLoading)
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
        isAuthenticated = true
        let name = draft.name.trimmingCharacters(in: .whitespaces)
        let email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        setUserDisplayName(name)
        setUserEmail(email)
        setUserPhone(draft.phoneDigitsOnly)
        setHasCompletedSignUp(true)
    }

    func loadPets(showLoading: Bool = true) async {
        if showLoading { isLoading = true }
        defer { if showLoading { isLoading = false } }
        do {
            let previousCurrentId = currentPet?.id
            let fetched = try await supabase.fetchAllPets(limit: Self.maxPets)
            pets = fetched
            if let previousCurrentId,
               let kept = fetched.first(where: { $0.id == previousCurrentId }) {
                currentPet = kept
            } else {
                currentPet = fetched.first
            }
            resolveWidgetPetId()
            if !fetched.isEmpty {
                setHasCompletedOnboarding(true)
            }
            syncHomeGeofenceFromCurrentPet()
            await syncWidgetSnapshot()
        } catch {
            // No pets yet — show onboarding
        }
    }

    private func resolveWidgetPetId() {
        if let widgetPetId,
           pets.contains(where: { $0.id == widgetPetId }) {
            return
        }
        if let firstPet = pets.first {
            setWidgetPetId(firstPet.id)
        } else {
            setWidgetPetId(nil)
        }
    }

    private func setWidgetPetId(_ id: UUID?) {
        widgetPetId = id
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: MockUserSettings.Keys.widgetPetId)
        } else {
            UserDefaults.standard.removeObject(forKey: MockUserSettings.Keys.widgetPetId)
        }
    }

    var widgetPet: Pet? {
        guard let widgetPetId else { return pets.first }
        return pets.first { $0.id == widgetPetId } ?? pets.first
    }

    var canAddPet: Bool { pets.count < Self.maxPets }

    var availablePets: [Pet] { pets }

    func setWidgetPet(_ pet: Pet) {
        setWidgetPetId(pet.id)
        Task { await syncWidgetSnapshot() }
    }

    func syncWidgetSnapshot() async {
        guard let pet = widgetPet else { return }
        if let message = try? await supabase.fetchLatestMessage(for: pet.id) {
            WidgetSnapshotSync.writeFromPet(pet, message: message)
        }
    }

    func registerNewPet(_ pet: Pet) {
        var next = pets.filter { $0.id != pet.id }
        next.append(pet)
        next.sort { $0.createdAt < $1.createdAt }
        pets = Array(next.prefix(Self.maxPets))
        mergePet(pet)
        startSyncingExpressions(petId: pet.id)
    }

    private func mergePet(_ pet: Pet) {
        if var current = currentPet, current.id == pet.id {
            current = pet
            currentPet = current
        }
        if let index = pets.firstIndex(where: { $0.id == pet.id }) {
            pets[index] = pet
        }
    }

    func updateCurrentPetHome(lat: Double, lng: Double) {
        guard let petId = currentPet?.id else { return }
        updatePetHome(petId: petId, lat: lat, lng: lng)
    }

    func updatePetHome(petId: UUID, lat: Double, lng: Double) {
        guard var pet = pets.first(where: { $0.id == petId }) else { return }
        pet.homeLat = lat
        pet.homeLng = lng
        mergePet(pet)
        if currentPet?.id == petId {
            syncHomeGeofenceFromCurrentPet()
        }
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
        if let index = pets.firstIndex(where: { $0.id == pet.id }) {
            pets[index] = pet
        } else if pets.count < Self.maxPets {
            pets.append(pet)
            pets.sort { $0.createdAt < $1.createdAt }
        }
    }

    func removePetLocally(petId: UUID) {
        pets.removeAll { $0.id == petId }
        if currentPet?.id == petId {
            currentPet = pets.first
        }
        resolveWidgetPetId()
    }

    func deletePet(_ pet: Pet) async {
        if expressionSyncPetId == pet.id {
            stopSyncingExpressions()
        }
        try? await supabase.deletePet(petId: pet.id)
        ChatHistoryStore.clearHistory(for: pet.id)
        removePetLocally(petId: pet.id)
        await syncWidgetSnapshot()
    }

    func selectPet(_ pet: Pet) {
        currentPet = pet
    }

    func resetForOnboarding() async {
        stopSyncingExpressions()
        try? await SupabaseService.shared.client.auth.signOut()
        applyUnauthenticatedState()
        setHasCompletedOnboarding(false)
    }

    /// Clears session, pet, and cached profile so the app returns to sign-in.
    func signOut() async {
        stopSyncingExpressions()
        try? await SupabaseService.shared.client.auth.signOut()
        applyUnauthenticatedState()
        setHasCompletedOnboarding(false)
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
                    if var pet = self.pets.first(where: { $0.id == petId }) {
                        pet.expressions = partial
                        self.mergePet(pet)
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
