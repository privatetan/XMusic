import SwiftUI

#if os(iOS)
import MediaPlayer
#endif

#if canImport(UIKit)
import UIKit
#endif

/// GeometryProxy 在转场动画期间可能返回 .zero 或不正确的尺寸。
/// 此包装器在 proxy 的值无效时使用外部传入的稳定 fallback 值。
private struct StableGeometry {
    let size: CGSize
    let safeAreaInsets: EdgeInsets

    init(proposed: GeometryProxy, fallbackSize: CGSize) {
        let s = proposed.size
        // 视图处于转场动画中时 size 可能为 0 或极小值。
        if s.width > 10 && s.height > 10 {
            size = s
            safeAreaInsets = proposed.safeAreaInsets
        } else {
            size = fallbackSize.width > 10 && fallbackSize.height > 10
                ? fallbackSize
                : UIScreen.main.bounds.size
            safeAreaInsets = proposed.safeAreaInsets
        }
    }
}

struct MiniPlayerView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if let track = player.currentTrack {
            HStack(spacing: isCompactLayout ? 10 : 14) {
                Button {
                    player.presentNowPlaying()
                } label: {
                    HStack(spacing: isCompactLayout ? 10 : 14) {
                        ArtworkView(track: track, cornerRadius: 18, iconSize: 18)
                            .frame(width: artworkSize, height: artworkSize)

                        VStack(alignment: .leading, spacing: 3) {
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
                        .background(miniPlayerControlBackground())
                }
                .buttonStyle(.plain)

                Button {
                    player.playNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: controlSize, height: controlSize)
                        .background(miniPlayerControlBackground())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, isCompactLayout ? 10 : 12)
            .frame(height: barHeight)
            .background(miniPlayerBackground())
            .overlay(miniPlayerOutline())
        }
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var artworkSize: CGFloat {
        ChromeBarMetrics.miniPlayerArtworkSize(for: horizontalSizeClass)
    }

    private var controlSize: CGFloat {
        ChromeBarMetrics.miniPlayerControlSize(for: horizontalSizeClass)
    }

    private var barHeight: CGFloat {
        ChromeBarMetrics.height(for: horizontalSizeClass)
    }

    @ViewBuilder
    private func miniPlayerBackground() -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: shape)
                .overlay {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
        } else {
            shape.fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func miniPlayerOutline() -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(Color.white.opacity(0.1), lineWidth: 1)
    }

    @ViewBuilder
    private func miniPlayerControlBackground() -> some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: Circle())
                .overlay {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                }
        } else {
            Circle()
                .fill(Color.white.opacity(0.08))
        }
    }
}

struct AppTabBar: View {
    @Binding var selectedTab: AppTab
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Namespace private var navigationAnimation
    private let activeColor = Color(red: 0.50, green: 0.52, blue: 1.0)

    var body: some View {
        HStack(spacing: isCompactLayout ? 12 : 16) {
            HStack(spacing: isCompactLayout ? 4 : 6) {
                ForEach(AppTab.mainNavigationTabs) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(.horizontal, isCompactLayout ? 3 : 4)
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)
            .background(tabClusterBackground())
            .overlay(tabClusterOutline())
            .shadow(color: tabClusterShadowColor, radius: 18, x: 0, y: 8)

            tabButton(for: .search, isSearchShortcut: true)
        }
    }

    private func tabButton(for tab: AppTab, isSearchShortcut: Bool = false) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                selectedTab = tab
            }
        } label: {
            if isSearchShortcut {
                Image(systemName: tab.symbol)
                    .font(.system(size: isCompactLayout ? 22 : 24, weight: .semibold))
                    .foregroundStyle(isSelected ? activeColor : .white)
                    .frame(width: barHeight, height: barHeight)
                    .background(searchButtonBackground(isSelected: isSelected))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(isSelected ? 0.18 : 0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
            } else {
                VStack(spacing: 3) {
                    Image(systemName: tab.symbol)
                        .font(.system(size: isSelected ? 18 : 16, weight: .semibold))

                    Text(tab.title)
                        .font(.system(size: isCompactLayout ? 10 : 11, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(isSelected ? activeColor : Color.white.opacity(0.88))
                .frame(maxWidth: .infinity)
                .frame(height: tabItemHeight)
                .background {
                    if isSelected {
                        selectedTabBackground()
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var tabItemHeight: CGFloat {
        ChromeBarMetrics.tabItemHeight(for: horizontalSizeClass)
    }

    private var barHeight: CGFloat {
        ChromeBarMetrics.height(for: horizontalSizeClass)
    }

    @ViewBuilder
    private func searchButtonBackground(isSelected: Bool) -> some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: Circle())
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isSelected
                                    ? [activeColor.opacity(0.22), Color.white.opacity(0.10)]
                                    : [Color.white.opacity(0.08), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        } else {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isSelected
                                    ? [Color.white.opacity(0.16), Color.white.opacity(0.06)]
                                    : [Color.white.opacity(0.08), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
        }
    }

    @ViewBuilder
    private func tabClusterBackground() -> some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: Capsule())
                .overlay {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func tabClusterOutline() -> some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
        } else {
            Capsule()
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func selectedTabBackground() -> some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: Capsule())
                .overlay {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [activeColor.opacity(0.16), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.horizontal, 0.5)
                .padding(.vertical, 1)
                .matchedGeometryEffect(id: "tab-selection", in: navigationAnimation)
        } else {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .padding(.horizontal, 0.5)
                .padding(.vertical, 1)
                .matchedGeometryEffect(id: "tab-selection", in: navigationAnimation)
        }
    }

    private var tabClusterShadowColor: Color {
        if #available(iOS 26.0, *) {
            return Color.black.opacity(0.14)
        }
        return Color.black.opacity(0.22)
    }
}

struct InlineNowPlayingPanel: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @State private var isScrubbing = false
    @State private var draftTime: Double = 0
    @State private var dragOffset: CGFloat = 0
    /// 从父视图传入的稳定尺寸，避免 GeometryReader 在转场动画期间
    /// 拿到 .zero / 不正确的值导致布局卡死。
    var containerSize: CGSize = .zero
    let close: () -> Void

    var body: some View {
        if let track = player.currentTrack {
            GeometryReader { geometry in
                let geometry = StableGeometry(
                    proposed: geometry,
                    fallbackSize: containerSize
                )
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
                let topButtonPadding = max(safeTop + 2, 10)

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
                            Button {
                                dismissPanel()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.white.opacity(0.96))
                                    .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 2)
                                    .frame(width: 32, height: 32)
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
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .truncationMode(.tail)

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
                // 屏幕上半部分下滑可关闭播放页（通过背景探针挂载手势到宿主视图）。
                #if canImport(UIKit)
                .background(
                    DismissPanCapture(
                        onChanged: { dragOffset = $0 },
                        onEnded: { ty, vy in
                            let shouldDismiss = ty > 120 || (ty > 44 && vy > 900)
                            if shouldDismiss {
                                dismissPanel()
                            } else {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                    dragOffset = 0
                                }
                            }
                        }
                    )
                )
                #endif
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                // 下滑时让整页跟随手指位移，形成下拉退出的反馈。
                .offset(y: dragOffset)
            }
            .ignoresSafeArea()
            .onAppear(perform: resetTransientPresentationState)
        }
    }

    private var backgroundOpacity: Double {
        let progress = min(max(dragOffset / 360, 0), 1)
        return 1 - Double(progress) * 0.22
    }

    private func resetTransientPresentationState() {
        isScrubbing = false
        draftTime = player.currentTime
        dragOffset = 0
    }

    private func dismissPanel() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            resetTransientPresentationState()
        }
        close()
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
/// 通过零尺寸背景探针 UIView 将 UIPanGestureRecognizer 挂载到宿主视图上，
/// 实现「屏幕上半部分下滑关闭播放页」。
///
/// 原理：
/// - 探针 view 不接收触摸（isUserInteractionEnabled = false），
///   仅用于找到包含 ScrollView 的宿主视图。
/// - 手势挂载在宿主视图上，与 ScrollView 共享触摸链。
/// - gestureRecognizerShouldBegin 只在「触摸点在屏幕上半部 + 垂直下滑」时
///   返回 true；其余情况立即失败，ScrollView / 按钮正常响应。
/// - shouldRecognizeSimultaneouslyWith 返回 true 保证 begin 阶段能
///   同时识别；一旦确认下滑，通过禁用 ScrollView 的 isScrollEnabled 来
///   独占拖拽控制，结束后恢复。
private struct DismissPanCapture: UIViewRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat, CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        // 延迟一帧以确保 SwiftUI hosting 层级已完成布局。
        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: DismissPanCapture
        private let pan = UIPanGestureRecognizer()
        private weak var attachedHost: UIView?
        private weak var scrollView: UIScrollView?
        /// 拖拽期间被禁用的 ScrollView（强引用，保证 detach 时能恢复）。
        private var disabledScrollView: UIScrollView?

        init(parent: DismissPanCapture) {
            self.parent = parent
            super.init()
            pan.addTarget(self, action: #selector(handlePan(_:)))
            pan.delegate = self
            pan.cancelsTouchesInView = false
            pan.delaysTouchesBegan = false
            pan.delaysTouchesEnded = false
        }

        // MARK: - 挂载 / 卸载

        func attachIfNeeded(from probe: UIView) {
            // 找到包含 UIScrollView 的最近祖先。
            var candidate = probe.superview
            while let c = candidate {
                if Self.findScrollView(in: c) != nil { break }
                candidate = c.superview
            }
            guard let host = candidate else { return }
            guard attachedHost !== host else { return }
            detach()

            host.addGestureRecognizer(pan)
            attachedHost = host
            scrollView = Self.findScrollView(in: host)
        }

        private func enableScrollView() {
            disabledScrollView?.isScrollEnabled = true
            disabledScrollView = nil
        }

        func detach() {
            enableScrollView()
            attachedHost?.removeGestureRecognizer(pan)
            attachedHost = nil
            scrollView = nil
        }

        // MARK: - UIScrollView 查找

        private static func findScrollView(in view: UIView) -> UIScrollView? {
            if let sv = view as? UIScrollView { return sv }
            for child in view.subviews {
                if let found = findScrollView(in: child) { return found }
            }
            return nil
        }

        // MARK: - Pan 处理

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let ty = max(recognizer.translation(in: view).y, 0)
            let vy = recognizer.velocity(in: view).y

            switch recognizer.state {
            case .began:
                disabledScrollView = scrollView
                disabledScrollView?.isScrollEnabled = false
            case .changed:
                parent.onChanged(ty)
            case .ended:
                enableScrollView()
                parent.onEnded(ty, vy)
            case .cancelled, .failed:
                enableScrollView()
                parent.onEnded(0, 0)
            default:
                break
            }
        }

        // MARK: - UIGestureRecognizerDelegate

        func gestureRecognizerShouldBegin(
            _ gestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let host = pan.view else { return false }

            // 只在屏幕上半部分起效。
            let location = pan.location(in: host)
            guard location.y < host.bounds.height / 2 else { return false }

            let v = pan.velocity(in: host)
            // 只在明确的垂直下滑时开始手势。
            return v.y > 0 && v.y > abs(v.x)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            // 允许同时识别，这样在 begin 阶段能和 ScrollView 的 pan 共存。
            // 一旦 began 触发，handlePan 会禁用 ScrollView 来独占控制。
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
