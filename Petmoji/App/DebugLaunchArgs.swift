#if DEBUG
import Foundation

enum DebugLaunchArgs {
    private static let prefix = "-testPetMessage:"

    /// Parses all `-testPetMessage:left_home` style args (or legacy `-testPetMessage`).
    static var testPetMessageEvents: [String] {
        let args = ProcessInfo.processInfo.arguments
        let prefixed = args
            .filter { $0.hasPrefix(prefix) }
            .map { arg -> String in
                let event = String(arg.dropFirst(prefix.count))
                return event.isEmpty ? "been_gone_2h" : event
            }

        if !prefixed.isEmpty { return prefixed }

        guard args.contains("-testPetMessage") else { return [] }

        if let index = args.firstIndex(of: "-testPetMessage"), index + 1 < args.count {
            let next = args[index + 1]
            if !next.hasPrefix("-") { return [next] }
        }

        return ["been_gone_2h"]
    }

    static var testPetMessageEvent: String? {
        testPetMessageEvents.first
    }
}
#endif
