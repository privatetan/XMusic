// 引入 Foundation，提供基础数据类型与正则等能力。
import Foundation
// 引入 SwiftUI，提供视图声明与状态管理能力。
import SwiftUI

// 仅在 iOS 平台下编译下面这组导入。
#if os(iOS)
// 引入 AVKit，提供音视频播放相关能力。
import AVKit
// 引入 MediaPlayer，提供系统媒体路由与播放信息能力。
import MediaPlayer
// 结束仅 iOS 平台的条件编译块。
#endif

// 当可以导入 UIKit 时编译下面这组代码。
#if canImport(UIKit)
// 引入 UIKit，用于访问 UIDevice、UIScreen 等 UIKit 类型。
import UIKit
// 结束 UIKit 条件编译块。
#endif

// 定义播放页主视图。
struct PlayPageMainView: View {
    // 从环境中读取播放器视图模型。
    @EnvironmentObject private var player: MusicPlayerViewModel
    // 从环境中读取音源库对象。
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    // 从环境中读取搜索视图模型。
    @EnvironmentObject private var musicSearch: MusicSearchViewModel
    // 观察播放时间线对象，用于更新进度条和歌词高亮。
    @ObservedObject var timeline: PlaybackTimeline
    // 标记当前是否处于手动拖动进度条状态。
    @State private var isScrubbing = false
    // 保存拖动时的临时播放时间。
    @State private var draftTime: Double = 0
    // 记录整个播放页面板的拖拽偏移量。
    @State private var dragOffset: CGFloat = 0
    // 控制内容显隐，用于入场动画。
    @State private var showContent = true
    // 记录歌词展示模式，隐藏、半屏或全屏。
    @State private var lyricsPresentationMode: LyricsPresentationMode = .hidden
    // 标记歌词是否正在加载。
    @State private var isLoadingLyrics = false
    // 记录当前歌词状态绑定的是哪首歌。
    @State private var lyricsStateTrackID: UUID?
    // 记录已经成功加载歌词的是哪首歌。
    @State private var loadedLyricsTrackID: UUID?
    // 保存当前加载到的歌词结果。
    @State private var lyricResult: MusicSourceLyricResult?
    // 保存歌词加载失败时的错误文案。
    @State private var lyricsErrorMessage: String?
    // 标记当前是否连接到外部音频输出设备。
    @State private var isExternalAudioRouteActive = false
    // 标记是否展示输出设备选择浮层。
    @State private var isRouteSheetPresented = false
    // 作为路由选择器触发器的计数值。
    @State private var routePickerTrigger = 0
    // 标记歌词列表当前是否滚动在顶部。
    @State private var isLyricsAtTop = true
    // 接收父视图传入的命名空间，用于 matchedGeometry 动画。
    let animation: Namespace.ID
    // 从父视图传入稳定尺寸，避免 GeometryReader 在转场时拿到错误值。
    /// 从父视图传入的稳定尺寸，避免 GeometryReader 在转场动画期间
    // 补充说明：避免拿到 .zero 或错误尺寸导致布局卡死。
    /// 拿到 .zero / 不正确的值导致布局卡死。
    // 保存父视图提供的容器尺寸。
    var containerSize: CGSize = .zero
    // 播放页关闭时执行的回调。
    let close: () -> Void

    // 视图主体。
    var body: some View {
        // 只有当前存在正在播放的歌曲时才渲染播放页。
        if let track = player.currentTrack {
            // 使用 GeometryReader 读取当前可用尺寸与安全区。
            GeometryReader { geometry in
                // 构造稳定几何信息，优先用真实 geometry，否则回退到父视图传入尺寸。
                let geometry = StableGeometry(
                    // 传入 GeometryReader 提供的布局信息。
                    proposed: geometry,
                    // 当 GeometryReader 尺寸异常时，回退使用外部传入尺寸。
                    fallbackSize: containerSize
                )
                // 根据容器尺寸与安全区计算播放页布局参数。
                let layout = PlayPagePanelLayout(
                    // 传入当前容器尺寸。
                    size: geometry.size,
                    // 传入当前安全区边距。
                    safeAreaInsets: geometry.safeAreaInsets
                )
                // 解析当前歌曲对应的歌词行。
                let lyricLines = parsedLyricLines(for: track)
                // 计算当前时刻应该高亮的歌词行 id。
                let activeLineID = currentLyricLineID(for: track, lines: lyricLines)
                // 根据歌词模式决定顶部区域高度。
                let topSectionHeight = lyricsPresentationMode == .full ? layout.availableHeight : layout.topSectionHeight

                // 使用 ZStack 叠放背景、主体内容、光晕和路由弹层。
                ZStack {
                    // 绘制播放页整体背景卡片。
                    // RoundedRectangle 是一个形状（Shape），用来创建带有圆角的矩形。它非常适合用于创建按钮、背景框、卡片等需要圆角矩形效果的 UI 元素。你可以通过设置圆角半径、大小等参数来定制它的外观。
                    RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                        // 用线性渐变填充背景。
                        .fill(
                            // 定义顶部到底部的背景渐变。
                            LinearGradient(
                                // 渐变色数组。
                                colors: [
                                    // 渐变第一段颜色。
                                    Color(red: 0.67, green: 0.64, blue: 0.64),
                                    // 渐变第二段颜色。
                                    Color(red: 0.58, green: 0.55, blue: 0.55),
                                    // 渐变第三段颜色。
                                    Color(red: 0.53, green: 0.50, blue: 0.50)
                                ],
                                // 渐变起点为顶部。
                                startPoint: .top,
                                // 渐变终点为底部。
                                endPoint: .bottom
                            )
                        )
                        // 与迷你播放器背景做共享几何动画。
                        .matchedGeometryEffect(id: "PlayerBackground", in: animation)
                        // 背景扩展到安全区外。
                        .ignoresSafeArea()
                        // 根据拖拽和入场状态缩放 X 轴。
                        .scaleEffect(x: currentScaleX, y: currentScaleY)
                        // 根据拖拽进度调整背景透明度。
                        .opacity(backgroundOpacity)

                    // 纵向排列上半区和下半区控制面板。
                    VStack(spacing: 0) {
                        // 渲染封面和歌词上半部分。
                        PlayPageArtworkSectionView(
                            // 传入当前歌曲。
                            track: track,
                            // 传入布局参数。
                            layout: layout,
                            // 传入拖拽压缩进度。
                            squeezeProgress: squeezeProgress,
                            // 传入歌词行数据。
                            lines: lyricLines,
                            // 传入当前高亮歌词行 id。
                            activeLineID: activeLineID,
                            // 传入歌词加载状态。
                            isLoadingLyrics: isLoadingLyrics,
                            // 传入歌词错误信息。
                            lyricsErrorMessage: lyricsErrorMessage,
                            // 传入歌词展示模式。
                            lyricsPresentationMode: lyricsPresentationMode,
                            // 传入内容显隐状态，用于动画。
                            showContent: showContent,
                            // 点击歌手名时打开搜索。
                            onArtistTap: { openArtistSearch(for: track) },
                            // 重试歌词加载时强制刷新。
                            onRetryLyrics: { loadLyrics(for: track, force: true) },
                            // 同步歌词列表是否滚动到顶部。
                            onLyricsTopStateChange: { isLyricsAtTop = $0 },
                            // 点击歌词头部时切换歌词展开状态。
                            onLyricsHeaderTap: { toggleLyricsExpansion(for: track) }
                        )
                        // 顶部区域高度受歌词模式影响。
                        .frame(height: topSectionHeight, alignment: .top)
                        // 指定命中区域为矩形。
                        .contentShape(Rectangle())
                        // 为顶部区域附加歌词模式切换拖拽手势。
                        .simultaneousGesture(lyricsModeDragGesture)

                        // 当歌词不是全屏时，显示底部控制区。
                        if lyricsPresentationMode != .full {
                            // 渲染播放控制区。
                            PlayPageControlsSectionView(
                                // 传入播放时间线。
                                timeline: timeline,
                                // 传入布局参数。
                                layout: layout,
                                // 传入内容显隐状态。
                                showContent: showContent,
                                // 传入拖拽压缩进度。
                                squeezeProgress: squeezeProgress,
                                // 传入是否有外部音频路由。
                                isExternalAudioRouteActive: isExternalAudioRouteActive,
                                // 绑定是否正在拖动进度条。
                                isScrubbing: $isScrubbing,
                                // 绑定拖动中的临时时间。
                                draftTime: $draftTime,
                                // 将歌词展示状态转换成布尔绑定传入子视图。
                                isLyricsPresented: Binding(
                                    // 读取当前歌词模式是否已展示。
                                    get: { lyricsPresentationMode.isPresented },
                                    // 写入时根据布尔值切回半屏或隐藏。
                                    set: { lyricsPresentationMode = $0 ? .half : .hidden }
                                ),
                                // 绑定路由面板展示状态。
                                isRouteSheetPresented: $isRouteSheetPresented,
                                // 绑定路由选择器触发值。
                                routePickerTrigger: $routePickerTrigger,
                                // 上一首按钮行为。
                                onPrevious: { player.playPrevious() },
                                // 播放暂停按钮行为。
                                onTogglePlayback: { player.togglePlayback() },
                                // 下一首按钮行为。
                                onNext: { player.playNext() },
                                // 歌词按钮行为。
                                onLyricsTap: { handleLyricsButtonTap(for: track) }
                            )
                            // 底部控制区切换时使用自底部移动加淡入淡出过渡。
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    // 设置主体内容宽高。
                    .frame(width: layout.contentWidth, height: layout.availableHeight, alignment: .top)
                    // 避开顶部安全区。
                    .padding(.top, layout.safeTop)
                    // 应用左右内边距。
                    .padding(.horizontal, layout.horizontalPadding)
                    // 让主体内容在容器内顶对齐居中。
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    // 添加一层封面色光晕背景。
                    Circle()
                        // 使用封面主色作为光晕填充。
                        .fill(track.artwork.glow.opacity(0.10))
                        // 设置光晕尺寸。
                        .frame(width: 560, height: 560)
                        // 模糊形成柔和氛围。
                        .blur(radius: 130)
                        // 跟随拖拽产生轻微位移。
                        .offset(y: -240 + dragOffset * 0.18)
                        // 入场前隐藏，入场后显示。
                        .opacity(showContent ? 1 : 0)
                        // 这层纯视觉背景不接收点击事件。
                        .allowsHitTesting(false)

                    // 当路由面板打开时显示 AirPlay / 输出设备浮层。
                    if isRouteSheetPresented {
                        // 渲染路由浮层。
                        routeSheetOverlay(
                            // 传入当前歌曲。
                            track: track,
                            // 传入底部安全区高度。
                            safeBottom: layout.safeBottom,
                            // 传入水平边距。
                            horizontalPadding: layout.horizontalPadding,
                            // 传入是否紧凑高度布局。
                            compactHeight: layout.compactHeight
                        )
                        // 让浮层位于更高层级。
                        .zIndex(121)
                    }
                }
                // 当支持 UIKit 时给整个页面加下拉关闭捕获层。
                #if canImport(UIKit)
                // 通过 background 挂载全屏拖拽捕获视图。
                .background(
                    // 自定义拖拽捕获视图，用于实现下滑关闭播放页。
                    DismissPanCaptureView(
                        // 拖动过程中实时更新偏移量。
                        onChanged: { dragOffset = $0 },
                        // 拖动结束时根据位移和速度决定是否关闭。
                        onEnded: { ty, vy in
                            // 达到阈值则关闭播放页。
                            let shouldDismiss = ty > 120 || (ty > 44 && vy > 900)
                            // 如果满足关闭条件就关闭面板。
                            if shouldDismiss {
                                // 调用关闭逻辑。
                                dismissPanel()
                            } else {
                                // 否则回弹到原位。
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                    // 将偏移量归零。
                                    dragOffset = 0
                                }
                            }
                        },
                        // 决定是否允许开始下拉关闭手势。
                        shouldBegin: { shouldAllowPanelDismissGesture }
                    )
                )
                // 结束 UIKit 条件编译区域。
                #endif
                // 让整个页面占满容器。
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                // 根据下拉手势整体移动面板。
                .offset(y: dragOffset)
                // 当歌曲切换时处理歌词状态更新。
                .task(id: track.id) {
                    // 调用歌曲切换处理逻辑。
                    handleTrackChange(track)
                }
                // 视图消失时重置歌词状态。
                .onDisappear {
                    // 清空歌词相关状态。
                    resetLyricsState()
                }
            }
            // 整个播放页忽略安全区。
            .ignoresSafeArea()
            // 页面出现时重置临时展示状态并触发入场动画。
            .onAppear {
                // 调用重置临时状态方法。
                resetTransientPresentationState()
            }
            // 页面出现时刷新音频输出路由状态。
            .onAppear(perform: refreshAudioRouteState)
            // 监听系统音频路由变化通知。
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { _ in
                // 路由变化后刷新当前是否为外部输出。
                refreshAudioRouteState()
            }
        }
    }

    // 根据拖拽偏移计算背景透明度。
    private var backgroundOpacity: Double {
        // 先将拖拽进度归一化到 0...1。
        let progress = min(max(dragOffset / 360, 0), 1)
        // 拖得越多透明度越低。
        return 1 - Double(progress) * 0.22
    }

    // 根据拖拽偏移计算压缩进度。
    private var squeezeProgress: CGFloat {
        // 定义达到完全压缩所需的位移阈值。
        let threshold: CGFloat = 420
        // 将拖拽值裁剪到 0...1。
        return min(max(dragOffset / threshold, 0), 1)
    }

    // 计算背景卡片当前 X 轴缩放。
    private var currentScaleX: CGFloat {
        // 根据内容是否显示决定基础缩放值。
        let baseScale: CGFloat = showContent ? 1.0 : 0.82
        // 在基础值上叠加拖拽压缩效果。
        return baseScale - (squeezeProgress * 0.18)
    }

    // 计算背景卡片当前 Y 轴缩放。
    private var currentScaleY: CGFloat {
        // 根据内容是否显示决定基础缩放值。
        let baseScale: CGFloat = showContent ? 1.0 : 0.96
        // 在基础值上叠加拖拽压缩效果。
        return baseScale - (squeezeProgress * 0.04)
    }

    // 计算背景卡片当前圆角值。
    private var currentCornerRadius: CGFloat {
        // 根据内容是否显示决定基础圆角。
        let baseRadius: CGFloat = showContent ? 48 : 28
        // 拖拽时逐渐减小圆角。
        return baseRadius - (squeezeProgress * 20)
    }

    // 重置播放页入场相关的临时状态。
    private func resetTransientPresentationState() {
        // 进入页面时默认不是手动拖动进度。
        isScrubbing = false
        // 初始化草稿时间为当前播放时间。
        draftTime = timeline.currentTime
        // 清空整体下拉偏移。
        dragOffset = 0
        // 默认先关闭歌词面板。
        lyricsPresentationMode = .hidden
        // 歌词列表顶部状态重置为 true。
        isLyricsAtTop = true

        // 先隐藏内容，为入场动画做准备。
        showContent = false
        // 稍微延迟后执行内容显示动画。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // 通过 easeOut 动画显示内容。
            withAnimation(.easeOut(duration: 0.45).delay(0.1)) {
                // 将内容显示出来。
                showContent = true
            }
        }
    }

    // 关闭播放页面板。
    private func dismissPanel() {
        // 调用父视图传入的关闭回调。
        close()
    }

    // 判断当前是否允许开始下拉关闭手势。
    private var shouldAllowPanelDismissGesture: Bool {
        // 如果歌词面板未展示，则总是允许关闭。
        guard lyricsPresentationMode.isPresented else { return true }
        // 如果歌词面板已展示，则只有滚动在顶部才允许下拉关闭。
        return isLyricsAtTop
    }

    // 定义顶部区域用于切换歌词半屏/全屏的拖拽手势。
    private var lyricsModeDragGesture: some Gesture {
        // 创建最小触发距离为 8 的拖拽手势。
        DragGesture(minimumDistance: 8)
            // 仅在手势结束时判断切换逻辑。
            .onEnded { value in
                // 歌词未展示时不处理。
                guard lyricsPresentationMode.isPresented else { return }

                // 获取垂直方向实际位移。
                let verticalTranslation = value.translation.height
                // 获取系统预测的结束位移。
                let predictedVerticalTranslation = value.predictedEndTranslation.height
                // 在半屏状态向上拖时切到全屏。
                let isExpanding = lyricsPresentationMode == .half &&
                    (verticalTranslation < -18 || predictedVerticalTranslation < -44)
                // 在全屏状态向下拖时切到半屏。
                let isCollapsing = lyricsPresentationMode == .full &&
                    (verticalTranslation > 14 || predictedVerticalTranslation > 52)

                // 命中展开条件时切到全屏。
                if isExpanding {
                    // 使用弹簧动画让切换更自然。
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        // 设置歌词模式为全屏。
                        lyricsPresentationMode = .full
                    }
                } else if isCollapsing {
                    // 命中收起条件时切回半屏。
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                        // 设置歌词模式为半屏。
                        lyricsPresentationMode = .half
                    }
                }
            }
    }

    // 计算当前允许用于搜索的音源列表。
    private var searchableSources: [SearchPlatformSource] {
        // 从当前激活音源能力中提取出可映射的搜索平台。
        let sourceNames = sourceLibrary.activeSource?.capabilities.compactMap { SearchPlatformSource(rawValue: $0.source) } ?? []
        // 如果激活音源没有搜索能力，则回退到内置搜索平台列表。
        return sourceNames.isEmpty ? SearchPlatformSource.builtIn : sourceNames
    }

    // 点击歌手名后打开搜索页并搜索该歌手。
    private func openArtistSearch(for track: Track) {
        // 对歌手名做首尾空白清理。
        let artist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        // 歌手名为空时直接返回。
        guard !artist.isEmpty else { return }

        // 发起搜索。
        musicSearch.startSearch(query: artist, allowedSources: searchableSources)
        // 切换到底部搜索标签页。
        player.selectedTab = .search
        // 关闭播放页。
        dismissPanel()
    }

    // 构建底部音频输出路由弹层。
    @ViewBuilder
    private func routeSheetOverlay(
        // 当前歌曲，用于和外部上下文保持参数一致。
        track: Track,
        // 底部安全区高度。
        safeBottom: CGFloat,
        // 左右内边距。
        horizontalPadding: CGFloat,
        // 是否使用紧凑高度布局。
        compactHeight: Bool
    ) -> some View {
        // 读取当前设备名称。
        let deviceName = UIDevice.current.name
        // 优先读取当前系统输出路由名，否则回退到设备名。
        let currentRouteName = AVAudioSession.sharedInstance().currentRoute.outputs.first?.portName ?? deviceName
        // 计算弹层宽度。
        let panelWidth = min(UIScreen.main.bounds.width - horizontalPadding * 2, compactHeight ? 320 : 352)
        // 计算底部留白，避免挡住系统区域。
        let bottomInset = max(safeBottom + 96, 104)
        // 定义面板背景色。
        let panelBackground = Color(red: 0.28, green: 0.23, blue: 0.31).opacity(0.97)
        // 定义面板描边色。
        let panelStroke = Color.white.opacity(0.07)

        // 使用底部对齐的 ZStack 承载遮罩与弹层内容。
        ZStack(alignment: .bottom) {
            // 背景遮罩渐变。
            LinearGradient(
                // 遮罩颜色数组。
                colors: [
                    // 顶部接近透明。
                    Color.black.opacity(0.03),
                    // 中间轻度加深。
                    Color.black.opacity(0.16),
                    // 底部更深以衬托弹层。
                    Color.black.opacity(0.28)
                ],
                // 遮罩从顶部开始。
                startPoint: .top,
                // 遮罩到底部结束。
                endPoint: .bottom
            )
            // 遮罩铺满全屏。
            .ignoresSafeArea()
            // 遮罩出现时淡入淡出。
            .transition(.opacity)
            // 点击遮罩时关闭路由弹层。
            .onTapGesture {
                // 使用弹簧动画收起弹层。
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    // 隐藏路由面板。
                    isRouteSheetPresented = false
                }
            }

            // 弹层主体纵向布局。
            VStack(spacing: 0) {
                // 上方卡片内容。
                VStack(spacing: 0) {
                    // 标题区纵向布局。
                    VStack(spacing: 6) {
                        // 显示 AirPlay 图标。
                        Image(systemName: "airplayaudio")
                            // 设置图标字体样式。
                            .font(.system(size: 15, weight: .medium))
                            // 设置图标颜色。
                            .foregroundStyle(Color.white.opacity(0.82))

                        // 显示弹层标题。
                        Text("AirPlay")
                            // 设置标题字体。
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            // 设置标题颜色。
                            .foregroundStyle(.white)
                    }
                    // 标题区上边距。
                    .padding(.top, 16)
                    // 标题区下边距。
                    .padding(.bottom, 14)

                    // 输出设备列表区域。
                    VStack(alignment: .leading, spacing: 0) {
                        // 当前设备行。
                        routeRow(
                            // 图标为 iPhone。
                            systemName: "iphone",
                            // 标题为 iPhone。
                            title: "iPhone"
                        )
                        // 设备分隔线。
                        routeDivider()
                        // AirPods 行。
                        routeRow(
                            // 图标为 AirPods Pro。
                            systemName: "airpodspro",
                            // 标题为 AirPods Pro。
                            title: "AirPods Pro",
                            // 副标题为未连接。
                            subtitle: "未连接"
                        )
                        // 设备分隔线。
                        routeDivider()
                        // HomePod 行。
                        routeRow(
                            // 图标为 HomePod mini。
                            systemName: "homepodmini.fill",
                            // 标题为 Living Room。
                            title: "Living Room",
                            // 副标题为设备型号。
                            subtitle: "HomePod mini"
                        )
                    }
                    // 列表底部留白。
                    .padding(.bottom, 12)
                }
                // 设置卡片宽度。
                .frame(width: panelWidth)
                // 绘制卡片背景。
                .background(
                    // 使用圆角矩形背景。
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        // 填充自定义背景色。
                        .fill(panelBackground)
                )
                // 绘制卡片描边。
                .overlay(
                    // 使用同样圆角的描边形状。
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        // 应用描边颜色和宽度。
                        .stroke(panelStroke, lineWidth: 1)
                )
                // 给卡片添加阴影。
                .shadow(color: Color.black.opacity(0.22), radius: 28, x: 0, y: 14)

                // 显示当前播放输出路由名称。
                Text("正在播放到 \(currentRouteName)")
                    // 设置文字样式。
                    .font(.system(size: 13, weight: .medium))
                    // 设置文字颜色。
                    .foregroundStyle(Color.white.opacity(0.58))
                    // 顶部留白。
                    .padding(.top, 16)
                    // 底部留白。
                    .padding(.bottom, bottomInset)
            }
            // 给整体弹层应用水平边距。
            .padding(.horizontal, horizontalPadding)
            // 让弹层自底部滑入并伴随透明度变化。
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // 构建单个输出设备行。
    @ViewBuilder
    private func routeRow(
        // 设备图标名。
        systemName: String,
        // 设备标题。
        title: String,
        // 可选副标题。
        subtitle: String? = nil
    ) -> some View {
        // 使用横向布局排列图标、标题与选中标记。
        HStack(spacing: 14) {
            // 左侧设备图标。
            Image(systemName: systemName)
                // 设置图标样式。
                .font(.system(size: 18, weight: .medium))
                // 设置图标颜色。
                .foregroundStyle(.white.opacity(0.88))
                // 固定图标区域尺寸。
                .frame(width: 28, height: 28)

            // 标题和副标题纵向排列。
            VStack(alignment: .leading, spacing: 2) {
                // 设备标题。
                Text(title)
                    // 设置标题字体。
                    .font(.system(size: 16, weight: .semibold))
                    // 设置标题颜色。
                    .foregroundStyle(.white)

                // 当副标题存在时显示。
                if let subtitle {
                    // 副标题文本。
                    Text(subtitle)
                        // 设置副标题字体。
                        .font(.system(size: 13, weight: .medium))
                        // 设置副标题颜色。
                        .foregroundStyle(Color.white.opacity(0.52))
                }
            }

            // 把右侧内容推到最右边。
            Spacer(minLength: 12)

            // 如果当前行是 iPhone，则显示选中勾。
            if title == "iPhone" {
                // 勾选图标。
                Image(systemName: "checkmark")
                    // 设置图标样式。
                    .font(.system(size: 14, weight: .bold))
                    // 设置图标颜色。
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        // 应用左右内边距。
        .padding(.horizontal, 18)
        // 应用上下内边距。
        .padding(.vertical, 14)
    }

    // 构建设备列表分隔线。
    @ViewBuilder
    private func routeDivider() -> some View {
        // 使用矩形作为分隔线。
        Rectangle()
            // 设置分隔线颜色。
            .fill(Color.white.opacity(0.07))
            // 设置分隔线高度。
            .frame(height: 1)
            // 左侧留出图标区域宽度。
            .padding(.leading, 60)
    }

    // 处理点击歌词按钮的行为。
    private func handleLyricsButtonTap(for track: Track) {
        // 已展示则隐藏，未展示则切到半屏。
        lyricsPresentationMode = lyricsPresentationMode.isPresented ? .hidden : .half
        // 如果切换后是隐藏状态就不用加载歌词。
        guard lyricsPresentationMode.isPresented else { return }
        // 在展示歌词时尝试加载歌词。
        loadLyrics(for: track, force: false)
    }

    // 处理点击歌词头部时的展开/收起行为。
    private func toggleLyricsExpansion(for track: Track) {
        // 如果当前歌词未展示，则等价于点击歌词按钮。
        guard lyricsPresentationMode.isPresented else {
            // 直接走歌词按钮逻辑。
            handleLyricsButtonTap(for: track)
            // 提前返回。
            return
        }

        // 使用动画在半屏与全屏之间切换。
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            // 全屏就切半屏，半屏就切全屏。
            lyricsPresentationMode = lyricsPresentationMode == .full ? .half : .full
        }

        // 切换后确保歌词已加载。
        loadLyrics(for: track, force: false)
    }

    // 处理歌曲切换时的歌词状态逻辑。
    private func handleTrackChange(_ track: Track) {
        // 如果当前歌词面板未展示，则只重置歌词状态但保留展示模式。
        guard lyricsPresentationMode.isPresented else {
            // 保留展示模式参数传 true。
            resetLyricsState(keepPresentation: true)
            // 直接返回。
            return
        }

        // 如果歌词面板已展示，则强制为新歌曲重新加载歌词。
        loadLyrics(for: track, force: true)
    }

    // 重置歌词相关状态。
    private func resetLyricsState(keepPresentation: Bool = false) {
        // 取消加载中状态。
        isLoadingLyrics = false
        // 清空歌词状态绑定的歌曲 id。
        lyricsStateTrackID = nil
        // 清空已加载歌词的歌曲 id。
        loadedLyricsTrackID = nil
        // 清空歌词结果。
        lyricResult = nil
        // 清空错误文案。
        lyricsErrorMessage = nil
        // 如果不要求保留展示状态，则顺带关闭歌词面板。
        if !keepPresentation {
            // 隐藏歌词面板。
            lyricsPresentationMode = .hidden
            // 同时将滚动状态重置为顶部。
            isLyricsAtTop = true
        }
    }

    // 加载指定歌曲的歌词。
    private func loadLyrics(for track: Track, force: Bool) {
        // 将当前歌词状态绑定到这首歌。
        lyricsStateTrackID = track.id

        // 如果不是强制刷新，且这首歌歌词已加载成功，则直接复用。
        if !force, loadedLyricsTrackID == track.id, lyricResult != nil {
            // 已有歌词时清空错误文案。
            lyricsErrorMessage = nil
            // 直接返回。
            return
        }

        // 开始新一轮加载前清空旧歌词结果。
        lyricResult = nil
        // 清空旧错误文案。
        lyricsErrorMessage = nil
        // 标记为加载中。
        isLoadingLyrics = true

        // 开启异步任务加载歌词。
        Task {
            // 记录当前任务对应的歌曲 id，避免异步串台。
            let currentTrackID = track.id

            // 执行歌词解析流程。
            do {
                // 当前歌曲没有 searchSong 信息时无法解析歌词。
                guard let searchSong = track.searchSong else {
                    // 抛出自定义错误。
                    throw NSError(
                        // 错误域名。
                        domain: "XMusic.Lyrics",
                        // 错误码。
                        code: 1,
                        // 错误描述。
                        userInfo: [NSLocalizedDescriptionKey: "这首歌当前没有可用于解析歌词的歌曲信息。"]
                    )
                }

                // 取出平台源标识。
                let platformSource = searchSong.source.rawValue
                // 声明最终解析出来的歌词结果。
                let resolvedLyrics: MusicSourceLyricResult

                // 先尝试走内置歌词服务。
                do {
                    // 使用内置歌词服务解析歌词。
                    resolvedLyrics = try await BuiltInLyricService.shared.resolveLyric(for: searchSong)
                } catch {
                    // 内置歌词失败后，选择一个可用的外部音源继续解析。
                    let source = preferredLyricsSource(for: track, platformSource: platformSource)
                    // 如果没有可用音源，则拼出更清晰的错误信息。
                    guard let source else {
                        // 清理内置错误消息文本。
                        let builtInMessage = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                        // 组合最终错误消息。
                        let message = builtInMessage.isEmpty
                            ? "当前没有可用的内置歌词，也没有任何已导入音源支持 \(searchSong.source.title) 的歌词解析。"
                            : "\(builtInMessage)。当前也没有任何已导入音源支持 \(searchSong.source.title) 的歌词解析。"
                        // 抛出没有可用歌词来源的错误。
                        throw NSError(
                            // 错误域名。
                            domain: "XMusic.Lyrics",
                            // 错误码。
                            code: 2,
                            // 错误描述。
                            userInfo: [NSLocalizedDescriptionKey: message]
                        )
                    }

                    // 使用已导入音源继续解析歌词。
                    resolvedLyrics = try await sourceLibrary.resolveLyric(
                        // 传入选中的音源。
                        with: source,
                        // 传入平台标识。
                        platformSource: platformSource,
                        // 传入 legacy songInfo json。
                        legacySongInfoJSON: searchSong.legacyInfoJSON
                    )
                }

                // 如果当前歌曲或歌词状态已经变了，就丢弃这次异步结果。
                guard player.currentTrack?.id == currentTrackID, lyricsStateTrackID == currentTrackID else { return }
                // 加载成功后取消加载状态。
                isLoadingLyrics = false
                // 记录这首歌歌词已经成功加载。
                loadedLyricsTrackID = currentTrackID
                // 保存歌词结果。
                lyricResult = resolvedLyrics
            } catch {
                // 如果当前歌曲或歌词状态已经变了，就丢弃错误结果。
                guard player.currentTrack?.id == currentTrackID, lyricsStateTrackID == currentTrackID else { return }
                // 失败后取消加载状态。
                isLoadingLyrics = false
                // 清空已加载歌曲 id。
                loadedLyricsTrackID = nil
                // 保存错误文案。
                lyricsErrorMessage = error.localizedDescription
            }
        }
    }

    // 选择一个最合适的歌词解析音源。
    private func preferredLyricsSource(for track: Track, platformSource: String) -> ImportedMusicSource? {
        // 优先使用歌曲自身记录的来源音源。
        if let sourceName = track.sourceName,
           let matchedSource = sourceLibrary.sources.first(where: { $0.name == sourceName }),
           matchedSource.supports(source: platformSource, action: .lyric) {
            // 命中时直接返回该音源。
            return matchedSource
        }

        // 其次尝试当前激活音源。
        if let activeSource = sourceLibrary.activeSource,
           activeSource.supports(source: platformSource, action: .lyric) {
            // 命中时返回激活音源。
            return activeSource
        }

        // 最后从所有导入音源中找第一个支持歌词解析的。
        return sourceLibrary.sources.first { $0.supports(source: platformSource, action: .lyric) }
    }

    // 解析歌词结果为可用于 UI 展示的歌词行模型。
    private func parsedLyricLines(for track: Track) -> [ParsedLyricLine] {
        // 只有当前歌词确实属于这首歌且歌词结果存在时才继续。
        guard loadedLyricsTrackID == track.id, let lyricResult else { return [] }
        // 优先选出主歌词文本。
        let primaryLyric = preferredPrimaryLyric(from: lyricResult)
        // 将主歌词解析成带时间戳的条目。
        let parsedPrimary = parseTimedLyricEntries(from: primaryLyric)

        // 主歌词为空时直接返回空数组。
        guard !parsedPrimary.isEmpty else { return [] }

        // 用于收集合并后的歌词行。
        var mergedLines: [ParsedLyricLine] = []
        // 用于按时间定位合并结果下标。
        var lineIndexByTime: [Int: Int] = [:]

        // 先把主歌词合并进最终结果。
        for entry in parsedPrimary {
            // 同一时间点已有歌词时尝试追加扩展歌词。
            if let existingIndex = lineIndexByTime[entry.time] {
                // 文本不同且还未存在时加入扩展歌词数组。
                if mergedLines[existingIndex].text != entry.text,
                   !mergedLines[existingIndex].extendedLyrics.contains(entry.text) {
                    // 将额外文本追加到扩展歌词中。
                    mergedLines[existingIndex].extendedLyrics.append(entry.text)
                }
                // 已处理该时间点，继续下一条。
                continue
            }

            // 记录新歌词行的索引。
            let newIndex = mergedLines.count
            // 构造并追加新的歌词行。
            mergedLines.append(
                // 创建 ParsedLyricLine 对象。
                ParsedLyricLine(
                    // 使用时间和索引构造稳定 id。
                    id: "\(entry.time)-\(newIndex)",
                    // 写入时间戳。
                    time: entry.time,
                    // 写入主歌词文本。
                    text: entry.text,
                    // 初始扩展歌词为空。
                    extendedLyrics: []
                )
            )
            // 建立时间到索引的映射。
            lineIndexByTime[entry.time] = newIndex
        }

        // 再把翻译歌词和罗马音歌词合并进对应时间点。
        for extraLyric in [lyricResult.tlyric, lyricResult.rlyric].compactMap({ $0 }) {
            // 逐条解析附加歌词。
            for entry in parseTimedLyricEntries(from: extraLyric) {
                // 找不到对应时间点就跳过。
                guard let index = lineIndexByTime[entry.time] else { continue }
                // 如果和主歌词完全相同则跳过。
                guard entry.text != mergedLines[index].text else { continue }
                // 如果扩展歌词中已有同样文本则跳过。
                guard !mergedLines[index].extendedLyrics.contains(entry.text) else { continue }
                // 将附加歌词放进扩展歌词数组。
                mergedLines[index].extendedLyrics.append(entry.text)
            }
        }

        // 返回最终合并结果。
        return mergedLines
    }

    // 根据当前播放时间找到应高亮的歌词行 id。
    private func currentLyricLineID(for track: Track, lines: [ParsedLyricLine]) -> String? {
        // 只有歌词已加载且列表不为空时才继续。
        guard loadedLyricsTrackID == track.id, !lines.isEmpty else { return nil }

        // 如果用户正在拖进度条，则用草稿时间，否则用实际播放时间。
        let currentTime = Int((isScrubbing ? draftTime : timeline.currentTime) * 1000)
        // 时间异常时直接返回 nil。
        guard currentTime >= 0 else { return nil }

        // 二分查找左边界初始化。
        var low = 0
        // 二分查找右边界初始化。
        var high = lines.count - 1
        // 用于记录最后一个小于等于当前时间的行下标。
        var candidateIndex: Int?

        // 开始二分查找。
        while low <= high {
            // 取中间下标。
            let middle = (low + high) / 2
            // 如果该行时间小于等于当前时间，说明可能是候选项。
            if lines[middle].time <= currentTime {
                // 记录当前候选下标。
                candidateIndex = middle
                // 继续向右找更接近当前时间的行。
                low = middle + 1
            } else {
                // 否则向左半边继续查找。
                high = middle - 1
            }
        }

        // 将最终候选下标映射成歌词行 id。
        return candidateIndex.map { lines[$0].id }
    }

    // 从歌词结果中选出优先展示的主歌词文本。
    private func preferredPrimaryLyric(from result: MusicSourceLyricResult) -> String {
        // 先取标准 lyric 字段并裁掉首尾空白。
        let primary = result.lyric.trimmingCharacters(in: .whitespacesAndNewlines)
        // 如果标准歌词不为空，则直接使用。
        if !primary.isEmpty {
            // 返回标准歌词。
            return primary
        }

        // 否则回退到 lxlyric，并去掉逐字歌词标记。
        return result.lxlyric?
            // 删除 `<数字,数字>` 这种逐字时间标签。
            .replacingOccurrences(
                // 正则匹配逐字标记。
                of: #"<\d+,\d+>"#,
                // 替换为空字符串。
                with: "",
                // 使用正则表达式选项。
                options: .regularExpression
            ) ?? ""
    }

    // 将原始歌词文本解析为带时间戳的歌词条目。
    private func parseTimedLyricEntries(from text: String) -> [(time: Int, text: String)] {
        // 先统一换行符格式。
        let normalized = text
            // 将 Windows 换行统一为 \n。
            .replacingOccurrences(of: "\r\n", with: "\n")
            // 将单独的 \r 也统一为 \n。
            .replacingOccurrences(of: "\r", with: "\n")

        // 定义匹配时间标签的正则。
        let linePattern = #"\[(\d{1,3}(?::\d{1,3}){0,2}(?:\.\d{1,3})?)\]"#
        // 正则创建失败时返回空数组。
        guard let regex = try? NSRegularExpression(pattern: linePattern) else { return [] }

        // 收集解析结果。
        var entries: [(time: Int, text: String)] = []

        // 按行遍历歌词文本。
        for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            // 去掉当前行首尾空白。
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            // 空行直接跳过。
            guard !line.isEmpty else { continue }

            // 跳过标题、作者、专辑等元信息行。
            if line.range(of: #"^\[(ti|ar|al|by|offset):.*\]$"#, options: .regularExpression) != nil {
                // 命中元信息时继续下一行。
                continue
            }

            // 转成 NSString，便于使用 NSRange。
            let nsLine = line as NSString
            // 匹配当前行中的所有时间标签。
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            // 没有时间标签时跳过。
            guard !matches.isEmpty else { continue }

            // 先保留原始内容，后面会移除时间标签。
            var content = line
            // 倒序删除所有时间标签，避免 range 位移问题。
            for match in matches.reversed() {
                // 用空字符串替换掉当前时间标签。
                content = (content as NSString).replacingCharacters(in: match.range, with: "")
            }

            // 对剩余歌词内容做清洗。
            let cleanedContent = content
                // 删除逐字歌词标记。
                .replacingOccurrences(of: #"<\d+,\d+>"#, with: "", options: .regularExpression)
                // 去掉首尾空白。
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // 清洗后为空就跳过。
            guard !cleanedContent.isEmpty else { continue }

            // 将这一行上的每个时间标签都映射成一条歌词记录。
            for match in matches {
                // 取出时间标签文本。
                let timeLabel = nsLine.substring(with: match.range(at: 1))
                // 解析成毫秒值，失败则跳过。
                guard let milliseconds = lyricTimeMilliseconds(from: timeLabel) else { continue }
                // 追加解析结果。
                entries.append((time: milliseconds, text: cleanedContent))
            }
        }

        // 按时间升序、文本字典序排序返回。
        return entries.sorted { lhs, rhs in
            // 时间相同时按文本排序，保证结果稳定。
            if lhs.time == rhs.time {
                // 返回文本字典序比较结果。
                return lhs.text < rhs.text
            }
            // 否则按时间升序。
            return lhs.time < rhs.time
        }
    }

    // 将单个时间标签解析成毫秒值。
    private func lyricTimeMilliseconds(from label: String) -> Int? {
        // 先按冒号拆分时间各部分。
        let mainParts = label.split(separator: ":")
        // 没有部分或超过三段时视为非法格式。
        guard !mainParts.isEmpty, mainParts.count <= 3 else { return nil }

        // 转成字符串数组以便后续补位。
        var timeParts = mainParts.map(String.init)
        // 不足三段时在前面补 0，统一成 时:分:秒 格式。
        while timeParts.count < 3 {
            // 在开头插入 0。
            timeParts.insert("0", at: 0)
        }

        // 解析小时值。
        let hour = Int(timeParts[0]) ?? 0
        // 解析分钟值。
        let minute = Int(timeParts[1]) ?? 0

        // 再把秒和毫秒拆开。
        let secondPart = timeParts[2].split(separator: ".", omittingEmptySubsequences: false)
        // 秒数解析失败则返回 nil。
        guard let second = Int(secondPart[0]) else { return nil }

        // 声明毫秒值变量。
        let millisecond: Int
        // 如果存在小数部分，则解析为毫秒。
        if secondPart.count > 1 {
            // 最多保留三位毫秒精度。
            var decimal = String(secondPart[1].prefix(3))
            // 不足三位时右侧补 0。
            while decimal.count < 3 {
                // 追加 0。
                decimal.append("0")
            }
            // 转成整数毫秒值。
            millisecond = Int(decimal) ?? 0
        } else {
            // 没有小数部分则毫秒为 0。
            millisecond = 0
        }

        // 组合成总毫秒数并返回。
        return hour * 3_600_000 + minute * 60_000 + second * 1_000 + millisecond
    }

    // 刷新当前音频输出路由状态。
    private func refreshAudioRouteState() {
        // 仅在 iOS 平台下执行。
        #if os(iOS)
        // 读取当前系统音频路由。
        let route = AVAudioSession.sharedInstance().currentRoute
        // 取出所有输出端口。
        let outputs = route.outputs

        // 只要存在一个非听筒/扬声器输出，就视为外部音频路由激活。
        isExternalAudioRouteActive = outputs.contains { output in
            // 根据端口类型判断是否属于本机内建输出。
            switch output.portType {
            // 内建扬声器不算外部输出。
            case .builtInSpeaker, .builtInReceiver:
                // 返回 false。
                return false
            // 其余端口都算外部输出。
            default:
                // 返回 true。
                return true
            }
        }
        // 结束 iOS 条件编译块。
        #endif
    }
}
