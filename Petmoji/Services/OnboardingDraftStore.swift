import Foundation
import UIKit

// MARK: - Persisted snapshot

enum PersistedOnboardingContext: String, Codable {
    case firstPet
    case additionalPet
}

enum PersistedOnboardingTopStep: String, Codable {
    case photo
    case personality
    case spriteReveal
    case widgetSetup
}

struct PersistedOnboardingProgress: Codable {
    var context: PersistedOnboardingContext
    var topStep: PersistedOnboardingTopStep
    var personalityActiveStep: Int
    var personalityIsReview: Bool
    var species: Species
    var gender: PetGender
    var selectedTraits: [PersonalityTrait]
    var energyLevel: Double
    var selectedTriggers: [PetTrigger]
    var customTrigger: String
    var baseMood: BaseMood
    var photoFileNames: [String]
    var pendingPetId: UUID?
    var petName: String
    var savedAt: Date
}

// MARK: - Store

enum OnboardingDraftStore {
    private static let progressKey = "onboarding_draft_v1"
    private static let draftDirectoryName = "OnboardingDraft"

    static var hasPendingAdditionalPetDraft: Bool {
        guard let progress = load() else { return false }
        return progress.context == .additionalPet
    }

    static var hasPendingFirstPetDraft: Bool {
        guard let progress = load() else { return false }
        return progress.context == .firstPet
    }

    static var pendingPetId: UUID? {
        load()?.pendingPetId
    }

    static func load() -> PersistedOnboardingProgress? {
        guard let data = UserDefaults.standard.data(forKey: progressKey) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(PersistedOnboardingProgress.self, from: data)
        } catch {
            clear()
            return nil
        }
    }

    @MainActor
    static func save(
        draft: OnboardingDraft,
        context: PersistedOnboardingContext,
        topStep: PersistedOnboardingTopStep,
        personalityActiveStep: Int,
        personalityIsReview: Bool,
        petName: String = ""
    ) {
        let photoFileNames = savePhotos(draft.photoData)
        let progress = PersistedOnboardingProgress(
            context: context,
            topStep: topStep,
            personalityActiveStep: personalityActiveStep,
            personalityIsReview: personalityIsReview,
            species: draft.species,
            gender: draft.gender,
            selectedTraits: Array(draft.selectedTraits),
            energyLevel: draft.energyLevel,
            selectedTriggers: Array(draft.selectedTriggers),
            customTrigger: draft.customTrigger,
            baseMood: draft.baseMood,
            photoFileNames: photoFileNames,
            pendingPetId: draft.completedPet?.id,
            petName: petName,
            savedAt: Date()
        )

        do {
            let data = try JSONEncoder().encode(progress)
            UserDefaults.standard.set(data, forKey: progressKey)
        } catch {
            assertionFailure("Failed to save onboarding draft: \(error)")
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: progressKey)
        try? FileManager.default.removeItem(at: draftDirectoryURL)
    }

    @MainActor
    static func apply(_ progress: PersistedOnboardingProgress, to draft: OnboardingDraft) {
        draft.species = progress.species
        draft.gender = progress.gender
        draft.selectedTraits = Set(progress.selectedTraits)
        draft.energyLevel = progress.energyLevel
        draft.selectedTriggers = Set(progress.selectedTriggers)
        draft.customTrigger = progress.customTrigger
        draft.baseMood = progress.baseMood

        let loadedData = loadPhotos(fileNames: progress.photoFileNames)
        draft.photoData = loadedData
        draft.photos = loadedData.compactMap { UIImage(data: $0) }
    }

    static func navigationPath(for topStep: PersistedOnboardingTopStep) -> [OnboardingCoordinator.OnboardingStep] {
        switch topStep {
        case .photo:
            return []
        case .personality:
            return [.personality]
        case .spriteReveal:
            return [.personality, .spriteReveal]
        case .widgetSetup:
            return [.personality, .spriteReveal, .widgetSetup]
        }
    }

    // MARK: - Photo files

    private static var draftDirectoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(draftDirectoryName, isDirectory: true)
    }

    private static func savePhotos(_ photoData: [Data]) -> [String] {
        guard !photoData.isEmpty else { return [] }

        let directory = draftDirectoryURL
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if let existing = try? FileManager.default.contentsOfDirectory(atPath: directory.path) {
            for file in existing where file.hasPrefix("photo_") {
                try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
            }
        }

        var fileNames: [String] = []
        for (index, data) in photoData.enumerated() {
            let compressed = compressPhotoData(data)
            let fileName = "photo_\(index).jpg"
            let fileURL = directory.appendingPathComponent(fileName)
            do {
                try compressed.write(to: fileURL, options: .atomic)
                fileNames.append(fileName)
            } catch {
                assertionFailure("Failed to write onboarding photo \(fileName): \(error)")
            }
        }
        return fileNames
    }

    private static func loadPhotos(fileNames: [String]) -> [Data] {
        guard !fileNames.isEmpty else { return [] }
        let directory = draftDirectoryURL
        return fileNames.compactMap { name in
            try? Data(contentsOf: directory.appendingPathComponent(name))
        }
    }

    private static func compressPhotoData(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let maxEdge: CGFloat = 1200
        let size = image.size
        let scale = min(1, maxEdge / max(size.width, size.height))
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.75) ?? data
    }
}
