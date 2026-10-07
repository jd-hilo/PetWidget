import AppTrackingTransparency
import Foundation
@preconcurrency import Singular
import UIKit

// MARK: - Config

/// Credentials come from Xcode Build Settings → Info.plist (`SINGULAR_SDK_KEY` /
/// `SINGULAR_SDK_SECRET`), with env-var overrides for local runs.
///
/// Paste the SDK secret (Singular dashboard → Developer Tools → SDK Integration)
/// into the Petmoji target Build Settings user-defined setting `SINGULAR_SDK_SECRET`
/// for **Debug** and **Release**. Do not commit the secret.
enum SingularCredentials {
    /// Public Singular SDK key for this app. Still overridable via build setting / env.
    static let defaultSDKKey = "hilo_2df29d75"

    static var sdkKey: String {
        resolvedValue(named: "SINGULAR_SDK_KEY", fallback: defaultSDKKey)
    }

    static var sdkSecret: String {
        resolvedValue(named: "SINGULAR_SDK_SECRET", fallback: "")
    }

    private static func resolvedValue(named key: String, fallback: String) -> String {
        if let env = ProcessInfo.processInfo.environment[key], !env.isEmpty {
            return env
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !plist.isEmpty,
           !plist.hasPrefix("$(") {
            return plist
        }
        return fallback
    }
}

// MARK: - Service

@MainActor
enum SingularService {
    /// Matches Singular's recommended ATT wait so the first session can include IDFA.
    static let trackingAuthorizationTimeoutSeconds: Int = 300

    private static var didStart = false

    static func configure(launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
        start(
            launchOptions: launchOptions,
            openURL: launchOptions?[.url] as? URL,
            userActivity: userActivity(from: launchOptions)
        )
    }

    static func handleOpenURL(_ url: URL) {
        start(openURL: url)
    }

    static func handleUserActivity(_ userActivity: NSUserActivity) {
        start(userActivity: userActivity)
    }

    static func setCustomUserId(_ userId: UUID) {
        guard didStart else { return }
        Singular.setCustomUserId(userId.uuidString)
    }

    static func unsetCustomUserId() {
        guard didStart else { return }
        Singular.unsetCustomUserId()
    }

    /// Shows the system ATT prompt once the first real screen is on screen.
    /// No-ops if the user already answered, or if the Info.plist usage string is missing.
    static func requestTrackingAuthorizationIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            #if DEBUG
            print(
                "[Singular] ATT already determined:",
                Self.debugDescription(for: ATTrackingManager.trackingAuthorizationStatus)
            )
            #endif
            return
        }

        let status = await ATTrackingManager.requestTrackingAuthorization()
        #if DEBUG
        print("[Singular] ATT response:", debugDescription(for: status))
        #endif
    }

    private static func start(
        launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil,
        openURL: URL? = nil,
        userActivity: NSUserActivity? = nil
    ) {
        guard let config = makeConfig() else { return }
        config.launchOptions = launchOptions
        if let userActivity {
            config.userActivity = userActivity
        }
        if let openURL {
            config.openUrl = openURL
        }

        #if DEBUG
        if !didStart, let idfv = UIDevice.current.identifierForVendor?.uuidString {
            print("[Singular] IDFV (paste into Testing Console):", idfv)
        }
        #endif

        _ = Singular.start(config)
        didStart = true
    }

    private static func makeConfig() -> SingularConfig? {
        let key = SingularCredentials.sdkKey
        let secret = SingularCredentials.sdkSecret
        guard !key.isEmpty, !secret.isEmpty else {
            print(
                "[Singular] Missing SINGULAR_SDK_SECRET — attribution disabled. Paste the secret from Singular → Developer Tools → SDK Integration into the Petmoji target Build Setting SINGULAR_SDK_SECRET (Debug and Release)."
            )
            return nil
        }

        guard let config = SingularConfig(apiKey: key, andSecret: secret) else {
            print("[Singular] Failed to create SingularConfig")
            return nil
        }

        // Managed SKAN: Singular updates conversion values from the dashboard model.
        config.skAdNetworkEnabled = true
        config.manualSkanConversionManagement = false
        config.waitForTrackingAuthorizationWithTimeoutInterval = trackingAuthorizationTimeoutSeconds

        config.sdidReceivedHandler = { sdid in
            #if DEBUG
            print("[Singular] SDID received:", String(describing: sdid))
            #endif
        }

        #if DEBUG
        config.enableLogging = true
        #endif

        return config
    }

    private static func userActivity(
        from launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> NSUserActivity? {
        let dictionary = launchOptions?[.userActivityDictionary] as? [AnyHashable: Any]
        return dictionary?["UIApplicationLaunchOptionsUserActivityKey"] as? NSUserActivity
    }

    private static func debugDescription(for status: ATTrackingManager.AuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorized: return "authorized"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }
}
