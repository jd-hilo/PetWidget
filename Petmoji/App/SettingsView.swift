import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.petmojiPalette) private var palette

    @State private var petName: String = ""
    @State private var notificationsEnabled = UserDefaults.standard.bool(forKey: "notifications_enabled")
    @State private var isRegenerating = false
    @State private var regenerateError: String?
    @State private var regenerateSuccess = false
    @State private var showResetConfirm = false
    @State private var showRegenerateConfirm = false
    @State private var showSignOutConfirm = false
    @State private var nameUpdateTask: Task<Void, Never>?

    private var pet: Pet? { appState.currentPet }

    private func spriteThumbLoading(_ expression: PetExpression, pet: Pet) -> Bool {
        pet.expressions[expression] == nil && appState.expressionSyncPetId == pet.id
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// In DEBUG mock-user mode, only mock account fields are shown; pet sections are hidden.
    private var showsPetCentricSettings: Bool {
        #if DEBUG
        appState.settingsPersona == .pet
        #else
        true
        #endif
    }

    var body: some View {
        ZStack {
            PMSageScreenBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
#if DEBUG
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Settings mode", selection: Binding(
                            get: { appState.settingsPersona },
                            set: { appState.setSettingsPersona($0) }
                        )) {
                            ForEach(SettingsPersona.allCases) { persona in
                                Text(persona.segmentTitle).tag(persona)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Settings mode")

                        if appState.settingsPersona == .mockUser {
                            SettingsSageSection(
                                title: "mock user (preview)",
                                footer: "Preview only until account sign-in ships."
                            ) {
                                VStack(alignment: .leading, spacing: 16) {
                                    ClassicDarkModeToggleRow()

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("display name")
                                            .font(.bodyS)
                                            .foregroundStyle(palette.textSecondary)
                                        TextField("Alex", text: Binding(
                                            get: { appState.mockUserDisplayName },
                                            set: { appState.setMockUserDisplayName($0) }
                                        ))
                                        .font(.bodyL)
                                        .foregroundStyle(palette.textPrimary)
                                        .textContentType(.name)
                                        .textInputAutocapitalization(.words)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("email (preview)")
                                            .font(.bodyS)
                                            .foregroundStyle(palette.textSecondary)
                                        TextField("alex@example.com", text: Binding(
                                            get: { appState.mockUserEmail },
                                            set: { appState.setMockUserEmail($0) }
                                        ))
                                        .font(.bodyL)
                                        .foregroundStyle(palette.textPrimary)
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                    }

                                    Toggle("verbose logging", isOn: Binding(
                                        get: { appState.mockUserVerboseLogs },
                                        set: { appState.setMockUserVerboseLogs($0) }
                                    ))
                                    .font(.bodyM)
                                    .foregroundStyle(palette.textPrimary)

                                    Toggle("bundled debug sprites", isOn: Binding(
                                        get: { appState.mockUserDebugSprites },
                                        set: { appState.setMockUserDebugSprites($0) }
                                    ))
                                    .font(.bodyM)
                                    .foregroundStyle(palette.textPrimary)
                                }
                            }
                        } else {
                            SettingsSageSection(
                                title: "display",
                                footer: "Dark Mode uses the same dark glass look as your home screen widgets."
                            ) {
                                ClassicDarkModeToggleRow()
                            }
                        }
                    }
#else
                    SettingsSageSection(
                        title: "display",
                        footer: "Dark Mode uses the same dark glass look as your home screen widgets."
                    ) {
                        ClassicDarkModeToggleRow()
                    }
#endif

                    if appState.hasCompletedSignUp {
                        SettingsSageSection(
                            title: "account",
                            footer: "Preview only. Returns you to sign-up from the beginning."
                        ) {
                            Button("sign out") {
                                showSignOutConfirm = true
                            }
                            .font(.bodyL)
                            .foregroundStyle(palette.accentDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .popover(
                                isPresented: $showSignOutConfirm,
                                attachmentAnchor: .rect(.bounds),
                                arrowEdge: .top
                            ) {
                                MockSignOutConfirmPopover(
                                    isPresented: $showSignOutConfirm,
                                    onSignOut: {
                                        Task { await appState.mockSignOut() }
                                    }
                                )
                            }
                        }
                    }

                    if showsPetCentricSettings {
                    SettingsSageSection(title: "pet profile") {
                        HStack(spacing: 16) {
                            SpriteImageView(urlString: pet?.expressions[.happy])
                                .frame(width: 52, height: 52)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().strokeBorder(palette.border.opacity(0.85), lineWidth: 1.25)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                TextField("pet name", text: $petName)
                                    .font(.bodyL)
                                    .foregroundStyle(palette.textPrimary)

                                if let pet {
                                    Text(pet.species.displayName)
                                        .font(.bodyS)
                                        .foregroundStyle(palette.textSecondary)
                                }
                            }
                        }
                    }

                    SettingsSageSection(title: "notifications") {
                        Toggle("scheduled messages", isOn: $notificationsEnabled)
                            .font(.bodyM)
                            .foregroundStyle(palette.textPrimary)
                            .tint(palette.accent)
                            .onChange(of: notificationsEnabled) { _, enabled in
                                UserDefaults.standard.set(enabled, forKey: "notifications_enabled")
                            }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("sprites")
                            .font(.titleL)
                            .foregroundStyle(palette.accentDark)

                        VStack(spacing: 12) {
                            Group {
                                if let pet {
                                    LazyVGrid(
                                        columns: [
                                            GridItem(.flexible(), spacing: 8),
                                            GridItem(.flexible(), spacing: 8),
                                            GridItem(.flexible(), spacing: 8),
                                        ],
                                        alignment: .center,
                                        spacing: 8
                                    ) {
                                        ForEach(PetExpression.allCases, id: \.self) { expression in
                                            ExpressionThumbnail(
                                                expression: expression,
                                                urlString: pet.expressions[expression],
                                                isSelected: false,
                                                size: 52,
                                                isLoading: spriteThumbLoading(expression, pet: pet),
                                                interactive: false,
                                                action: {}
                                            )
                                            .frame(maxWidth: .infinity)
                                        }
                                    }
                                } else {
                                    Text("no pet loaded")
                                        .font(.bodyM)
                                        .foregroundStyle(palette.textSecondary)
                                }
                            }
                            .settingsSageInsetCard()

                            VStack(alignment: .leading, spacing: 12) {
                                Button("regenerate sprites") {
                                    showRegenerateConfirm = true
                                }
                                .font(.bodyL)
                                .foregroundStyle(palette.accentDark)
                                .popover(
                                    isPresented: $showRegenerateConfirm,
                                    attachmentAnchor: .rect(.bounds),
                                    arrowEdge: .top
                                ) {
                                    RegenerateSpritesConfirmPopover(
                                        isPresented: $showRegenerateConfirm,
                                        onConfirm: {
                                            isRegenerating = true
                                            regenerateError = nil
                                            regenerateSuccess = false
                                        }
                                    )
                                }

                                if let error = regenerateError {
                                    Text(error)
                                        .font(.bodyS)
                                        .foregroundStyle(.red.opacity(0.9))
                                }
                                if regenerateSuccess {
                                    Label("sprites regenerated!", systemImage: "checkmark.circle.fill")
                                        .font(.bodyM)
                                        .foregroundStyle(palette.accentDark)
                                }
                            }
                            .settingsSageInsetCard()
                        }

                        Text("re-runs AI sprite generation from your original photos.")
                            .font(.bodyS)
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                    }

                    SettingsSageSection(title: "danger zone", titleColor: .red) {
                        Button("reset & start over", role: .destructive) {
                            showResetConfirm = true
                        }
                        .font(.bodyL)
                        .popover(
                            isPresented: $showResetConfirm,
                            attachmentAnchor: .rect(.bounds),
                            arrowEdge: .bottom
                        ) {
                            ResetOnboardingConfirmPopover(
                                isPresented: $showResetConfirm,
                                onReset: {
                                    Task { await appState.resetForOnboarding() }
                                }
                            )
                        }
                    }

                    }

                    Text("petmoji \(appVersion)")
                        .font(.bodyS)
                        .foregroundStyle(palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(palette.accentDark)
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

// MARK: - Dark Mode (system-style switch)

private struct ClassicDarkModeToggleRow: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.petmojiPalette) private var palette

    var body: some View {
        HStack(alignment: .center) {
            Text("Dark Mode")
                .font(.bodyM)
                .foregroundStyle(palette.textPrimary)
            Spacer(minLength: 12)
            Toggle("", isOn: Binding(
                get: { appState.isDarkModeEnabled },
                set: { appState.setDarkModeEnabled($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dark Mode")
        .accessibilityValue(appState.isDarkModeEnabled ? "On" : "Off")
    }
}

// MARK: - Anchored confirm popovers (near the triggering button)

private struct RegenerateSpritesConfirmPopover: View {
    @Environment(\.petmojiPalette) private var palette

    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Regenerate sprites?")
                .font(.titleL)
                .foregroundStyle(palette.accentDark)
            Text("This re-runs AI on your saved photos (about 30 seconds). Your current sprites will be replaced.")
                .font(.bodyM)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.bordered)
                    .tint(palette.accentDark)
                Button("Regenerate") {
                    isPresented = false
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
            }
        }
        .padding(20)
        .frame(minWidth: 300)
        .presentationCompactAdaptation(.popover)
    }
}

private struct MockSignOutConfirmPopover: View {
    @Environment(\.petmojiPalette) private var palette

    @Binding var isPresented: Bool
    let onSignOut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sign out?")
                .font(.titleL)
                .foregroundStyle(palette.accentDark)
            Text("This clears your account preview and pet, then takes you back to sign-up.")
                .font(.bodyM)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.bordered)
                    .tint(palette.accentDark)
                Button("Sign Out", role: .destructive) {
                    isPresented = false
                    onSignOut()
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
            }
        }
        .padding(20)
        .frame(minWidth: 300)
        .presentationCompactAdaptation(.popover)
    }
}

private struct ResetOnboardingConfirmPopover: View {
    @Environment(\.petmojiPalette) private var palette

    @Binding var isPresented: Bool
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reset onboarding")
                .font(.titleL)
                .foregroundStyle(palette.accentDark)
            Text("This will sign you out and delete your current pet setup.")
                .font(.bodyM)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.bordered)
                    .tint(palette.accentDark)
                Button("Reset & Start Over", role: .destructive) {
                    isPresented = false
                    onReset()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(20)
        .frame(minWidth: 300)
        .presentationCompactAdaptation(.popover)
    }
}

// MARK: - Settings inset card (matches `SettingsSageSection` inner chrome)

private struct SettingsSageInsetCardModifier: ViewModifier {
    @Environment(\.petmojiPalette) private var palette

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(palette.elevatedCardFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(palette.elevatedCardStroke, lineWidth: 1.2)
            )
    }
}

private extension View {
    func settingsSageInsetCard() -> some View {
        modifier(SettingsSageInsetCardModifier())
    }
}

// MARK: - Sage section (matches home pet cards)

private struct SettingsSageSection<Content: View>: View {
    @Environment(\.petmojiPalette) private var palette

    let title: String
    var footer: String?
    var titleColor: Color?
    @ViewBuilder var content: () -> Content

    init(title: String, footer: String? = nil, titleColor: Color? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footer = footer
        self.titleColor = titleColor
        self.content = content
    }

    private var resolvedTitleColor: Color {
        titleColor ?? palette.accentDark
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.titleL)
                .foregroundStyle(resolvedTitleColor)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(palette.elevatedCardFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(palette.elevatedCardStroke, lineWidth: 1.2)
                )

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.bodyS)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }
}

// MARK: - Regenerating Modal

struct RegeneratingModal: View {
    @Environment(\.petmojiPalette) private var palette

    @Binding var isPresented: Bool
    @Binding var error: String?
    @Binding var success: Bool
    let pet: Pet?

    @EnvironmentObject var appState: AppState
    @State private var phase: Phase = .working
    @State private var rotation: Double = 0

    enum Phase { case working, done, failed(String) }

    var body: some View {
        ZStack {
            PMSageScreenBackdrop()

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
                            .foregroundStyle(palette.textPrimary)

                        Text("keep the app open — this takes about 30 seconds")
                            .font(.bodyM)
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                case .done:
                    VStack(spacing: 16) {
                        Text("🎉")
                            .font(.system(size: 72))

                        Text("new sprite ready!")
                            .font(.titleL)
                            .foregroundStyle(palette.textPrimary)

                        Text("the rest will fill in over the next minute — you can close this.")
                            .font(.bodyM)
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                case .failed(let msg):
                    VStack(spacing: 16) {
                        Text("😬")
                            .font(.system(size: 72))

                        Text("something went wrong")
                            .font(.titleL)
                            .foregroundStyle(palette.textPrimary)

                        Text(msg)
                            .font(.bodyM)
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }

                Spacer()

                if case .working = phase {
                    EmptyView()
                } else {
                    PMPrimaryButton(title: "done") {
                        isPresented = false
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
