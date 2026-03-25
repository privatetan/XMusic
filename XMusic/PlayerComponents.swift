import SwiftUI

#if os(iOS)
import MediaPlayer
#endif

#if canImport(UIKit)
import UIKit
#endif

struct MiniPlayerView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if let track = player.currentTrack {
            HStack(spacing: isCompactLayout ? 10 : 14) {
                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                        player.isNowPlayingPresented.toggle()
                    }
                } label: {
                    HStack(spacing: isCompactLayout ? 10 : 14) {
                        ArtworkView(track: track, cornerRadius: 18, iconSize: 18)
                            .frame(width: artworkSize, height: artworkSize)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(track.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.86)

                            Text(track.artist)
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.65))
                                .lineLimit(1)
                        }
                        .layoutPriority(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Button {
                    player.togglePlayback()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: controlSize, height: controlSize)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    player.playNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: controlSize, height: controlSize)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(isCompactLayout ? 10 : 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var artworkSize: CGFloat {
        isCompactLayout ? 52 : 58
    }

    private var controlSize: CGFloat {
        isCompactLayout ? 40 : 42
    }
}

struct AppTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.symbol)
                            .font(.body.weight(.semibold))

                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(selectedTab == tab ? .white : Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct InlineNowPlayingPanel: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @State private var isScrubbing = false
    @State private var draftTime: Double = 0
    @State private var dragOffset: CGFloat = 0
    let close: () -> Void

    var body: some View {
        if let track = player.currentTrack {
            GeometryReader { geometry in
                let safeTop = geometry.safeAreaInsets.top
                let safeBottom = geometry.safeAreaInsets.bottom
                let horizontalPadding = min(max(geometry.size.width * 0.075, 24), 32)
                let availableHeight = geometry.size.height - safeTop - safeBottom
                let compactHeight = availableHeight < 780
                let contentWidth = max(geometry.size.width - horizontalPadding * 2, 0)
                let artworkSize = min(
                    contentWidth * 0.84,
                    compactHeight ? 224 : 300,
                    availableHeight * (compactHeight ? 0.285 : 0.315)
                )
                let topGap = max(
                    min(availableHeight * (compactHeight ? 0.028 : 0.04), compactHeight ? 18 : 26),
                    compactHeight ? 10 : 14
                )
                let infoGap = compactHeight ? 80.0 : 84.0
                let secondaryGap = compactHeight ? 14.0 : 18.0
                let controlsGap = compactHeight ? 28.0 : 34.0
                let volumeGap = compactHeight ? 40.0 : 54.0
                let bottomGap = compactHeight ? 18.0 : 20.0
                let actionIconSize = compactHeight ? 20.0 : 24.0
                let bottomPadding = max(safeBottom + (compactHeight ? 4 : 6), 10)
                let artworkTopPadding = max(safeTop + 100, 100)
                let topButtonPadding = max(safeTop + 10, 16)

                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.67, green: 0.64, blue: 0.64),
                            Color(red: 0.58, green: 0.55, blue: 0.55),
                            Color(red: 0.53, green: 0.50, blue: 0.50)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .opacity(backgroundOpacity)

                    Circle()
                        .fill(track.artwork.glow.opacity(0.10))
                        .frame(width: 560, height: 560)
                        .blur(radius: 130)
                        .offset(y: -240 + dragOffset * 0.18)

                    VStack(spacing: 0) {
                        HStack {
                            Button(action: close) {
                                HStack(spacing: 100) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .semibold))

                                    Text("返回")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .frame(height: 40)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("返回")
                            .accessibilityHint("关闭播放页")

                            Spacer(minLength: 0)
                        }
                        .padding(.top, topButtonPadding)
                        .padding(.horizontal, horizontalPadding)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .zIndex(10)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                Spacer(minLength: 0)

                                ArtworkView(track: track, cornerRadius: 26, iconSize: compactHeight ? 26 : 30)
                                    .frame(width: artworkSize, height: artworkSize)
                                    .clipped()
                                    .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 8)

                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, artworkTopPadding + topGap)

                            VStack(alignment: .leading, spacing: 0) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title)
                                        .font(.system(size: compactHeight ? 28 : 32, weight: .bold))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)
                                        .multilineTextAlignment(.leading)

                                    Text(track.artist)
                                        .font(.system(size: compactHeight ? 18 : 20, weight: .regular))
                                        .foregroundStyle(Color.white.opacity(0.88))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(1)

                                Spacer().frame(height: secondaryGap)

                                NowPlayingSliderBar(
                                    value: Binding(
                                        get: { isScrubbing ? draftTime : player.currentTime },
                                        set: { draftTime = $0 }
                                    ),
                                    range: 0...max(player.duration, 1),
                                    activeColor: Color.white.opacity(0.94),
                                    trackColor: Color.white.opacity(0.22),
                                    height: 8
                                ) { editing in
                                    isScrubbing = editing
                                    if editing {
                                        draftTime = player.currentTime
                                    } else {
                                        player.seek(to: draftTime)
                                    }
                                }
                                .frame(height: 8)
                                .frame(maxWidth: .infinity)

                                Spacer().frame(height: 10)

                                HStack {
                                    Text(format(time: isScrubbing ? draftTime : player.currentTime))
                                    Spacer()
                                    Text("-\(format(time: max(player.duration - (isScrubbing ? draftTime : player.currentTime), 0)))")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.50))
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Spacer().frame(height: controlsGap)

                                HStack {
                                    Spacer()
                                    
                                    playbackControlButton(systemName: "backward.fill", size: compactHeight ? 28 : 32, touchSize: 40) {
                                        player.playPrevious()
                                    }

                                    Spacer()

                                    playbackControlButton(systemName: player.isPlaying ? "pause.fill" : "play.fill", size: compactHeight ? 30 : 48, touchSize: 40) {
                                        player.togglePlayback()
                                    }

                                    Spacer()

                                    playbackControlButton(systemName: "forward.fill", size: compactHeight ? 28 : 32, touchSize: 40) {
                                        player.playNext()
                                    }
                                    
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)

                                Spacer().frame(height: volumeGap)

                                HStack(spacing: 16) {
                                    Image(systemName: "speaker.fill")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(Color.white.opacity(0.82))

                                    NowPlayingSliderBar(
                                        value: Binding(
                                            get: { player.volume },
                                            set: { player.setVolume($0) }
                                        ),
                                        range: 0...1,
                                        activeColor: Color.white.opacity(0.92),
                                        trackColor: Color.white.opacity(0.24),
                                        height: 8
                                    )
                                    .frame(height: 6)

                                    Image(systemName: "speaker.wave.3.fill")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(Color.white.opacity(0.82))
                                }
                                .frame(maxWidth: .infinity)
                                .background(SystemVolumeBridgeView().environmentObject(player))

                                Spacer().frame(height: bottomGap)

                                HStack {
                                    Spacer()
                                    
                                    bottomActionButton(systemName: "quote.bubble", size: actionIconSize)

                                    Spacer()

                                    bottomActionButton(systemName: "airplayaudio", size: actionIconSize)

                                    Spacer()

                                    bottomActionButton(systemName: "list.bullet", size: actionIconSize)
                                    
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                            }
                            // 歌曲信息和控制区左对齐铺满可用宽度，避免标题变长时整体居中漂移。
                            .frame(maxWidth: .infinity, alignment: .leading)
                            // 封面和文案/控制区之间保留一段垂直呼吸感。
                             .padding(.top, infoGap)
                        }
                        // 将整块滚动内容限制在我们计算出的内容宽度内，保持大屏和小屏视觉比例一致。
                        .frame(width: contentWidth, alignment: .top)
                        // 给播放页主体补上左右安全边距，避免内容贴边。
                        .padding(.horizontal, horizontalPadding)
                        // 底部给 Home Indicator 和底部操作区预留空间。
                        .padding(.bottom, bottomPadding)
                        // 至少撑满整个播放器页面高度，这样内容少时也能稳定贴顶显示。
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
                    }
                }
                // 整个播放器面板挂上拖拽关闭手势的捕获层。
                .background(dismissPanCapture)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                // 下滑时让整页跟随手指位移，形成下拉退出的反馈。
                .offset(y: dragOffset)
            }
            .ignoresSafeArea()
        }
    }

    private var backgroundOpacity: Double {
        let progress = min(max(dragOffset / 360, 0), 1)
        return 1 - Double(progress) * 0.22
    }

    @ViewBuilder
    private var dismissPanCapture: some View {
        #if canImport(UIKit)
        NowPlayingDismissPanCapture(
            onChanged: { translation in
                dragOffset = translation
            },
            onEnded: { translation, velocity in
                let shouldDismiss = translation > 120 || (translation > 44 && velocity > 900)

                if shouldDismiss {
                    close()
                } else {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
            }
        )
        #else
        Color.clear
        #endif
    }

    @ViewBuilder
    private func playbackControlButton(systemName: String, size: CGFloat, touchSize: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: touchSize, height: touchSize)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func bottomActionButton(systemName: String, size: CGFloat) -> some View {
        Button(action: {}) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.74))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    private func format(time: TimeInterval) -> String {
        guard time.isFinite else { return "0:00" }

        let whole = max(Int(time.rounded(.down)), 0)
        let minutes = whole / 60
        let seconds = whole % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

#if os(iOS)
private struct SystemVolumeBridgeView: UIViewRepresentable {
    @EnvironmentObject private var player: MusicPlayerViewModel

    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.alpha = 0.01
        volumeView.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            attachSlider(from: volumeView)
        }
        return volumeView
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        DispatchQueue.main.async {
            attachSlider(from: uiView)
        }
    }

    private func attachSlider(from volumeView: MPVolumeView) {
        guard let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first else { return }
        player.attachSystemVolumeSlider(slider)
    }
}
#endif

#if canImport(UIKit)
private struct NowPlayingDismissPanCapture: UIViewRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat, CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.attachIfNeeded(to: uiView.superview)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: NowPlayingDismissPanCapture
        private let recognizer = UIPanGestureRecognizer()
        private weak var attachedView: UIView?

        init(parent: NowPlayingDismissPanCapture) {
            self.parent = parent
            super.init()
            recognizer.addTarget(self, action: #selector(handlePan(_:)))
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
        }

        func attachIfNeeded(to view: UIView?) {
            guard attachedView !== view else { return }
            detach()

            guard let view else { return }
            view.addGestureRecognizer(recognizer)
            attachedView = view
        }

        func detach() {
            attachedView?.removeGestureRecognizer(recognizer)
            attachedView = nil
        }

        @objc
        private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: recognizer.view)
            let translationY = max(translation.y, 0)
            let velocityY = recognizer.velocity(in: recognizer.view).y

            switch recognizer.state {
            case .changed:
                parent.onChanged(translationY)
            case .ended:
                parent.onEnded(translationY, velocityY)
            case .cancelled, .failed:
                parent.onEnded(0, 0)
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let recognizer = gestureRecognizer as? UIPanGestureRecognizer,
                  let attachedView else {
                return false
            }

            let velocity = recognizer.velocity(in: attachedView)
            return velocity.y > abs(velocity.x) && velocity.y > 0
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
#endif

private struct NowPlayingSliderBar: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let activeColor: Color
    let trackColor: Color
    let height: CGFloat
    let onEditingChanged: ((Bool) -> Void)?

    @State private var isDragging = false

    init(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        activeColor: Color,
        trackColor: Color,
        height: CGFloat,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        _value = value
        self.range = range
        self.activeColor = activeColor
        self.trackColor = trackColor
        self.height = height
        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        GeometryReader { geometry in
            let progress = CGFloat(normalizedProgress)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)

                Capsule()
                    .fill(activeColor)
                    .frame(width: geometry.size.width * progress)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged?(true)
                        }

                        let width = max(geometry.size.width, 1)
                        let ratio = min(max(gesture.location.x / width, 0), 1)
                        value = range.lowerBound + (range.upperBound - range.lowerBound) * ratio
                    }
                    .onEnded { _ in
                        if isDragging {
                            isDragging = false
                            onEditingChanged?(false)
                        }
                    }
            )
        }
        .frame(height: height)
    }

    private var normalizedProgress: Double {
        let span = max(range.upperBound - range.lowerBound, 0.0001)
        return min(max((value - range.lowerBound) / span, 0), 1)
    }
}
