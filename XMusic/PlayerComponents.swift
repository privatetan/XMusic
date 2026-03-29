import Foundation
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
    let animation: Namespace.ID

    var body: some View {
        if let track = player.currentTrack {
            HStack(spacing: isCompactLayout ? 10 : 14) {
                Button {
                    player.presentNowPlaying()
                } label: {
                    HStack(spacing: isCompactLayout ? 10 : 14) {
                        ArtworkView(track: track, cornerRadius: 18, iconSize: 18)
                            .frame(width: artworkSize, height: artworkSize)
                            .matchedGeometryEffect(id: "Artwork", in: animation)

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
                .matchedGeometryEffect(id: "PlayerBackground", in: animation)
        } else {
            shape.fill(.ultraThinMaterial)
                .matchedGeometryEffect(id: "PlayerBackground", in: animation)
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
    @Binding var searchQuery: String
    var isSearchFieldFocused: FocusState<Bool>.Binding
    var onSearchSubmit: (() -> Void)? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Namespace private var navigationAnimation
    private let activeColor = Color(red: 0.50, green: 0.52, blue: 1.0)

    private var isSearchMode: Bool { selectedTab == .search }

    var body: some View {
        HStack(spacing: isCompactLayout ? 12 : 16) {
            // Left cluster: full tabs OR collapsed home button
            if isSearchMode {
                // Collapsed: single round "home" button
                Button {
                    isSearchFieldFocused.wrappedValue = false
                    withAnimation(.spring(response: 0.40, dampingFraction: 0.80)) {
                        selectedTab = .browse
                    }
                } label: {
                    Image(systemName: "house.fill")
                        .font(.system(size: isCompactLayout ? 20 : 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: barHeight, height: barHeight)
                        .background(searchButtonBackground(isSelected: false))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .shadow(color: tabClusterShadowColor, radius: 18, x: 0, y: 8)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else {
                // Expanded: normal tab cluster
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
                .transition(.scale(scale: 0.8, anchor: .leading).combined(with: .opacity))
            }

            // Right side: search button OR stretched search field
            if isSearchMode {
                // Stretched search field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))

                    TextField("搜索歌名、艺人、专辑", text: $searchQuery)
                        .focused(isSearchFieldFocused)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .medium))
                        .submitLabel(.search)
                        .onSubmit { onSearchSubmit?() }

                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: barHeight)
                .background(searchFieldBackground())
                .overlay(searchFieldOutline())
                .shadow(color: tabClusterShadowColor, radius: 18, x: 0, y: 8)
                .transition(.scale(scale: 0.5, anchor: .trailing).combined(with: .opacity))
            } else {
                // Normal search button
                tabButton(for: .search, isSearchShortcut: true)
                    .transition(.scale(scale: 0.5, anchor: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.40, dampingFraction: 0.80), value: isSearchMode)
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

    @ViewBuilder
    private func searchFieldBackground() -> some View {
        let shape = Capsule()
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
            shape.fill(Color.white.opacity(0.08))
        }
    }

    @ViewBuilder
    private func searchFieldOutline() -> some View {
        Capsule()
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    @State private var isScrubbing = false
    @State private var draftTime: Double = 0
    @State private var dragOffset: CGFloat = 0
    @State private var showContent = true
    @State private var isLyricsPresented = false
    @State private var isLoadingLyrics = false
    @State private var lyricsStateTrackID: UUID?
    @State private var loadedLyricsTrackID: UUID?
    @State private var lyricResult: MusicSourceLyricResult?
    @State private var lyricsErrorMessage: String?
    let animation: Namespace.ID
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
                    RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.67, green: 0.64, blue: 0.64),
                                    Color(red: 0.58, green: 0.55, blue: 0.55),
                                    Color(red: 0.53, green: 0.50, blue: 0.50)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .matchedGeometryEffect(id: "PlayerBackground", in: animation)
                        .ignoresSafeArea()
                        .scaleEffect(x: currentScaleX, y: currentScaleY)
                        .opacity(backgroundOpacity)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                Spacer(minLength: 0)

                                ArtworkView(track: track, cornerRadius: 26, iconSize: compactHeight ? 26 : 30)
                                    .frame(width: artworkSize, height: artworkSize)
                                    .matchedGeometryEffect(id: "Artwork", in: animation)
                                    .clipped()
                                    .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 8)

                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, artworkTopPadding + topGap)
                            .scaleEffect(1.0 - (squeezeProgress * 0.08)) // 封面随下拉略微缩小

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
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 20)
                                .scaleEffect(x: 1.0 - (squeezeProgress * 0.12), y: 1.0)

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
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 20)
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
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 22)

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
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 24)

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
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 25)

                                Spacer().frame(height: bottomGap)

                                HStack {
                                    Spacer()
                                    
                                    bottomActionButton(
                                        systemName: "quote.bubble",
                                        size: actionIconSize,
                                        isActive: isLyricsPresented
                                    ) {
                                        handleLyricsButtonTap(for: track)
                                    }

                                    Spacer()

                                    bottomActionButton(systemName: "airplayaudio", size: actionIconSize) {
                                    }

                                    Spacer()

                                    bottomActionButton(systemName: "list.bullet", size: actionIconSize) {
                                    }
                                    
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 30)
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

                    // 按钮层放在最上方，确保点击优先级
                    VStack(spacing: 0) {
                        HStack {
                            Button {
                                dismissPanel()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.white.opacity(0.96))
                                    .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 2)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("返回")
                            .accessibilityHint("关闭播放页")
                            .opacity(showContent ? 1 : 0)

                            Spacer(minLength: 0)
                        }
                        .padding(.top, topButtonPadding)
                        .padding(.horizontal, horizontalPadding)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(true)
                    .zIndex(100)

                    // 装饰层
                    Circle()
                        .fill(track.artwork.glow.opacity(0.10))
                        .frame(width: 560, height: 560)
                        .blur(radius: 130)
                        .offset(y: -240 + dragOffset * 0.18)
                        .opacity(showContent ? 1 : 0)
                        .allowsHitTesting(false)

                    if isLyricsPresented {
                        lyricsOverlay(
                            for: track,
                            availableHeight: availableHeight,
                            horizontalPadding: horizontalPadding,
                            safeBottom: safeBottom,
                            compactHeight: compactHeight
                        )
                        .zIndex(120)
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
                .onChange(of: track.id) { _ in
                    handleTrackChange(track)
                }
                .onDisappear {
                    resetLyricsState()
                }
            }
            .ignoresSafeArea()
            .onAppear(perform: resetTransientPresentationState)
        }
    }

    private var backgroundOpacity: Double {
        let progress = min(max(dragOffset / 360, 0), 1)
        return 1 - Double(progress) * 0.22
    }

    private var squeezeProgress: CGFloat {
        let threshold: CGFloat = 420
        return min(max(dragOffset / threshold, 0), 1)
    }

    private var currentScaleX: CGFloat {
        let baseScale: CGFloat = showContent ? 1.0 : 0.82
        return baseScale - (squeezeProgress * 0.18)
    }

    private var currentScaleY: CGFloat {
        let baseScale: CGFloat = showContent ? 1.0 : 0.96
        return baseScale - (squeezeProgress * 0.04)
    }

    private var currentCornerRadius: CGFloat {
        let baseRadius: CGFloat = showContent ? 48 : 28
        return baseRadius - (squeezeProgress * 20)
    }

    private func resetTransientPresentationState() {
        isScrubbing = false
        draftTime = player.currentTime
        dragOffset = 0
        
        // 仅在首次挂载或 ID 变化时触发入场效果
        showContent = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.45).delay(0.1)) {
                showContent = true
            }
        }
    }

    private func dismissPanel() {
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
    private func bottomActionButton(
        systemName: String,
        size: CGFloat,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(Color.white.opacity(isActive ? 0.96 : 0.74))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isActive ? 0.14 : 0.001))
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func lyricsOverlay(
        for track: Track,
        availableHeight: CGFloat,
        horizontalPadding: CGFloat,
        safeBottom: CGFloat,
        compactHeight: Bool
    ) -> some View {
        let panelHeight = min(max(availableHeight * (compactHeight ? 0.60 : 0.64), 320), compactHeight ? 450 : 540)
        let lines = cleanedLyricLines(for: track)

        ZStack(alignment: .bottom) {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        isLyricsPresented = false
                    }
                }

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.20))
                    .frame(width: 42, height: 5)
                    .padding(.top, 12)

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("歌词")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("\(track.title) · \(track.artist)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.58))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    if isLoadingLyrics, lyricsStateTrackID == track.id {
                        ProgressView()
                            .tint(.white)
                    }

                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            isLyricsPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.82))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 18)

                Group {
                    if isLoadingLyrics, lyricsStateTrackID == track.id {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                            Text("正在加载歌词…")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.72))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if lyricsStateTrackID == track.id, let lyricsErrorMessage {
                        VStack(spacing: 14) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 28, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.78))

                            Text(lyricsErrorMessage)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.72))
                                .multilineTextAlignment(.center)

                            Button {
                                loadLyrics(for: track, force: true)
                            } label: {
                                Label("重试", systemImage: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 28)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !lines.isEmpty {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: compactHeight ? 12 : 14) {
                                ForEach(lines.indices, id: \.self) { index in
                                    Text(lines[index])
                                        .font(.system(size: compactHeight ? 17 : 18, weight: .medium))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 28, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.78))

                            Text("当前歌曲暂无可显示的歌词")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.72))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: panelHeight)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, max(safeBottom + 8, 12))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func handleLyricsButtonTap(for track: Track) {
        if isLyricsPresented {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                isLyricsPresented = false
            }
            return
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isLyricsPresented = true
        }
        loadLyrics(for: track, force: false)
    }

    private func handleTrackChange(_ track: Track) {
        guard isLyricsPresented else {
            resetLyricsState(keepPresentation: false)
            return
        }

        loadLyrics(for: track, force: true)
    }

    private func resetLyricsState(keepPresentation: Bool = false) {
        isLoadingLyrics = false
        lyricsStateTrackID = nil
        loadedLyricsTrackID = nil
        lyricResult = nil
        lyricsErrorMessage = nil
        if !keepPresentation {
            isLyricsPresented = false
        }
    }

    private func loadLyrics(for track: Track, force: Bool) {
        lyricsStateTrackID = track.id

        if !force, loadedLyricsTrackID == track.id, lyricResult != nil {
            lyricsErrorMessage = nil
            return
        }

        lyricResult = nil
        lyricsErrorMessage = nil
        isLoadingLyrics = true

        Task {
            let currentTrackID = track.id

            do {
                guard let searchSong = track.searchSong else {
                    throw NSError(
                        domain: "XMusic.Lyrics",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "这首歌当前没有可用于解析歌词的歌曲信息。"]
                    )
                }

                let source = preferredLyricsSource(for: track)
                guard let source else {
                    throw NSError(
                        domain: "XMusic.Lyrics",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "没有找到可用的音源，请先在设置里激活一个音源。"]
                    )
                }

                let resolvedLyrics = try await sourceLibrary.resolveLyric(
                    with: source,
                    platformSource: searchSong.source.rawValue,
                    legacySongInfoJSON: searchSong.legacyInfoJSON
                )

                guard player.currentTrack?.id == currentTrackID, lyricsStateTrackID == currentTrackID else { return }
                isLoadingLyrics = false
                loadedLyricsTrackID = currentTrackID
                lyricResult = resolvedLyrics
            } catch {
                guard player.currentTrack?.id == currentTrackID, lyricsStateTrackID == currentTrackID else { return }
                isLoadingLyrics = false
                loadedLyricsTrackID = nil
                lyricsErrorMessage = error.localizedDescription
            }
        }
    }

    private func preferredLyricsSource(for track: Track) -> ImportedMusicSource? {
        if let sourceName = track.sourceName,
           let matchedSource = sourceLibrary.sources.first(where: { $0.name == sourceName }) {
            return matchedSource
        }
        return sourceLibrary.activeSource
    }

    private func cleanedLyricLines(for track: Track) -> [String] {
        guard loadedLyricsTrackID == track.id, let lyricResult else { return [] }

        let normalized = lyricResult.lyric
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        return normalized
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { cleanedLyricLine(from: String($0)) }
            .filter { !$0.isEmpty }
    }

    private func cleanedLyricLine(from line: String) -> String {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty else { return "" }

        if trimmedLine.range(of: #"^\[(ti|ar|al|by|offset):.*\]$"#, options: .regularExpression) != nil {
            return ""
        }

        let withoutTimestamps = trimmedLine.replacingOccurrences(
            of: #"\[[0-9]{1,2}:[0-9]{2}(?:\.[0-9]{1,3})?\]"#,
            with: "",
            options: .regularExpression
        )
        return withoutTimestamps.trimmingCharacters(in: .whitespacesAndNewlines)
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
