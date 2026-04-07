import SwiftUI
import WidgetKit

// MARK: - Pet Home View

struct PetHomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var latestMessage: PetMessage?
    @State private var breathe = false
    @State private var showChat = false
    @State private var isLoadingMessage = false
    @State private var showSettings = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    var pet: Pet? { appState.currentPet }

    private var spriteSize: CGFloat {
        min(UIScreen.main.bounds.width * 0.55, 260)
    }

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
        ZStack {
            Color.pmBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Greeting
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.bodyM)
                        .foregroundStyle(Color.pmTextSecondary)
                    if let pet {
                        Text(pet.name)
                            .font(.displayL)
                            .foregroundStyle(Color.pmTextPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 64)

                Spacer(minLength: 20)

                // Speech bubble + share
                if let message = latestMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        SpeechBubble(message: message.content)

                        Button {
                            Task { await prepareShare() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 13))
                                Text("share")
                                    .font(.bodyS)
                            }
                            .foregroundStyle(Color.pmTextSecondary)
                        }
                        .padding(.leading, 4)
                        .padding(.bottom, 12)
                    }
                    .padding(.horizontal, 24)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.7, anchor: .bottomLeading)
                                .combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                } else if isLoadingMessage {
                    TypingIndicator()
                        .padding(.horizontal, 24)
                }

                // Floating pet sprite with breathing animation
                // Falls back to happy if the message expression sprite isn't generated yet
                if let pet {
                    let expression = latestMessage?.expression ?? .happy
                    let spriteURL = pet.expressions[expression] ?? pet.expressions[.happy]
                    SpriteImageView(urlString: spriteURL)
                        .frame(width: spriteSize, height: spriteSize)
                        .scaleEffect(breathe ? 1.03 : 1.0)
                        .animation(
                            .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                            value: breathe
                        )
                        .onAppear { breathe = true }
                }

                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let pet {
                PMPrimaryButton(title: "talk to \(pet.name)") {
                    showChat = true
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .padding(.top, 8)
                .background(Color.pmBackground.opacity(0.95))
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.pmTextSecondary)
                    .padding(24)
                    .padding(.top, 48)
            }
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showChat) {
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

            latestMessage = try await SupabaseService.shared.fetchLatestMessage(for: pet.id)

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
                    .fill(Color.pmTextSecondary)
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
                .strokeBorder(Color.pmBorder, lineWidth: 1.5)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { animating = true }
    }
}
