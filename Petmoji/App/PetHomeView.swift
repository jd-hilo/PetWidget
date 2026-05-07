import SwiftUI
import UIKit

struct PetHomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var latestMessageByPet: [UUID: PetMessage] = [:]
    @State private var recentMessagesByPet: [UUID: [ChatMessage]] = [:]
    @State private var isLoadingByPet: [UUID: Bool] = [:]
    @State private var isChatPanelExpandedByPet: [UUID: Bool] = [:]
    @State private var breatheByPet: [UUID: Bool] = [:]
    @State private var showSettings = false
    @State private var selectedPetForChatRoom: Pet?
    @State private var showChatRoom = false
    @AppStorage("petHomeExpandedPetIDs") private var expandedPetIDsRaw = ""

    private var pets: [Pet] { appState.availablePets }
    private var expandedPetIDs: Set<UUID> {
        Set(expandedPetIDsRaw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "good morning"
        case 12..<17: return "good afternoon"
        case 17..<21: return "good evening"
        default: return "goodnight"
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let horizontalInset: CGFloat = 16
            let contentWidth = max(220, proxy.size.width - (horizontalInset * 2))
            let chatPanelHeight = min(proxy.size.height * 0.55, 520)
            let recentPreviewLimit = proxy.size.height < 760 ? 2 : 3

            ZStack {
                PMSageScreenBackdrop()

                VStack(spacing: 12) {
                    HomeHeader(
                        greeting: greeting,
                        petCount: pets.count,
                        onShowSettings: { showSettings = true }
                    )
                    .padding(.horizontal, horizontalInset)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            if pets.isEmpty {
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .fill(Color.white.opacity(0.9))
                                    .overlay(
                                        Text("no pet yet")
                                            .font(.bodyL)
                                            .foregroundStyle(Color.pmSageTextSecondary)
                                    )
                                    .frame(height: 260)
                            } else {
                                ForEach(pets) { pet in
                                    let isExpanded = expandedPetIDs.contains(pet.id)

                                    Group {
                                        if isExpanded {
                                            ExpandedPetCardContent(
                                                pet: pet,
                                                latestMessage: latestMessageByPet[pet.id],
                                                recentMessages: recentMessagesByPet[pet.id] ?? [],
                                                isLoadingMessage: isLoadingByPet[pet.id] ?? false,
                                                isChatPanelExpanded: isChatPanelExpandedByPet[pet.id] ?? false,
                                                isBreathing: breatheByPet[pet.id] ?? false,
                                                contentWidth: contentWidth,
                                                chatPanelHeight: chatPanelHeight,
                                                recentPreviewLimit: recentPreviewLimit,
                                                onToggleCardExpansion: {
                                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                                        toggleExpanded(for: pet.id)
                                                    }
                                                },
                                                onToggleChatPanel: {
                                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                                        setChatPanelExpanded(!(isChatPanelExpandedByPet[pet.id] ?? false), for: pet.id)
                                                    }
                                                },
                                                onOpenChatPanel: {
                                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                                        setChatPanelExpanded(true, for: pet.id)
                                                    }
                                                },
                                                onOpenChatRoom: {
                                                    appState.selectPet(pet)
                                                    selectedPetForChatRoom = pet
                                                    showChatRoom = true
                                                },
                                                onSpriteAppeared: { breatheByPet[pet.id] = true }
                                            )
                                        } else {
                                            CollapsedPetCardContent(
                                                pet: pet,
                                                latestMessage: latestMessageByPet[pet.id],
                                                isLoadingMessage: isLoadingByPet[pet.id] ?? false
                                            ) {
                                                appState.selectPet(pet)
                                                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                                    toggleExpanded(for: pet.id)
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .strokeBorder(Color.pmSageBorder.opacity(0.75), lineWidth: 1.2)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12) + 12)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if pets.isEmpty {
                    PMSageCTAButton(title: "open settings") { showSettings = true }
                        .padding(.horizontal, 16)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom, 8) + 8)
                }
            }
        }
        .navigationDestination(isPresented: $showSettings) { SettingsView() }
        .navigationDestination(isPresented: $showChatRoom) {
            if let pet = selectedPetForChatRoom {
                PetChatRoomView(pet: pet)
            }
        }
        .task(id: pets.map(\.id)) {
            await loadMessagesForAllPets()
            reconcilePerPetState()
            reconcilePersistedExpansionWithAvailablePets()
        }
        .onChange(of: appState.pendingWidgetDeepLink) { _, link in
            guard link == .openChat else { return }
            openDeepLinkedChat()
        }
        .onAppear {
            if appState.pendingWidgetDeepLink == .openChat {
                openDeepLinkedChat()
            }
        }
    }

    private func openDeepLinkedChat() {
        if let selected = appState.currentPet ?? pets.first {
            appState.selectPet(selected)
            setExpanded(true, for: selected.id)
            setChatPanelExpanded(true, for: selected.id)
        }
        appState.pendingWidgetDeepLink = .none
    }

    private func reconcilePerPetState() {
        let validIDs = Set(pets.map(\.id))
        latestMessageByPet = latestMessageByPet.filter { validIDs.contains($0.key) }
        recentMessagesByPet = recentMessagesByPet.filter { validIDs.contains($0.key) }
        isLoadingByPet = isLoadingByPet.filter { validIDs.contains($0.key) }
        isChatPanelExpandedByPet = isChatPanelExpandedByPet.filter { validIDs.contains($0.key) }
        breatheByPet = breatheByPet.filter { validIDs.contains($0.key) }
    }

    private func reconcilePersistedExpansionWithAvailablePets() {
        let validIDs = Set(pets.map(\.id))
        persistExpandedIDs(expandedPetIDs.intersection(validIDs))
    }

    private func toggleExpanded(for petID: UUID) {
        setExpanded(!expandedPetIDs.contains(petID), for: petID)
    }

    private func setExpanded(_ expanded: Bool, for petID: UUID) {
        var next = expandedPetIDs
        if expanded {
            next.insert(petID)
        } else {
            next.remove(petID)
            setChatPanelExpanded(false, for: petID)
            refreshRecentMessagesFromLocalHistory(for: petID)
        }
        persistExpandedIDs(next)
    }

    private func persistExpandedIDs(_ ids: Set<UUID>) {
        expandedPetIDsRaw = ids.map(\.uuidString).sorted().joined(separator: ",")
    }

    private func setChatPanelExpanded(_ expanded: Bool, for petID: UUID) {
        isChatPanelExpandedByPet[petID] = expanded
        if !expanded {
            refreshRecentMessagesFromLocalHistory(for: petID)
        }
    }

    private func loadMessagesForAllPets() async {
        for pet in pets {
            await loadMessageData(for: pet)
        }
    }

    private func loadMessageData(for pet: Pet) async {
        isLoadingByPet[pet.id] = true
        defer { isLoadingByPet[pet.id] = false }
        do {
            let localHistory = ChatHistoryStore.loadHistory(for: pet.id)
            if !localHistory.isEmpty {
                recentMessagesByPet[pet.id] = Array(localHistory.suffix(8))
                if let latestPetChat = localHistory.last(where: { $0.isFromPet }) {
                    latestMessageByPet[pet.id] = PetMessage(
                        id: UUID(),
                        petId: pet.id,
                        content: latestPetChat.content,
                        expression: latestPetChat.expression ?? .happy,
                        triggerType: .chatReply,
                        scheduledFor: latestPetChat.timestamp,
                        sentAt: latestPetChat.timestamp
                    )
                }
            }

            if let fetchedLatest = try await SupabaseService.shared.fetchLatestMessage(for: pet.id) {
                latestMessageByPet[pet.id] = fetchedLatest
            }
            let recent = try await SupabaseService.shared.fetchRecentMessages(for: pet.id, limit: 4)
            let mapped = recent.reversed().map { ChatMessage(content: $0.content, isFromPet: true, expression: $0.expression) }
            if localHistory.isEmpty {
                recentMessagesByPet[pet.id] = mapped
            }

            if let message = latestMessageByPet[pet.id], pet.id == appState.currentPet?.id {
                WidgetSnapshotSync.writeFromPet(pet, message: message)
            }
        } catch {}
    }

    private func refreshRecentMessagesFromLocalHistory(for petID: UUID) {
        guard let pet = pets.first(where: { $0.id == petID }) else { return }
        let localHistory = ChatHistoryStore.loadHistory(for: pet.id)
        guard !localHistory.isEmpty else { return }
        recentMessagesByPet[pet.id] = Array(localHistory.suffix(8))
        if let latestPetChat = localHistory.last(where: { $0.isFromPet }) {
            let synced = PetMessage(
                id: UUID(),
                petId: pet.id,
                content: latestPetChat.content,
                expression: latestPetChat.expression ?? .happy,
                triggerType: .chatReply,
                scheduledFor: latestPetChat.timestamp,
                sentAt: latestPetChat.timestamp
            )
            latestMessageByPet[pet.id] = synced
            if pet.id == appState.currentPet?.id {
                WidgetSnapshotSync.writeFromPet(pet, message: synced)
            }
        }
    }
}

private struct HomeHeader: View {
    let greeting: String
    let petCount: Int
    let onShowSettings: () -> Void

    private var checkInText: String {
        if petCount == 1 {
            return "your pet is checking in"
        }
        return "your pets are checking in"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.titleL.weight(.bold))
                    .foregroundStyle(Color.pmSageTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(checkInText)
                    .font(.bodyM)
                    .foregroundStyle(Color.pmSageTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            Spacer(minLength: 8)
            Button(action: onShowSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.pmSageIconTint)
                    .frame(width: 56, height: 56)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.pmSageBorder.opacity(0.9), lineWidth: 1.25)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct CollapsedPetCardContent: View {
    let pet: Pet
    let latestMessage: PetMessage?
    let isLoadingMessage: Bool
    let onTap: () -> Void

    private var expression: PetExpression { latestMessage?.expression ?? .happy }
    private var spriteURL: String? { pet.expressions[expression] ?? pet.expressions[.happy] }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                SpriteImageView(urlString: spriteURL, contentMode: .fill)
                    .frame(width: 84, height: 84)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.pmSageBorder.opacity(0.85), lineWidth: 1.25))
                    .padding(2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(pet.name).font(.bodyL).foregroundStyle(Color.pmSageTextPrimary).lineLimit(1)
                        HomeStatusChip(icon: "heart.fill", title: expression.displayName)
                    }

                    if isLoadingMessage && latestMessage == nil {
                        Text("checking in...").font(.bodyM).foregroundStyle(Color.pmSageTextSecondary).lineLimit(1)
                    } else {
                        Text(latestMessage?.content ?? "tap to open \(pet.name)'s full view")
                            .font(.bodyM)
                            .foregroundStyle(Color.pmSageTextSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 6)
                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.pmSageAccentDark)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Expand \(pet.name)")
    }
}

private struct ExpandedPetCardContent: View {
    let pet: Pet
    let latestMessage: PetMessage?
    let recentMessages: [ChatMessage]
    let isLoadingMessage: Bool
    let isChatPanelExpanded: Bool
    let isBreathing: Bool
    let contentWidth: CGFloat
    let chatPanelHeight: CGFloat
    let recentPreviewLimit: Int
    let onToggleCardExpansion: () -> Void
    let onToggleChatPanel: () -> Void
    let onOpenChatPanel: () -> Void
    let onOpenChatRoom: () -> Void
    let onSpriteAppeared: () -> Void

    private var expression: PetExpression { latestMessage?.expression ?? .happy }
    private var spriteURL: String? { pet.expressions[expression] ?? pet.expressions[.happy] }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(pet.name).font(.titleL).foregroundStyle(Color.pmSageTextPrimary).lineLimit(1)
                Spacer()
                Button(action: onToggleCardExpansion) {
                    Label("Collapse", systemImage: "chevron.up").font(.bodyS).foregroundStyle(Color.pmSageAccentDark)
                }
                .buttonStyle(.plain)
            }

            Button(action: onOpenChatPanel) {
                VStack(spacing: 14) {
                    let spriteWidth = max(170, contentWidth - 56)
                    let spriteHeight = spriteWidth * 0.9
                    let breatheScale: CGFloat = 1.02

                    SpriteImageView(urlString: spriteURL, contentMode: .fill)
                        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .frame(width: spriteWidth / breatheScale, height: spriteHeight / breatheScale)
                        .scaleEffect(isBreathing ? breatheScale : 1.0)
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isBreathing)
                        .onAppear(perform: onSpriteAppeared)
                        .frame(width: spriteWidth, height: spriteHeight)
                        .mask(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .clipped()

                    HStack(spacing: 10) {
                        HomeStatusChip(icon: "heart.fill", title: expression.displayName)
                        HomeStatusChip(icon: "bolt.fill", title: "Active")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.pmSageWashDeep.opacity(0.75), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(Color.pmSageBorder.opacity(0.8), lineWidth: 1.4)
                )
            }
            .buttonStyle(.plain)

            VStack(spacing: 10) {
                Button(action: onToggleChatPanel) {
                    HStack {
                        Text(isChatPanelExpanded ? "Chat with \(pet.name.lowercased())" : "Recent messages")
                            .font(.bodyL)
                            .foregroundStyle(Color.pmSageTextPrimary)
                        Spacer()
                        Image(systemName: isChatPanelExpanded ? "chevron.down" : "chevron.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.pmSageAccentDark)
                    }
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isChatPanelExpanded {
                    ChatPanel(pet: pet)
                        .id(pet.id)
                        .frame(height: chatPanelHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else if recentMessages.isEmpty && isLoadingMessage {
                    TypingIndicator()
                } else if recentMessages.isEmpty {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.84))
                        .overlay(
                            Text("start chatting with your pet")
                                .font(.bodyM)
                                .foregroundStyle(Color.pmSageTextSecondary)
                                .padding(.horizontal, 14)
                        )
                        .frame(height: 64)
                } else {
                    ForEach(recentMessages.suffix(recentPreviewLimit)) { message in
                        HomePreviewBubble(message: message)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.pmSageBorder.opacity(0.7), lineWidth: 1.2)
            )

            Button(action: onOpenChatRoom) {
                Text("chat with \(pet.name.lowercased())")
                    .font(.buttonFont)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.pmSageAccentDark, in: Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.pmSageBorder.opacity(0.6), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }
}

private struct PetChatRoomView: View {
    let pet: Pet

    var body: some View {
        ChatPanel(pet: pet)
            .navigationTitle("Chat with \(pet.name)")
            .navigationBarTitleDisplayMode(.inline)
            .pmSageScreenBackground()
    }
}

struct HomeStatusChip: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
            Text(title.lowercased()).font(.bodyS).lineLimit(1)
        }
        .foregroundStyle(Color.pmSageTextPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.9), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.pmSageBorder.opacity(0.8), lineWidth: 1))
    }
}

struct HomePreviewBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromPet {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pmSageIconTint)
                    .frame(width: 24, height: 24)
                Text(message.content)
                    .font(.bodyM)
                    .foregroundStyle(Color.pmSageTextPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.pmSageWashSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                Text(message.content)
                    .font(.bodyM)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.pmSageAccentDark, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct TypingIndicator: View {
    @State private var animating = false
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.pmSageTextSecondary)
                    .frame(width: 8, height: 8)
                    .opacity(animating ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.18), value: animating)
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.pmSageBorder, lineWidth: 1.5))
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { animating = true }
    }
}
