import SwiftUI
import WidgetKit

// MARK: - Pet Home View

struct PetHomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var latestMessage: PetMessage?
    @State private var recentMessages: [ChatMessage] = []
    @State private var breathe = false
    @State private var showChat = false
    @State private var isLoadingMessage = false
    @State private var isSendingMessage = false
    @State private var showSettings = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var inlineComposerText = ""

    var pet: Pet? { appState.currentPet }

    var greeting: String {
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
            let topPadding = max(proxy.safeAreaInsets.top - 6, 0)
            let horizontalInset: CGFloat = 16
            let contentWidth = max(220, proxy.size.width - (horizontalInset * 2))
            let spriteWidth = max(170, contentWidth - 56)
            let recentPreviewLimit = proxy.size.height < 760 ? 2 : 3

            ZStack {
                PMSageScreenBackdrop()

                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            if let pet {
                                Text("\(greeting), \(pet.name)")
                                    .font(.titleL)
                                    .foregroundStyle(Color.pmSageTextPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            } else {
                                Text(greeting)
                                    .font(.titleL)
                                    .foregroundStyle(Color.pmSageTextPrimary)
                            }
                            Text("your pet is checking in")
                                .font(.bodyS)
                                .foregroundStyle(Color.pmSageTextSecondary)
                        }
                        Spacer(minLength: 8)
                        Button {
                            showSettings = true
                        } label: {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, horizontalInset)
                    // .padding(.top, topPadding)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            if let pet {
                                let activeExpression = latestMessage?.expression ?? .happy
                                let spriteURL = pet.expressions[activeExpression] ?? pet.expressions[.happy]
                                Button {
                                    showChat = true
                                } label: {
                                    VStack(spacing: 14) {
                                        SpriteImageView(urlString: spriteURL, contentMode: .fill)
                                            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                                            .frame(width: spriteWidth, height: spriteWidth * 0.9)
                                            .mask(
                                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                            )
                                            .clipped()
                                            .scaleEffect(breathe ? 1.02 : 1.0)
                                            .animation(
                                                .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                                                value: breathe
                                            )
                                            .onAppear { breathe = true }

                                        HStack(spacing: 10) {
                                            HomeStatusChip(icon: "heart.fill", title: activeExpression.displayName)
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
                                .frame(width: contentWidth)
                                .buttonStyle(.plain)
                                .accessibilityLabel("Open chat with \(pet.name)")
                            } else {
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .fill(Color.white.opacity(0.9))
                                    .overlay(
                                        Text("no pet yet")
                                            .font(.bodyL)
                                            .foregroundStyle(Color.pmSageTextSecondary)
                                    )
                                    .frame(height: 260)
                                    .padding(.horizontal, 16)
                            }

                            VStack(spacing: 10) {
                                HStack {
                                    Text("Recent messages")
                                        .font(.bodyL)
                                        .foregroundStyle(Color.pmSageTextPrimary)
                                    Spacer()
                                    Button("See all") {
                                        showChat = true
                                    }
                                    .font(.bodyL)
                                    .foregroundStyle(Color.pmSageAccentDark)
                                }
                                .padding(.horizontal, 6)

                                if recentMessages.isEmpty && isLoadingMessage {
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

                                if let pet {
                                    PMSageCTAButton(title: "talk with \(pet.name.lowercased())") {
                                        showChat = true
                                    }
                                    .padding(.top, 4)
                                    .accessibilityLabel("Talk with \(pet.name)")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(Color.pmSageBorder.opacity(0.7), lineWidth: 1.2)
                            )
                        }
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, 8)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let pet {
                    HStack(spacing: 10) {
                        TextField("Talk to \(pet.name)...", text: $inlineComposerText, axis: .vertical)
                            .font(.bodyM)
                            .lineLimit(1...3)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Color.pmSageBorder.opacity(0.7), lineWidth: 1)
                            )

                        Button {
                            showChat = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.pmSageIconTint)
                                .frame(width: 42, height: 42)
                                .background(Color.white, in: Circle())
                                .overlay(Circle().strokeBorder(Color.pmSageBorder.opacity(0.8), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open full chat")

                        Button {
                            Task { await sendInlineMessage() }
                        } label: {
                            Image(systemName: isSendingMessage ? "ellipsis.circle.fill" : "arrow.up.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(
                                    inlineComposerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.pmSageBorder
                                    : Color.pmSageAccentDark
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(
                            isSendingMessage ||
                            inlineComposerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .overlay(alignment: .top) {
                        Divider().overlay(Color.pmSageBorder.opacity(0.6))
                    }
                    .onTapGesture {
                        if inlineComposerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            // Keep the "hybrid" feel: tapping bar opens full chat when empty.
                            showChat = true
                        }
                    }
                } else {
                    PMSageCTAButton(title: "open settings") {
                        showSettings = true
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 8) + 8)
                }
            }
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showChat, onDismiss: {
            refreshRecentMessagesFromLocalHistory()
        }) {
            if let pet {
                ChatView(pet: pet)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ActivityView(activityItems: [image])
            }
        }
        .task {
            await loadLatestMessage()
        }
    }

    private func loadLatestMessage() async {
        isLoadingMessage = true
        defer { isLoadingMessage = false }
        do {
            // Always re-fetch the pet so expressions are fresh
            await appState.loadCurrentPet()
            guard let pet = appState.currentPet else { return }

            let localHistory = ChatHistoryStore.loadHistory(for: pet.id)
            if !localHistory.isEmpty {
                recentMessages = Array(localHistory.suffix(8))
                if let latestPetChat = localHistory.last(where: { $0.isFromPet }) {
                    latestMessage = PetMessage(
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
                latestMessage = fetchedLatest
            }
            let recent = try await SupabaseService.shared.fetchRecentMessages(for: pet.id, limit: 4)
            let mapped = recent.reversed().map {
                ChatMessage(content: $0.content, isFromPet: true, expression: $0.expression)
            }
            if localHistory.isEmpty {
                recentMessages = mapped
            }

            // Keep widget in sync: same message + correct expression sprite
            if let message = latestMessage {
                let spriteURL = pet.expressions[message.expression]
                               ?? pet.expressions[.happy]
                let d = UserDefaults(suiteName: "group.com.petmoji.app")
                d?.set(pet.name,                    forKey: "pet_name")
                d?.set(message.content,             forKey: "widget_message")
                d?.set(message.expression.rawValue, forKey: "widget_expression")
                d?.set(spriteURL,                   forKey: "widget_sprite_url")
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            // Silently fail — widget keeps showing cached data
        }
    }

    private func refreshRecentMessagesFromLocalHistory() {
        guard let pet else { return }
        let localHistory = ChatHistoryStore.loadHistory(for: pet.id)
        guard !localHistory.isEmpty else { return }
        recentMessages = Array(localHistory.suffix(8))
        if let latestPetChat = localHistory.last(where: { $0.isFromPet }) {
            latestMessage = PetMessage(
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

    private func sendInlineMessage() async {
        guard let pet else { return }
        let trimmedText = inlineComposerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        await MainActor.run {
            isSendingMessage = true
            recentMessages.append(ChatMessage(content: trimmedText, isFromPet: false, expression: nil))
            inlineComposerText = ""
            ChatHistoryStore.saveHistory(recentMessages, for: pet.id)
        }

        do {
            let response = try await ClaudeService.shared.chatReply(
                petId: pet.id,
                userMessage: trimmedText,
                conversationHistory: recentMessages
            )
            await MainActor.run {
                let reply = ChatMessage(
                    content: response.message,
                    isFromPet: true,
                    expression: response.expression
                )
                recentMessages.append(reply)
                recentMessages = Array(recentMessages.suffix(8))
                ChatHistoryStore.saveHistory(recentMessages, for: pet.id)
                isSendingMessage = false
                latestMessage = PetMessage(
                    id: UUID(),
                    petId: pet.id,
                    content: response.message,
                    expression: response.expression,
                    triggerType: .chatReply,
                    scheduledFor: Date(),
                    sentAt: Date()
                )
            }
        } catch {
            await MainActor.run {
                isSendingMessage = false
            }
        }
    }

    private func prepareShare() async {
        guard let pet = appState.currentPet,
              let urlString = pet.expressions[.happy],
              let url = URL(string: urlString) else { return }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let spriteImage = UIImage(data: data) else { return }

        let messageText = latestMessage?.content ?? pet.name
        let rendered = renderShareCard(petName: pet.name, spriteImage: spriteImage, message: messageText)

        await MainActor.run {
            shareImage = rendered
            showShareSheet = true
        }
    }

    private func renderShareCard(petName: String, spriteImage: UIImage, message: String) -> UIImage {
        let size = CGSize(width: 390, height: 390)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Background
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // Sprite centered in upper portion
            let spriteSize: CGFloat = 200
            let spriteRect = CGRect(
                x: (size.width - spriteSize) / 2,
                y: 48,
                width: spriteSize,
                height: spriteSize
            )
            spriteImage.draw(in: spriteRect)

            // Message text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let textAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: UIColor(red: 0.1, green: 0.07, blue: 0.03, alpha: 1),
                .paragraphStyle: paragraphStyle
            ]
            let textRect = CGRect(x: 24, y: 268, width: 342, height: 90)
            (message as NSString).draw(in: textRect, withAttributes: textAttrs)

            // Watermark
            let wmAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.gray
            ]
            ("petmoji" as NSString).draw(at: CGPoint(x: 318, y: 365), withAttributes: wmAttrs)
        }
    }
}

struct HomeStatusChip: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(title.lowercased())
                .font(.bodyS)
                .lineLimit(1)
        }
        .foregroundStyle(Color.pmSageTextPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.9), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.pmSageBorder.opacity(0.8), lineWidth: 1)
        )
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

// MARK: - Activity View (Share Sheet)

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.pmSageTextSecondary)
                    .frame(width: 8, height: 8)
                    .opacity(animating ? 1 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(i) * 0.18),
                        value: animating
                    )
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.pmSageBorder, lineWidth: 1.5)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { animating = true }
    }
}
