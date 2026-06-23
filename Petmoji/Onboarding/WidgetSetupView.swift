import SwiftUI
import AVFoundation

// MARK: - Widget Setup View

struct WidgetSetupView: View {
    @Environment(\.petmojiPalette) private var palette

    let onNext: () -> Void
    var onCancel: (() -> Void)?

    private let steps: [WidgetSetupStep] = [
        WidgetSetupStep(
            number: 1,
            prefix: "Long press on any empty area of your ",
            highlight: "Home Screen",
            suffix: " until apps jiggle."
        ),
        WidgetSetupStep(
            number: 2,
            prefix: "Tap the ",
            highlight: "+",
            suffix: " button in the top left corner."
        ),
        WidgetSetupStep(
            number: 3,
            prefix: "Search for ",
            highlight: "Petmoji",
            suffix: " in the widget gallery."
        ),
        WidgetSetupStep(
            number: 4,
            prefix: "Choose your favorite layout and tap ",
            highlight: "Add Widget",
            suffix: "."
        )
    ]

    var body: some View {
        ZStack {
            PMSageScreenBackdrop()

            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        WidgetSetupVideoPlayer(
                            maxWidth: geo.size.width - 48,
                            maxHeight: geo.size.height * 0.5
                        )
                        .padding(.top, 8)

                        Text("how to setup")
                            .font(.titleL)
                            .foregroundStyle(palette.accentDark)

                        VStack(spacing: 8) {
                            ForEach(steps) { step in
                                WidgetSetupStepCard(step: step)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, onCancel != nil ? 16 : 96)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 12) {
            VStack(spacing: 12) {
                PMSageCTAButton(
                    title: "next: location tracking →",
                    action: onNext
                )

                Text("You can always add this later from settings")
                    .font(.bodyS)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                if let onCancel {
                    PMOnboardingCancelButton(action: onCancel)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
            .background(Color.clear)
        }
        .pmOnboardingScreenTitle("set up the widget")
    }
}

// MARK: - Step Model

private struct WidgetSetupStep: Identifiable {
    let number: Int
    let prefix: String
    let highlight: String
    let suffix: String

    var id: Int { number }
}

// MARK: - Video Player

private enum WidgetSetupVideo {
    static let resourceName = "WidgetSetup"
    static let resourceExtension = "mov"
    static var bundledURL: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: resourceExtension)
    }
}

private struct WidgetSetupVideoPlayer: View {
    @Environment(\.petmojiPalette) private var palette
    @State private var player: AVPlayer?
    @State private var videoSize: CGSize?

    let maxWidth: CGFloat
    let maxHeight: CGFloat

    private var displaySize: CGSize {
        let sourceWidth = videoSize?.width ?? 9
        let sourceHeight = videoSize?.height ?? 16
        guard sourceWidth > 0, sourceHeight > 0, maxWidth > 0, maxHeight > 0 else {
            return CGSize(width: maxWidth, height: maxHeight)
        }

        let scale = min(maxWidth / sourceWidth, maxHeight / sourceHeight)
        return CGSize(width: sourceWidth * scale, height: sourceHeight * scale)
    }

    var body: some View {
        Group {
            if WidgetSetupVideo.bundledURL != nil {
                WidgetSetupAspectFitVideoPlayerView(
                    player: player,
                    onVideoSizeChange: { size in
                        guard size.width > 0, size.height > 0 else { return }
                        videoSize = size
                    }
                )
            } else {
                WidgetSetupVideoUnavailablePlaceholder()
                    .frame(width: displaySize.width, height: displaySize.height)
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(palette.elevatedCardStroke, lineWidth: 1.2)
        )
        .accessibilityLabel("Widget setup walkthrough video")
        .onAppear(perform: configurePlayerIfNeeded)
        .onDisappear {
            player?.pause()
        }
    }

    private func configurePlayerIfNeeded() {
        guard player == nil, let url = WidgetSetupVideo.bundledURL else { return }
        let avPlayer = AVPlayer(url: url)
        avPlayer.isMuted = true
        avPlayer.actionAtItemEnd = .none
        player = avPlayer
        avPlayer.play()
    }
}

private struct WidgetSetupAspectFitVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer?
    var onVideoSizeChange: (CGSize) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onVideoSizeChange: onVideoSizeChange)
    }

    func makeUIView(context: Context) -> WidgetSetupPlayerContainerView {
        let view = WidgetSetupPlayerContainerView()
        view.isUserInteractionEnabled = false
        view.clipsToBounds = true
        context.coordinator.bind(player: player, to: view)
        return view
    }

    func updateUIView(_ uiView: WidgetSetupPlayerContainerView, context: Context) {
        context.coordinator.bind(player: player, to: uiView)
    }

    final class Coordinator {
        private var statusObservation: NSKeyValueObservation?
        private var endObservation: NSObjectProtocol?
        private let onVideoSizeChange: (CGSize) -> Void
        private var reportedVideoSize: CGSize?

        init(onVideoSizeChange: @escaping (CGSize) -> Void) {
            self.onVideoSizeChange = onVideoSizeChange
        }

        func bind(player: AVPlayer?, to view: WidgetSetupPlayerContainerView) {
            statusObservation?.invalidate()
            if let endObservation {
                NotificationCenter.default.removeObserver(endObservation)
                self.endObservation = nil
            }

            view.playerLayer.player = player
            view.onLayoutVideoSize = { [weak self] size in
                guard let self, size != self.reportedVideoSize else { return }
                self.reportedVideoSize = size
                self.onVideoSizeChange(size)
            }
            view.setNeedsLayout()

            guard let item = player?.currentItem else { return }

            endObservation = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }

            let layoutAndPlay = { [weak view, weak player] in
                view?.setNeedsLayout()
                player?.play()
            }

            if item.status == .readyToPlay {
                layoutAndPlay()
            }

            statusObservation = item.observe(\.status, options: [.new]) { item, _ in
                guard item.status == .readyToPlay else { return }
                DispatchQueue.main.async(execute: layoutAndPlay)
            }
        }
    }
}

private final class WidgetSetupPlayerContainerView: UIView {
    let playerLayer = AVPlayerLayer()
    var onLayoutVideoSize: ((CGSize) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        layer.addSublayer(playerLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutAspectFitPlayerLayer()
    }

    private func layoutAspectFitPlayerLayer() {
        let containerSize = bounds.size
        guard containerSize.width > 0, containerSize.height > 0 else { return }

        guard let videoSize = presentationVideoSize,
              videoSize.width > 0,
              videoSize.height > 0 else {
            playerLayer.frame = bounds
            playerLayer.videoGravity = .resizeAspect
            return
        }

        onLayoutVideoSize?(videoSize)

        let fitScale = min(
            containerSize.width / videoSize.width,
            containerSize.height / videoSize.height
        )
        let scaledWidth = videoSize.width * fitScale
        let scaledHeight = videoSize.height * fitScale

        playerLayer.videoGravity = .resizeAspect
        playerLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        playerLayer.position = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        playerLayer.bounds = CGRect(
            x: 0,
            y: 0,
            width: scaledWidth,
            height: scaledHeight
        )
    }

    private var presentationVideoSize: CGSize? {
        guard let track = playerLayer.player?.currentItem?.asset.tracks(withMediaType: .video).first else {
            return nil
        }
        let transformed = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(transformed.width), height: abs(transformed.height))
    }
}

private struct WidgetSetupVideoUnavailablePlaceholder: View {
    @Environment(\.petmojiPalette) private var palette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.elevatedCardFill)

            VStack(spacing: 8) {
                Image(systemName: "play.slash.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(palette.textSecondary)
                Text("Video unavailable")
                    .font(.bodyS)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }
}

// MARK: - Step Card

private struct WidgetSetupStepCard: View {
    @Environment(\.petmojiPalette) private var palette

    let step: WidgetSetupStep

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("\(step.number)")
                .font(.bodyL)
                .foregroundStyle(palette.accentDark)
                .frame(width: 28, height: 28)
                .background(palette.accent, in: Circle())

            (
                Text(step.prefix)
                    .foregroundStyle(palette.textPrimary)
                + Text(step.highlight)
                    .foregroundStyle(palette.accentDark)
                + Text(step.suffix)
                    .foregroundStyle(palette.textPrimary)
            )
            .font(.bodyS)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.elevatedCardStroke.opacity(0.8), lineWidth: 1)
        )
    }
}
