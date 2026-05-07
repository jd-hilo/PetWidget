import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var petName: String = ""
    @State private var notificationsEnabled = UserDefaults.standard.bool(forKey: "notifications_enabled")
    @State private var isRegenerating = false
    @State private var regenerateError: String?
    @State private var regenerateSuccess = false
    @State private var showResetConfirm = false
    @State private var nameUpdateTask: Task<Void, Never>?

    private var pet: Pet? { appState.currentPet }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        List {
            // MARK: Pet Profile
            Section {
                HStack(spacing: 16) {
                    SpriteImageView(urlString: pet?.expressions[.happy])
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.pmBorder, lineWidth: 1))

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("pet name", text: $petName)
                            .font(.bodyL)
                            .foregroundStyle(Color.pmTextPrimary)

                        if let pet {
                            Text(pet.species.displayName)
                                .font(.bodyS)
                                .foregroundStyle(Color.pmTextSecondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("pet profile")
            }

            // MARK: Notifications
            Section {
                Toggle("scheduled messages", isOn: $notificationsEnabled)
                    .tint(Color.black)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        UserDefaults.standard.set(enabled, forKey: "notifications_enabled")
                    }
            } header: {
                Text("notifications")
            }

            // MARK: Sprites
            Section {
                Button("regenerate sprites") {
                    isRegenerating = true
                    regenerateError = nil
                    regenerateSuccess = false
                }
                .foregroundStyle(Color.black)

                if let error = regenerateError {
                    Text(error)
                        .font(.bodyS)
                        .foregroundStyle(.red)
                }
                if regenerateSuccess {
                    Label("sprites regenerated!", systemImage: "checkmark.circle.fill")
                        .font(.bodyM)
                        .foregroundStyle(.green)
                }
            } header: {
                Text("sprites")
            } footer: {
                Text("re-runs AI sprite generation from your original photos.")
            }

            // MARK: Danger Zone
            Section {
                Button("reset & start over", role: .destructive) {
                    showResetConfirm = true
                }
            } header: {
                Text("account")
            }

            // MARK: App Version Footer
            Section {
                Text("petmoji \(appVersion)")
                    .font(.bodyS)
                    .foregroundStyle(Color.pmTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            petName = pet?.name ?? ""
        }
        .onChange(of: petName) { _, newName in
            guard let petId = pet?.id else { return }
            nameUpdateTask?.cancel()
            nameUpdateTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                try? await SupabaseService.shared.updatePetName(petId: petId, name: newName)
                await MainActor.run {
                    if var updated = appState.currentPet {
                        updated.name = newName
                        appState.currentPet = updated
                    }
                }
            }
        }
        .confirmationDialog("Reset Onboarding", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset & Start Over", role: .destructive) {
                Task { await appState.resetForOnboarding() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will sign you out and delete your current pet setup.")
        }
        // Loading modal — shown when isRegenerating = true
        .sheet(isPresented: $isRegenerating) {
            RegeneratingModal(
                isPresented: $isRegenerating,
                error: $regenerateError,
                success: $regenerateSuccess,
                pet: pet
            )
            .interactiveDismissDisabled(true)
        }
    }
}

// MARK: - Regenerating Modal

struct RegeneratingModal: View {
    @Binding var isPresented: Bool
    @Binding var error: String?
    @Binding var success: Bool
    let pet: Pet?

    @EnvironmentObject var appState: AppState
    @State private var phase: Phase = .working
    @State private var rotation: Double = 0

    enum Phase { case working, done, failed(String) }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            switch phase {
            case .working:
                VStack(spacing: 20) {
                    Text("✨")
                        .font(.system(size: 72))
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }

                    Text("regenerating sprites...")
                        .font(.titleL)
                        .foregroundStyle(Color.pmTextPrimary)

                    Text("keep the app open — this takes about 30 seconds")
                        .font(.bodyM)
                        .foregroundStyle(Color.pmTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

            case .done:
                VStack(spacing: 16) {
                    Text("🎉")
                        .font(.system(size: 72))

                    Text("new sprite ready!")
                        .font(.titleL)
                        .foregroundStyle(Color.pmTextPrimary)

                    Text("the rest will fill in over the next minute — you can close this.")
                        .font(.bodyM)
                        .foregroundStyle(Color.pmTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

            case .failed(let msg):
                VStack(spacing: 16) {
                    Text("😬")
                        .font(.system(size: 72))

                    Text("something went wrong")
                        .font(.titleL)
                        .foregroundStyle(Color.pmTextPrimary)

                    Text(msg)
                        .font(.bodyM)
                        .foregroundStyle(Color.pmTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Spacer()

            if case .working = phase {
                // no button — can't dismiss while working
            } else {
                PMPrimaryButton(title: "done") {
                    isPresented = false
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pmBackground)
        // Keep screen on during generation
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            Task { await runRegeneration() }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func runRegeneration() async {
        guard let pet = pet ?? appState.currentPet else {
            phase = .failed("no pet found")
            return
        }

        do {
            let photoURLs = try await SupabaseService.shared.getStoredPhotoURLs(petId: pet.id)
            guard !photoURLs.isEmpty else {
                phase = .failed("no photos found for this pet")
                return
            }
            // Stage A returns synchronously with the `happy` base. Stages B
            // for the remaining 5 expressions land in `pets.expressions` over
            // the following minute or so; we hand polling off to AppState so
            // the home screen keeps updating after this modal is dismissed.
            let initialExpressions = try await SupabaseService.shared.generateSprites(
                petId: pet.id,
                photoURLs: photoURLs,
                petName: pet.name == "unnamed" ? "" : pet.name,
                species: pet.species
            )
            await MainActor.run {
                if var updated = appState.currentPet {
                    updated.expressions = initialExpressions
                    appState.currentPet = updated
                }
                appState.startSyncingExpressions(petId: pet.id)
                success = true
                phase = .done
            }
        } catch {
            await MainActor.run {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}
