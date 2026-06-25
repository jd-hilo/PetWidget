import SwiftUI
import AVFoundation

// MARK: - Onboarding Looping Video Player

struct OnboardingLoopingVideoPlayer: View {
    let resourceName: String
    var resourceExtension: String = "mov"
    let maxWidth: CGFloat
    let maxHeight: CGFloat
    var cornerRadius: CGFloat = 24
    var accessibilityLabel: String

    @State private var player: AVPlayer?
    @State private var videoSize: CGSize?

    private var bundledURL: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: resourceExtension)
    }

    private var displaySize: CGSize {
        let sourceWidth = videoSize?.width ?? 9
        let sourceHeight = videoSize?.height ?? 16
        guard sourceWidth > 0, sourceHeight > 0, maxWidth > 0, maxHeight > 0 else {
            return CGSize(width: maxWidth, height: min(maxWidth * 16 / 9, maxHeight))
        }

        let scale = min(maxWidth / sourceWidth, maxHeight / sourceHeight)
        return CGSize(width: sourceWidth * scale, height: sourceHeight * scale)
    }

    var body: some View {
        Group {
            if bundledURL != nil {
                OnboardingAspectFitVideoPlayerView(
                    player: player,
                    cornerRadius: cornerRadius,
                    onVideoSizeChange: { size in
                        guard size.width > 0, size.height > 0 else { return }
                        videoSize = size
                    }
                )
            } else {
                OnboardingVideoUnavailablePlaceholder(cornerRadius: cornerRadius)
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .frame(maxWidth: .infinity)
        .accessibilityLabel(accessibilityLabel)
        .onAppear(perform: configurePlayerIfNeeded)
        .onDisappear {
            player?.pause()
        }
    }

    private func configurePlayerIfNeeded() {
        guard player == nil, let url = bundledURL else { return }
        let avPlayer = AVPlayer(url: url)
        avPlayer.isMuted = true
        avPlayer.actionAtItemEnd = .none
        player = avPlayer
        avPlayer.play()
    }
}

// MARK: - UIViewRepresentable

private struct OnboardingAspectFitVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer?
    let cornerRadius: CGFloat
    var onVideoSizeChange: (CGSize) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onVideoSizeChange: onVideoSizeChange)
    }

    func makeUIView(context: Context) -> OnboardingPlayerContainerView {
        let view = OnboardingPlayerContainerView(cornerRadius: cornerRadius)
        view.isUserInteractionEnabled = false
        context.coordinator.bind(player: player, to: view)
        return view
    }

    func updateUIView(_ uiView: OnboardingPlayerContainerView, context: Context) {
        uiView.cornerRadius = cornerRadius
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

        func bind(player: AVPlayer?, to view: OnboardingPlayerContainerView) {
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

private final class OnboardingPlayerContainerView: UIView {
    let playerLayer = AVPlayerLayer()
    var onLayoutVideoSize: ((CGSize) -> Void)?
    var cornerRadius: CGFloat {
        didSet { applyCornerRadius() }
    }

    init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        backgroundColor = .clear
        clipsToBounds = true
        layer.addSublayer(playerLayer)
        applyCornerRadius()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyCornerRadius()
        layoutAspectFitPlayerLayer()
    }

    private func applyCornerRadius() {
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        playerLayer.cornerRadius = cornerRadius
        playerLayer.masksToBounds = true
    }

    private func layoutAspectFitPlayerLayer() {
        let containerSize = bounds.size
        guard containerSize.width > 0, containerSize.height > 0 else { return }

        if let videoSize = presentationVideoSize,
           videoSize.width > 0,
           videoSize.height > 0 {
            onLayoutVideoSize?(videoSize)
        }

        playerLayer.frame = bounds
        playerLayer.videoGravity = .resizeAspect
    }

    private var presentationVideoSize: CGSize? {
        guard let track = playerLayer.player?.currentItem?.asset.tracks(withMediaType: .video).first else {
            return nil
        }
        let transformed = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(transformed.width), height: abs(transformed.height))
    }
}

private struct OnboardingVideoUnavailablePlaceholder: View {
    @Environment(\.petmojiPalette) private var palette

    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
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
