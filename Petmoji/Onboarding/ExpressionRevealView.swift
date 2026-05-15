import SwiftUI

// MARK: - Expression Reveal View (Sprite Preview + Name)

struct ExpressionRevealView: View {
    @ObservedObject var draft: OnboardingDraft
    @EnvironmentObject var appState: AppState
    @Environment(\.petmojiPalette) private var palette
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
    @State private var expressionSyncTask: Task<Void, Never>?
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

    /// True while Stage B is still filling in expressions on the server.
    /// Drives the "still generating" caption and the loading spinners on
    /// thumbnails that don't have a URL yet.
    private var isFillingRemainingExpressions: Bool {
        let filled = [
            expressions.happy, expressions.sleepy, expressions.mad,
            expressions.excited, expressions.missesYou, expressions.judging
        ].compactMap { $0 }.count
        return filled < 6
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
        .onDisappear {
            expressionSyncTask?.cancel()
        }
    }

    // MARK: - Sprite Reveal UI

    @ViewBuilder
    private var spriteRevealContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("say hi to...")
                    .font(.titleL)
                    .foregroundStyle(palette.textSecondary)

                // Hero sprite
                SpriteImageView(urlString: expressions[selectedExpression])
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(
                        color: palette.accent.opacity(0.35),
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

                if isFillingRemainingExpressions {
                    VStack(spacing: 6) {
                        Text("the rest are still loading…")
                            .font(.bodyM)
                            .foregroundStyle(palette.textSecondary)
                        Text("you can move on — they'll appear in Settings under Sprites.")
                            .font(.bodyS)
                            .foregroundStyle(palette.textSecondary.opacity(0.92))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .transition(.opacity)
                }

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
                                size: thumbSize,
                                isLoading: expressions[expression] == nil && isFillingRemainingExpressions
                            ) {
                                guard expressions[expression] != nil else { return }
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
                        .foregroundStyle(palette.accentDark)

                    TextField("enter name...", text: $name)
                        .font(.displayXL)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.textPrimary)
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                        .tint(.blue)
                        .onSubmit {
                            isNameFieldFocused = false
                        }
                        .padding(16)
                        .background(palette.chromeButtonFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(palette.border, lineWidth: 1.5)
                        )
                }
                .padding(.bottom, 8)
            }
            .padding(.top, 8)
            .padding(.horizontal, 24)
            // Room to scroll the name field above the pinned CTA (56pt) + inset padding.
            .padding(.bottom, 96)
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
            .padding(.bottom, 10)
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(palette.textSecondary)
            Text("something went wrong")
                .font(.titleL)
                .foregroundStyle(palette.accentDark)
            Text(msg)
                .font(.bodyM)
                .foregroundStyle(palette.textSecondary)
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

            // 4. Generate sprites — Stage A (the `happy` base) returns sync,
            //    Stages B (the other 5) write to the DB row in the background.
            generationState = .generating
            let initialExpressions = try await SupabaseService.shared.generateSprites(
                petId: pet.id,
                photoURLs: photoURLs,
                petName: "", // no user-typed name yet at this point in onboarding
                species: draft.species
            )

            // Stage A failure surfaces as a 500 (so it would have thrown).
            // Anything else means at least `happy` is back.
            guard initialExpressions.happy != nil else {
                throw NSError(domain: "Petmoji", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "No expressions were generated. Please try again."])
            }

            expressions = initialExpressions
            draft.generatedExpressions = initialExpressions
            if var snapshot = draft.completedPet {
                snapshot.expressions = initialExpressions
                draft.completedPet = snapshot
            }
            generationState = .done

            // Start polling for the remaining 5 expressions written by Stage B.
            startExpressionSync(petId: pet.id)
        } catch {
            generationState = .error(error.localizedDescription)
        }
    }

    /// Polls the pet row and merges newly-written expressions into local state
    /// so the UI fills in thumbnails as Stage B completes.
    private func startExpressionSync(petId: UUID) {
        expressionSyncTask?.cancel()
        expressionSyncTask = Task {
            do {
                for try await partial in SupabaseService.shared.observePetExpressions(petId: petId) {
                    if Task.isCancelled { return }
                    await MainActor.run {
                        expressions = partial
                        draft.generatedExpressions = partial
                        if var snapshot = draft.completedPet {
                            snapshot.expressions = partial
                            draft.completedPet = snapshot
                        }
                    }
                }
            } catch {
                print("[ExpressionReveal] sync error: \(error)")
            }
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

        // Stop the view-local poller — AppState picks it up below so the
        // remaining expressions keep syncing into `appState.currentPet`
        // after this view is dismissed.
        expressionSyncTask?.cancel()
        expressionSyncTask = nil

        Task {
            // Persist only user-edited fields. We deliberately avoid a full
            // upsert here because the edge function's Stage B is concurrently
            // writing `expressions` — a full upsert would clobber any
            // expression that landed after Stage A.
            try? await SupabaseService.shared.updatePetName(petId: pet.id, name: finalName)

            // Re-fetch so we hand off the latest server-side expressions.
            let latest = (try? await SupabaseService.shared.fetchPet(by: pet.id)) ?? pet
            MessageScheduler.shared.savePetMetadata(name: latest.name, petId: latest.id.uuidString)

            // Continue polling at the app level so the home screen keeps
            // updating as the remaining expressions land.
            await MainActor.run {
                // Install the pet before polling: `startSyncingExpressions` merges into
                // `currentPet`, which was nil until widget setup — so Stage B updates were dropped.
                appState.setPet(latest)
                appState.startSyncingExpressions(petId: latest.id)
                onComplete(latest)
            }
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
    @Environment(\.petmojiPalette) private var palette

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
                .foregroundStyle(palette.accentDark)

            Text("this takes about 30 seconds")
                .font(.bodyM)
                .foregroundStyle(palette.textSecondary)

            Text("you'll see the first look on the next screen; other moods keep finishing in the background.")
                .font(.bodyS)
                .foregroundStyle(palette.textSecondary.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            // Shimmer placeholder cards
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(palette.surface)
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
    @Environment(\.petmojiPalette) private var palette

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
            .fill(palette.cardNeutral)
            .overlay {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 24))
                    .foregroundStyle(palette.textSecondary)
            }
    }

    private var placeholderSprite: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(palette.surface)
            .overlay {
                Text("🐾")
                    .font(.system(size: 64))
            }
    }
}

// MARK: - Expression Thumbnail

struct ExpressionThumbnail: View {
    @Environment(\.petmojiPalette) private var palette

    let expression: PetExpression
    let urlString: String?
    let isSelected: Bool
    let size: CGFloat
    var isLoading: Bool = false
    /// When `false`, renders as a static preview (e.g. settings) instead of a tappable control.
    var interactive: Bool = true
    let action: () -> Void

    var body: some View {
        Group {
            if interactive {
                Button(action: action) {
                    tile
                }
                .buttonStyle(SpringButtonStyle())
                .disabled(isLoading)
            } else {
                tile
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(expression.displayName)
            }
        }
    }

    private var tile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? palette.surface : palette.surface.opacity(0.78))

            if let urlString {
                SpriteImageView(urlString: urlString, cornerRadius: 12)
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(palette.textSecondary)
            } else {
                SpriteImageView(urlString: nil, cornerRadius: 12)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected ? palette.accent : palette.border.opacity(0.55),
                    lineWidth: isSelected ? 2.5 : 1
                )
        )
        .shadow(
            color: isSelected ? palette.accent.opacity(0.45) : .clear,
            radius: isSelected ? 12 : 0,
            x: 0,
            y: 0
        )
        .opacity(isLoading ? 0.85 : 1)
    }
}

// MARK: - Widget Setup View

struct WidgetSetupView: View {
    @Environment(\.petmojiPalette) private var palette

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
                        .foregroundStyle(palette.accentDark)
                        .multilineTextAlignment(.center)
                    Text("long press your home screen → tap +\n→ search Petmoji → add widget")
                        .font(.bodyL)
                        .foregroundStyle(palette.textSecondary)
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
