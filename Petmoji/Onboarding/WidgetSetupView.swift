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
            title: "Long-press the Home Screen",
            description: "Hold any empty area until the apps start to jiggle."
        ),
        WidgetSetupStep(
            number: 2,
            title: "Tap the + button",
            description: "You'll find it in the top-left corner of the screen."
        ),
        WidgetSetupStep(
            number: 3,
            title: "Search for \"Petmoji\"",
            description: "Look it up in the widget gallery."
        ),
        WidgetSetupStep(
            number: 4,
            title: "Add your widget",
            description: "Pick a favorite layout, then tap Add Widget."
        )
    ]

    private static let stepRowHeight: CGFloat = 48
    private static let stepSpacing: CGFloat = 12

    private func videoMaxHeight(in availableHeight: CGFloat) -> CGFloat {
        let stepsBlockHeight = CGFloat(steps.count) * Self.stepRowHeight
            + CGFloat(steps.count - 1) * Self.stepSpacing
        let chrome: CGFloat = 8 + 12
        return max(120, availableHeight - stepsBlockHeight - chrome)
    }

    var body: some View {
        ZStack {
            PMSageScreenBackdrop()

            GeometryReader { geo in
                let contentWidth = geo.size.width - 48
                let maxVideoHeight = videoMaxHeight(in: geo.size.height)

                VStack(alignment: .leading, spacing: 12) {
                    WidgetSetupVideoPlayer(
                        maxWidth: contentWidth,
                        maxHeight: maxVideoHeight
                    )
                    .frame(maxWidth: .infinity)

                    VStack(spacing: Self.stepSpacing) {
                        ForEach(steps) { step in
                            WidgetSetupStepRow(step: step)
                                .frame(height: Self.stepRowHeight)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
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
    let title: String
    let description: String

    var id: Int { number }
}

// MARK: - Video Player

private enum WidgetSetupVideo {
    static let resourceName = "WidgetScreenDemo"
    static let resourceExtension = "mov"
    static let cornerRadius: CGFloat = 24
    static var bundledURL: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: resourceExtension)
    }
}

private struct WidgetSetupVideoPlayer: View {
    @State private var player: AVPlayer?
    @State private var videoSize: CGSize?

    let maxWidth: CGFloat
    let maxHeight: CGFloat

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
            if WidgetSetupVideo.bundledURL != nil {
                WidgetSetupAspectFitVideoPlayerView(
                    player: player,
                    cornerRadius: WidgetSetupVideo.cornerRadius,
                    onVideoSizeChange: { size in
                        guard size.width > 0, size.height > 0 else { return }
                        videoSize = size
                    }
                )
            } else {
                WidgetSetupVideoUnavailablePlaceholder()
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .clipShape(RoundedRectangle(cornerRadius: WidgetSetupVideo.cornerRadius, style: .continuous))
        .frame(maxWidth: .infinity)
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
    let cornerRadius: CGFloat
    var onVideoSizeChange: (CGSize) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onVideoSizeChange: onVideoSizeChange)
    }

    func makeUIView(context: Context) -> WidgetSetupPlayerContainerView {
        let view = WidgetSetupPlayerContainerView(cornerRadius: cornerRadius)
        view.isUserInteractionEnabled = false
        context.coordinator.bind(player: player, to: view)
        return view
    }

    func updateUIView(_ uiView: WidgetSetupPlayerContainerView, context: Context) {
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

private struct WidgetSetupVideoUnavailablePlaceholder: View {
    @Environment(\.petmojiPalette) private var palette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: WidgetSetupVideo.cornerRadius, style: .continuous)
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

// MARK: - Step Row

private struct WidgetSetupStepRow: View {
    @Environment(\.petmojiPalette) private var palette

    let step: WidgetSetupStep

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(step.number)")
                .font(.bodyM.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(palette.accent, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.bodyL)
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(step.description)
                    .font(.bodyS)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
