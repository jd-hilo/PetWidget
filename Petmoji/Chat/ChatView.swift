import SwiftUI

// MARK: - Chat Panel (embeddable)

struct ChatPanel: View {
    let pet: Pet

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isTyping = false
    @State private var showShareSheet = false
    @State private var shareMessage: ChatMessage?
    @FocusState private var isInputFocused: Bool

    var body: some View {
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

                    Color.clear
                        .frame(height: 1)
                        .id("chatBottomAnchor")
                }
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider()
                        .overlay(Color.pmSageBorder.opacity(0.6))

                    HStack(spacing: 12) {
                        TextField("say something...", text: $inputText, axis: .vertical)
                            .font(.bodyM)
                            .lineLimit(1...4)
                            .foregroundStyle(Color.pmSageTextPrimary)
                            .focused($isInputFocused)
                            .onSubmit { submitFromKeyboard() }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Color.pmSageBorder.opacity(0.7), lineWidth: 1)
                            )

                        Button {
                            submitFromKeyboard()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(
                                    inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? Color.pmSageBorder : Color.pmSageTextPrimary
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                }
                .background(.ultraThinMaterial)
            }
            .onChange(of: messages.count) { _, _ in
                scrollChatToEnd(proxy: proxy)
            }
            .onChange(of: isTyping) { _, typing in
                if typing {
                    scrollChatToEnd(proxy: proxy, preferTyping: true)
                } else {
                    scrollChatToEnd(proxy: proxy)
                }
            }
            .onChange(of: isInputFocused) { _, focused in
                if focused {
                    scrollChatToEnd(proxy: proxy, delay: 0.32)
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

    private func scrollChatToEnd(proxy: ScrollViewProxy, preferTyping: Bool = false, delay: TimeInterval = 0) {
        func snapToEnd() {
            if preferTyping, isTyping {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    proxy.scrollTo("typing", anchor: .bottom)
                }
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    proxy.scrollTo("chatBottomAnchor", anchor: .bottom)
                }
            }
        }
        let run = {
            snapToEnd()
            if !(preferTyping && self.isTyping) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    withAnimation(.easeOut(duration: 0.22)) {
                        if self.isTyping {
                            proxy.scrollTo("typing", anchor: .bottom)
                        } else {
                            proxy.scrollTo("chatBottomAnchor", anchor: .bottom)
                        }
                    }
                }
            }
        }
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: run)
        } else {
            DispatchQueue.main.async(execute: run)
        }
    }

    private func submitFromKeyboard() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sendMessage(text)
    }

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
