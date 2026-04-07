import SwiftUI

// MARK: - Expression Reveal View (Sprite Preview + Name)

struct ExpressionRevealView: View {
    @ObservedObject var draft: OnboardingDraft
    let onComplete: (Pet) -> Void

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
            // Gradient background
            LinearGradient(
                colors: [Color(hex: "#FFF3EC"), Color(hex: "#EDE8FF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

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
            await startGeneration()
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
        VStack(spacing: 24) {
            Text("say hi to...")
                .font(.titleL)
                .foregroundStyle(Color.pmTextSecondary)

            // Hero sprite
            SpriteImageView(urlString: expressions[selectedExpression])
                .frame(width: 200, height: 200)
                .offset(y: spriteVisible ? 0 : spriteOffset)
                .opacity(spriteVisible ? 1 : 0)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.65).delay(0.2),
                    value: spriteVisible
                )
                .onAppear { spriteVisible = true }

            // Expression thumbnails
            HStack(spacing: 12) {
                ForEach(Array(PetExpression.allCases.enumerated()), id: \.element) { i, expression in
                    ExpressionThumbnail(
                        expression: expression,
                        urlString: expressions[expression],
                        isSelected: selectedExpression == expression
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

            // Name input
            VStack(spacing: 16) {
                Text("what's their name?")
                    .font(.titleL)
                    .foregroundStyle(Color.pmTextPrimary)

                TextField("enter name...", text: $name)
                    .font(.displayXL)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.pmTextPrimary)
                    .padding(16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.pmBorder, lineWidth: 1.5)
                    )
                    .padding(.horizontal, 24)
            }

            Spacer()

            PMPrimaryButton(
                title: name.isEmpty ? "enter a name first" : "meet \(name)! →",
                action: savePet,
                isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.pmTextSecondary)
            Text("something went wrong")
                .font(.titleL)
                .foregroundStyle(Color.pmTextPrimary)
            Text(msg)
                .font(.bodyM)
                .foregroundStyle(Color.pmTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            PMPrimaryButton(title: "try again", action: {
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
        guard var pet = draft.completedPet else { return }
        let finalName = name.trimmingCharacters(in: .whitespaces)
        pet.name = finalName
        pet.expressions = expressions
        Task {
            let saved = try await SupabaseService.shared.savePet(pet)
            MessageScheduler.shared.savePetMetadata(name: saved.name, petId: saved.id.uuidString)
            onComplete(saved)
        }
    }
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
                .foregroundStyle(Color.pmTextPrimary)

            Text("this takes about 30 seconds")
                .font(.bodyM)
                .foregroundStyle(Color.pmTextSecondary)

            // Shimmer placeholder cards
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.pmPrimaryLight)
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

    var body: some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
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
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.pmCardAlt)
            .overlay {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.pmTextSecondary)
            }
    }

    private var placeholderSprite: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.pmSecondaryLight)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SpriteImageView(urlString: urlString)
                .frame(width: 56, height: 56)
                .background(expression.color.opacity(0.3), in: Circle())
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? expression.color : Color.clear, lineWidth: 2.5)
                )
        }
        .buttonStyle(SpringButtonStyle())
    }
}

// MARK: - Widget Setup View

struct WidgetSetupView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("📱")
                .font(.system(size: 80))

            VStack(spacing: 12) {
                Text("add to home screen")
                    .font(.displayL)
                    .foregroundStyle(Color.pmTextPrimary)
                    .multilineTextAlignment(.center)
                Text("long press your home screen → tap +\n→ search Petmoji → add widget")
                    .font(.bodyL)
                    .foregroundStyle(Color.pmTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            PMPrimaryButton(title: "done, let's go →", action: onDone)
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pmBackground)
    }
}
