import Foundation
import StoreKit

/// Registers a SKAdNetwork install conversion so ad networks (Reddit/Meta) can receive Apple postbacks.
/// Petmoji is the advertised app — no SKAdNetworkItems plist list is required for that role.
enum SKAdNetworkService {
    private static let didRegisterKey = "skadnetwork.didRegisterInstallConversion"

    /// Call once early after launch. Non-blocking; retries on later launches if the update fails.
    static func registerInstallConversionIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didRegisterKey) else { return }

        // fine 0 + coarse low: v1 install signal for SKAN 4 postbacks
        SKAdNetwork.updatePostbackConversionValue(0, coarseValue: .low) { error in
            if let error {
                print("[SKAdNetwork] updatePostbackConversionValue failed: \(error.localizedDescription)")
                return
            }
            defaults.set(true, forKey: didRegisterKey)
        }
    }
}
