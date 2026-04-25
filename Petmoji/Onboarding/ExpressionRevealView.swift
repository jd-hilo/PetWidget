import SwiftUI

// MARK: - Expression Reveal View (Sprite Preview + Name)

struct ExpressionRevealView: View {
    @ObservedObject var draft: OnboardingDraft
    let onComplete: (Pet) -> Void
    var skipGenerationForDebug: Bool = false
    var useMockSpritesForDebug: Bool = false

    @State private var generationState: GenerationState = .loading
    @State private var uploadedPhotoURLs: [String] = []
    @State private var expressions: ExpressionMap = ExpressionMap()
    @State private var selectedExpression: PetExpression = .happy
    @State private var name: String = ""
    @State private var spriteOffset: CGFloat = -120
    @State private var spriteVisible = false
    @State private var thumbnailsVisible = [Bool](repeating: false, count: 6)
    @State private var createdPetId: UUID?
    @State private var nameDebounceTask: Task<Void, Never>?
    @FocusState private var isNameFieldFocused: Bool

    enum GenerationState {
        case loading, uploading, generating, done, error(String)
    }

    var isGenerating: Bool {
        switch generationState {
        case .loading, .uploading, .generating: return true
        default: return false
        }
    }

    var body: some View {
        ZStack {
            PMSageScreenBackdrop()

            VStack(spacing: 24) {
                switch generationState {
                case .loading, .uploading, .generating:
                    GenerationProgressView(state: generationState)

                case .done:
                    spriteRevealContent

                case .error(let msg):
                    errorView(msg)
                }
            }
        }
        .navigationBarBackButtonHidden(isGenerating)
        .task {
            if skipGenerationForDebug {
                if useMockSpritesForDebug {
#if DEBUG
                    expressions = Self.debugTesterExpressions()
#endif
                    selectedExpression = .happy
                }
                generationState = .done
            } else {
                await startGeneration()
            }
        }
        .onChange(of: name) { _, newName in
            guard let petId = createdPetId else { return }
            nameDebounceTask?.cancel()
            nameDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                try? await SupabaseService.shared.updatePetName(petId: petId, name: newName)
            }
        }
    }

    // MARK: - Sprite Reveal UI

    @ViewBuilder
    private var spriteRevealContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("say hi to...")
                    .font(.titleL)
                    .foregroundStyle(Color.pmSageTextSecondary)

                // Hero sprite
                SpriteImageView(urlString: expressions[selectedExpression])
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(
                        color: Color.pmSageAccent.opacity(0.35),
                        radius: 18,
                        x: 0,
                        y: 0
                    )
                    .offset(y: spriteVisible ? 0 : spriteOffset)
                    .opacity(spriteVisible ? 1 : 0)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.65).delay(0.2),
                        value: spriteVisible
                    )
                    .onAppear { spriteVisible = true }

                // Expression thumbnails
                GeometryReader { geo in
                    let spacing: CGFloat = 10
                    let thumbSize = min(56, (geo.size.width - (spacing * 5)) / 6)

                    HStack(spacing: spacing) {
                        ForEach(Array(PetExpression.allCases.enumerated()), id: \.element) { i, expression in
                            ExpressionThumbnail(
                                expression: expression,
                                urlString: expressions[expression],
                                isSelected: selectedExpression == expression,
                                size: thumbSize
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedExpression = expression
                                }
                            }
                            .scaleEffect(thumbnailsVisible[i] ? 1 : 0.5)
                            .opacity(thumbnailsVisible[i] ? 1 : 0)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.7)
                                .delay(0.6 + Double(i) * 0.15),
                                value: thumbnailsVisible[i]
                            )
                            .onAppear {
                                thumbnailsVisible[i] = true
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(height: 56)

                // Name input
                VStack(spacing: 16) {
                    Text("what's their name?")
                        .font(.titleL)
                        .foregroundStyle(Color.pmSageAccentDark)

                    TextField("enter name...", text: $name)
                        .font(.displayXL)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.pmSageTextPrimary)
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                        .tint(.blue)
                        .onSubmit {
                            isNameFieldFocused = false
                        }
                        .padding(16)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.pmSageBorder, lineWidth: 1.5)
                        )
                }
                .padding(.bottom, 24)
            }
            .padding(.top, 112)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(
            TapGesture().onEnded {
                isNameFieldFocused = false
            }
        )
        .safeAreaInset(edge: .bottom) {
            PMSageCTAButton(
                title: name.isEmpty ? "enter a name first" : "meet \(name)! →",
                action: savePet,
                isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 75)
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.pmSageTextSecondary)
            Text("something went wrong")
                .font(.titleL)
                .foregroundStyle(Color.pmSageAccentDark)
            Text(msg)
                .font(.bodyM)
                .foregroundStyle(Color.pmSageTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            PMSageCTAButton(title: "try again", action: {
                Task { await startGeneration() }
            })
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Generation Logic

    private func startGeneration() async {
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = false }

        do {
            // 1. Sign in anonymously if needed
            let userId = try await SupabaseService.shared.signInAnonymously()

            // 2. Create initial pet record
            generationState = .uploading
            let pet = try await createInitialPet(userId: userId)

            // Store pet immediately so name saves work during generation
            await MainActor.run {
                draft.completedPet = pet
                createdPetId = pet.id
            }

            // 3. Upload photos
            var photoURLs: [String] = []
            for (i, photoData) in draft.photoData.enumerated() {
                let url = try await SupabaseService.shared.uploadPetPhoto(
                    petId: pet.id, imageData: photoData, index: i
                )
                photoURLs.append(url)
            }
            uploadedPhotoURLs = photoURLs

            // 4. Generate sprites
            generationState = .generating
            let generatedExpressions = try await SupabaseService.shared.generateSprites(
                petId: pet.id,
                photoURLs: photoURLs,
                species: draft.species,
                gender: draft.gender
            )

            // Verify all 6 expressions came back — fail loudly if none, warn if partial
            let generatedCount = [
                generatedExpressions.happy, generatedExpressions.sleepy,
                generatedExpressions.mad, generatedExpressions.excited,
                generatedExpressions.missesYou, generatedExpressions.judging
            ].compactMap { $0 }.count

            if generatedCount == 0 {
                throw NSError(domain: "Petmoji", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "No expressions were generated. Please try again."])
            }

            expressions = generatedExpressions
            draft.generatedExpressions = generatedExpressions
            generationState = .done
        } catch {
            generationState = .error(error.localizedDescription)
        }
    }

    private func createInitialPet(userId: UUID) async throws -> Pet {
        let pet = Pet(
            id: UUID(),
            userId: userId,
            name: "unnamed",
            species: draft.species,
            gender: draft.gender,
            expressions: ExpressionMap(),
            personalityTraits: Array(draft.selectedTraits),
            energyLevel: Int(draft.energyLevel),
            biggestEnemy: draft.biggestEnemy,
            baseMood: draft.baseMood,
            homeLat: nil,
            homeLng: nil,
            timezone: TimeZone.current.identifier,
            createdAt: Date()
        )
        return try await SupabaseService.shared.savePet(pet)
    }

    private func savePet() {
        var pet = draft.completedPet ?? makeLocalDebugPet()
        let finalName = name.trimmingCharacters(in: .whitespaces)
        pet.name = finalName
        pet.expressions = expressions

        if skipGenerationForDebug {
            draft.completedPet = pet
            onComplete(pet)
            return
        }

        Task {
            let saved = try await SupabaseService.shared.savePet(pet)
            MessageScheduler.shared.savePetMetadata(name: saved.name, petId: saved.id.uuidString)
            onComplete(saved)
        }
    }

    private func makeLocalDebugPet() -> Pet {
        Pet(
            id: UUID(),
            userId: UUID(),
            name: "unnamed",
            species: draft.species,
            gender: draft.gender,
            expressions: expressions,
            personalityTraits: Array(draft.selectedTraits),
            energyLevel: Int(draft.energyLevel),
            biggestEnemy: draft.biggestEnemy,
            baseMood: draft.baseMood,
            homeLat: nil,
            homeLng: nil,
            timezone: TimeZone.current.identifier,
            createdAt: Date()
        )
    }

#if DEBUG
    /// Uses bundled tester sprites first (if present), otherwise falls back to remote placeholders.
    private static func debugTesterExpressions() -> ExpressionMap {
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

    private static func debugBundleSpriteURL(named resourceName: String) -> String? {
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

// MARK: - Generation Progress

struct GenerationProgressView: View {
    let state: ExpressionRevealView.GenerationState

    var message: String {
        switch state {
        case .loading: return "getting ready..."
        case .uploading: return "uploading photos..."
        case .generating: return "generating sprites..."
        default: return ""
        }
    }

    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 32) {
            Text("✨")
                .font(.system(size: 64))
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            Text(message)
                .font(.titleL)
                .foregroundStyle(Color.pmSageAccentDark)

            Text("this takes about 30 seconds")
                .font(.bodyM)
                .foregroundStyle(Color.pmSageTextSecondary)

            // Shimmer placeholder cards
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.pmSageSurface)
                        .frame(width: 48, height: 48)
                        .shimmer()
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Sprite Image View

struct SpriteImageView: View {
    let urlString: String?
    var cornerRadius: CGFloat = 20
    var contentMode: ContentMode = .fit

    var body: some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                case .failure:
                    retryPlaceholder
                case .empty:
                    ProgressView()
                @unknown default:
                    placeholderSprite
                }
            }
        } else {
            placeholderSprite
        }
    }

    private var retryPlaceholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.pmSageCardNeutral)
            .overlay {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.pmSageTextSecondary)
            }
    }

    private var placeholderSprite: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.pmSageSurface)
            .overlay {
                Text("🐾")
                    .font(.system(size: 64))
            }
    }
}

// MARK: - Expression Thumbnail

struct ExpressionThumbnail: View {
    let expression: PetExpression
    let urlString: String?
    let isSelected: Bool
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.pmSageSurface : Color.pmSageSurface.opacity(0.78))

                SpriteImageView(urlString: urlString, cornerRadius: 12)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.pmSageAccent : Color.pmSageBorder.opacity(0.55),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            .shadow(
                color: isSelected ? Color.pmSageAccent.opacity(0.45) : .clear,
                radius: isSelected ? 12 : 0,
                x: 0,
                y: 0
            )
        }
        .buttonStyle(SpringButtonStyle())
    }
}

// MARK: - Widget Setup View

struct WidgetSetupView: View {
    let onDone: () -> Void

    var body: some View {
        ZStack {
            PMSageScreenBackdrop()

            VStack(spacing: 32) {
                Spacer()

                Text("📱")
                    .font(.system(size: 80))

                VStack(spacing: 12) {
                    Text("add to home screen")
                        .font(.displayL)
                        .foregroundStyle(Color.pmSageAccentDark)
                        .multilineTextAlignment(.center)
                    Text("long press your home screen → tap +\n→ search Petmoji → add widget")
                        .font(.bodyL)
                        .foregroundStyle(Color.pmSageTextSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                PMSageCTAButton(title: "done, let's go →", action: onDone)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 75)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
