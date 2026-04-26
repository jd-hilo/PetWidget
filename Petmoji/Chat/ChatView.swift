import SwiftUI

// MARK: - Chat View

struct ChatView: View {
    let pet: Pet
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isTyping = false
    @State private var showShareSheet = false
    @State private var shareMessage: ChatMessage?

    private let suggestedReplies = [
        "what are you thinking about?",
        "hungry?",
        "want to go outside?",
        "i love you",
        "do you miss me?"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                PMSageScreenBackdrop()

                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(messages) { message in
                                    ChatBubble(message: message, pet: pet)
                                        .id(message.id)
                                        .transition(
                                            .asymmetric(
                                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                                removal: .opacity
                                            )
                                        )
                                        .contextMenu {
                                            if message.isFromPet {
                                                Button {
                                                    shareMessage = message
                                                    showShareSheet = true
                                                } label: {
                                                    Label("Share", systemImage: "square.and.arrow.up")
                                                }
                                            }
                                        }
                                }

                                if isTyping {
                                    HStack {
                                        TypingIndicator()
                                            .frame(maxWidth: 160)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .id("typing")
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            }
                            .padding(.vertical, 16)
                        }
                        .onChange(of: messages.count) { _, _ in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                proxy.scrollTo(messages.last?.id, anchor: .bottom)
                            }
                        }
                        .onChange(of: isTyping) { _, typing in
                            if typing {
                                withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                            }
                        }
                    }

                    Divider()
                        .overlay(Color.pmSageBorder.opacity(0.6))

                    if messages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(suggestedReplies, id: \.self) { reply in
                                    Button(reply) {
                                        sendMessage(reply)
                                    }
                                    .font(.bodyS)
                                    .foregroundStyle(Color.pmSageTextPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.9), in: Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.pmSageBorder.opacity(0.8), lineWidth: 1)
                                    )
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }

                    HStack(spacing: 12) {
                        TextField("say something...", text: $inputText, axis: .vertical)
                            .font(.bodyM)
                            .lineLimit(1...4)
                            .foregroundStyle(Color.pmSageTextPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Color.pmSageBorder.opacity(0.7), lineWidth: 1)
                            )

                        Button {
                            let text = inputText.trimmingCharacters(in: .whitespaces)
                            guard !text.isEmpty else { return }
                            sendMessage(text)
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(
                                    inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.pmSageBorder : Color.pmSageAccentDark
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .overlay(alignment: .top) {
                        Divider().overlay(Color.pmSageBorder.opacity(0.6))
                    }
                }
            }
            .navigationTitle(pet.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("done") { dismiss() }
                        .font(.bodyM)
                        .foregroundStyle(Color.pmSageAccentDark)
                }
                ToolbarItem(placement: .principal) {
                    // Pet avatar in nav
                    HStack(spacing: 8) {
                        SpriteImageView(urlString: pet.expressions[.happy])
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                        Text(pet.name)
                            .font(.bodyL)
                            .foregroundStyle(Color.pmSageTextPrimary)
                    }
                }
            }
        }
        .onAppear {
            let loaded = ChatHistoryStore.loadHistory(for: pet.id)
            messages = loaded
            if loaded.isEmpty {
                Task { await sendPetOpening() }
            }
        }
        .onChange(of: messages) { _, newMessages in
            ChatHistoryStore.saveHistory(newMessages, for: pet.id)
        }
        .sheet(isPresented: $showShareSheet) {
            if let msg = shareMessage {
                ActivityView(activityItems: ["\(pet.name): \(msg.content)"])
            }
        }
    }

    // MARK: - Actions

    private func sendMessage(_ text: String) {
        let userMsg = ChatMessage(content: text, isFromPet: false, expression: nil)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            messages.append(userMsg)
        }
        inputText = ""
        Task { await getPetReply(to: text) }
    }

    private func getPetReply(to userText: String) async {
        isTyping = true
        do {
            let response = try await ClaudeService.shared.chatReply(
                petId: pet.id,
                userMessage: userText,
                conversationHistory: messages
            )
            let petMsg = ChatMessage(
                content: response.message,
                isFromPet: true,
                expression: response.expression
            )
            await MainActor.run {
                isTyping = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    messages.append(petMsg)
                }
                syncWidget(petMessage: petMsg)
            }
        } catch {
            await MainActor.run {
                isTyping = false
                let fallback = ChatMessage(content: "...", isFromPet: true, expression: .judging)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    messages.append(fallback)
                }
                syncWidget(petMessage: fallback)
            }
        }
    }

    private func sendPetOpening() async {
        isTyping = true
        try? await Task.sleep(nanoseconds: 800_000_000)
        do {
            let response = try await ClaudeService.shared.chatReply(
                petId: pet.id,
                userMessage: "say a short, in-character greeting",
                conversationHistory: []
            )
            let opening = ChatMessage(content: response.message, isFromPet: true, expression: response.expression)
            await MainActor.run {
                isTyping = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    messages.append(opening)
                }
                syncWidget(petMessage: opening)
            }
        } catch {
            await MainActor.run { isTyping = false }
        }
    }

    private func syncWidget(petMessage: ChatMessage) {
        guard petMessage.isFromPet else { return }
        let expression = petMessage.expression ?? .happy
        let synced = PetMessage(
            id: UUID(),
            petId: pet.id,
            content: petMessage.content,
            expression: expression,
            triggerType: .chatReply,
            scheduledFor: petMessage.timestamp,
            sentAt: petMessage.timestamp
        )
        WidgetSnapshotSync.writeFromPet(pet, message: synced)
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    let pet: Pet

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromPet {
                // Pet avatar
                SpriteImageView(urlString: pet.expressions[message.expression ?? .happy])
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())

                Text(message.content)
                    .font(.bodyM)
                    .foregroundStyle(Color.pmSageTextPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.pmSageWashSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxWidth: 260, alignment: .leading)

                Spacer()
            } else {
                Spacer()

                Text(message.content)
                    .font(.bodyM)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.pmSageAccentDark, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxWidth: 260, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
    }
}
