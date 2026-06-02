import BackgroundTasks
import Foundation

// MARK: - Schedules AI "been gone" follow-ups (2h / 6h after leaving home)

enum BeenGoneBackgroundScheduler {
    static let taskId2h = "com.petmoji.been-gone-2h"
    static let taskId6h = "com.petmoji.been-gone-6h"

    private nonisolated(unsafe) static let sharedDefaults = UserDefaults(suiteName: "group.com.petmoji.app")

    static func registerHandlers() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId2h, using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            runBeenGoneTask(refresh, event: "been_gone_2h")
        }

        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId6h, using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            runBeenGoneTask(refresh, event: "been_gone_6h")
        }
    }

    static func scheduleFollowUps() {
        cancelFollowUps()
        submitRefreshTask(identifier: taskId2h, delay: 2 * 60 * 60)
        submitRefreshTask(identifier: taskId6h, delay: 6 * 60 * 60)
    }

    static func cancelFollowUps() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskId2h)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskId6h)
    }

    private static func submitRefreshTask(identifier: String, delay: TimeInterval) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: delay)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[BeenGoneBackgroundScheduler] failed to schedule \(identifier): \(error)")
        }
    }

    private static func runBeenGoneTask(_ task: BGAppRefreshTask, event: String) {
        let completion = BeenGoneTaskCompletion(task)

        task.expirationHandler = {
            completion.finish(success: false)
        }

        Task {
            let success = await generateAndDeliverBeenGoneMessage(event: event)
            completion.finish(success: success)
        }
    }

    private static func generateAndDeliverBeenGoneMessage(event: String) async -> Bool {
        guard let petId = storedPetId() else { return false }
        do {
            let message = try await SupabaseService.shared.reportLocationEvent(petId: petId, event: event)
            guard let pet = try await SupabaseService.shared.fetchPet(by: petId) else { return false }
            await MainActor.run {
                PetMessageDelivery.deliver(pet: pet, message: message)
            }
            return true
        } catch {
            print("[BeenGoneBackgroundScheduler] \(event) failed: \(error)")
            return false
        }
    }

    private static func storedPetId() -> UUID? {
        guard let raw = sharedDefaults?.string(forKey: "pet_id") else { return nil }
        return UUID(uuidString: raw)
    }
}

private final class BeenGoneTaskCompletion: @unchecked Sendable {
    private let task: BGAppRefreshTask
    private var didFinish = false
    private let lock = NSLock()

    init(_ task: BGAppRefreshTask) {
        self.task = task
    }

    func finish(success: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard !didFinish else { return }
        didFinish = true
        task.setTaskCompleted(success: success)
    }
}
