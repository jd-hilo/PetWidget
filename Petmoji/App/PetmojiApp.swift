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

        let sharedDefaults = UserDefaults(suiteName: "group.com.petmoji.app")
        sharedDefaults?.set(pet.name, forKey: "pet_name")
        sharedDefaults?.set(message.content, forKey: "widget_message")
        sharedDefaults?.set(message.expression.rawValue, forKey: "widget_expression")
        sharedDefaults?.set(pet.expressions[message.expression], forKey: "widget_sprite_url")

        WidgetReloader.reload()
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.currentPet != nil {
                NavigationStack {
                    PetHomeView()
                }
            } else {
                OnboardingCoordinator()
            }
        }
        .task {
            await appState.loadCurrentPet()
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var currentPet: Pet?
    @Published var isLoading = false

    private let supabase = SupabaseService.shared

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

    func resetForOnboarding() async {
        try? await SupabaseService.shared.client.auth.signOut()
        currentPet = nil
    }
}
