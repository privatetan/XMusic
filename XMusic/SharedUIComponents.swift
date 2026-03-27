import SwiftUI

struct TrackStack: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    let title: String
    let subtitle: String
    let tracks: [Track]
    var queueOverride: [Track]? = nil

    var body: some View {
        let currentTrackID = player.currentTrack?.id
        let isPlaying = player.isPlaying
        let queue = queueOverride ?? tracks

        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: title, subtitle: subtitle)

            LazyVStack(spacing: 12) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRow(
                        track: track,
                        index: index + 1,
                        isCurrent: currentTrackID == track.id,
                        isPlaying: isPlaying
                    ) {
                        player.play(track, from: queue)
                    }
                }
            }
        }
    }
}

struct ArtworkView: View {
    let track: Track
    let cornerRadius: CGFloat
    let iconSize: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let artworkURL = track.searchSong?.artworkURL {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    artworkFallback
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else if shouldUseTextOnlyFallback {
                artworkFallback
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: track.artwork.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(track.artwork.glow.opacity(0.55))
                    .frame(width: iconSize * 4.3, height: iconSize * 4.3)
                    .blur(radius: iconSize * 1.2)
                    .offset(x: iconSize * 0.55, y: -iconSize * 0.7)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.5)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )

                VStack(alignment: .leading, spacing: iconSize * 0.18) {
                    HStack {
                        Spacer()

                        Text(track.artwork.label.uppercased())
                            .font(.system(size: max(9, iconSize * 0.32), weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.62))
                    }

                    Spacer()

                    Image(systemName: track.artwork.symbol)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(track.title)
                        .font(.system(size: max(10, iconSize * 0.38), weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                .padding(iconSize * 0.56)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var shouldUseTextOnlyFallback: Bool {
        track.searchSong != nil || track.sourceName != nil
    }

    @ViewBuilder
    private var artworkFallback: some View {
        TrackArtworkFallbackView(
            platformTitle: track.searchSong?.source.title ?? track.sourceName ?? track.artwork.label,
            trackTitle: track.title,
            cornerRadius: cornerRadius,
            tintColors: track.artwork.colors
        )
    }
}

struct TrackArtworkFallbackView: View {
    let platformTitle: String
    let trackTitle: String
    let cornerRadius: CGFloat
    let tintColors: [Color]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: tintColors + [Color.black.opacity(0.68)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.clear, Color.black.opacity(0.26)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(platformTitle.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(trackTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String
    var showsSettingsButton: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Date(), format: .dateTime.month(.abbreviated).day())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.45))

                Text(title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .layoutPriority(1)

            if showsSettingsButton {
                SettingsEntryButton()
                    .padding(.top, 2)
            }
        }
    }
}

private struct SettingsSheetNavigationContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content
            }
        } else {
            NavigationView {
                content
            }
            .navigationViewStyle(.stack)
        }
    }
}

private struct SettingsEntryButton: View {
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "gearshape.fill")
                    .font(.subheadline.weight(.semibold))

                Text("设置")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) {
            SettingsSheetNavigationContainer {
                SettingsView()
            }
            .preferredColorScheme(.dark)
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    @EnvironmentObject private var musicSearch: MusicSearchViewModel

    @State private var isSourceManagerPresented = false
    @State private var alertMessage: String?

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    settingsHeroCard

                    SettingsPanel(
                        title: "播放偏好",
                        subtitle: "把默认音质放到一处，切换后立刻生效。"
                    ) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Label("默认音质", systemImage: "music.note")
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                Spacer()

                                Text(sourceLibrary.defaultPlaybackQuality.shortLabel)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.white.opacity(0.66))
                            }

                            HStack(spacing: 8) {
                                ForEach(PlaybackQualityPreference.allCases) { quality in
                                    Button {
                                        sourceLibrary.defaultPlaybackQuality = quality
                                    } label: {
                                        SettingsQualityIconOption(
                                            quality: quality,
                                            isSelected: sourceLibrary.defaultPlaybackQuality == quality
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(sourceLibrary.defaultPlaybackQuality.title)
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                Text(sourceLibrary.defaultPlaybackQuality.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.white.opacity(0.66))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )

                            Text("实际播放时会优先使用你选中的默认音质；如果目标平台没有这个音质，会自动切到最近可用的档位。")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.58))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    SettingsPanel(
                        title: "音源与解析",
                        subtitle: "集中放置跟搜索、解析和当前音源相关的开关。"
                    ) {
                        VStack(alignment: .leading, spacing: 16) {
                            Toggle(isOn: $sourceLibrary.enableAutomaticSourceFallback) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("自动切换可用音源")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    Text("当前音源不支持目标平台时，自动尝试切到可解析的平台。")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.white.opacity(0.66))
                                }
                            }
                            .tint(Color(red: 0.48, green: 0.92, blue: 0.72))

                            SettingsStatusRow(
                                title: "当前激活音源",
                                value: sourceLibrary.activeSource?.name ?? "未激活"
                            )

                            Button {
                                isSourceManagerPresented = true
                            } label: {
                                SettingsActionRow(
                                    title: "管理音乐源",
                                    subtitle: "导入、切换、重解析或删除音乐源",
                                    symbol: "waveform.and.magnifyingglass"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    SettingsPanel(
                        title: "数据与缓存",
                        subtitle: "清理历史记录和临时缓存，保持应用轻一点。"
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            SettingsStatusRow(
                                title: "搜索历史",
                                value: musicSearch.searchHistory.isEmpty ? "暂无记录" : "\(musicSearch.searchHistory.count) 条"
                            )

                            Button {
                                musicSearch.clearSearchHistory()
                            } label: {
                                SettingsActionRow(
                                    title: "清空搜索历史",
                                    subtitle: musicSearch.searchHistory.isEmpty ? "当前没有可清理的搜索记录" : "删除最近搜索关键词",
                                    symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                                )
                                .opacity(musicSearch.searchHistory.isEmpty ? 0.55 : 1)
                            }
                            .buttonStyle(.plain)
                            .disabled(musicSearch.searchHistory.isEmpty)

                            SettingsStatusRow(
                                title: "媒体缓存",
                                value: sourceLibrary.mediaCacheSummary.isEmpty
                                    ? "暂无缓存"
                                    : "\(sourceLibrary.mediaCacheSummary.fileCount) 个文件 · \(sourceLibrary.mediaCacheSummary.formattedSize)"
                            )

                            Button {
                                do {
                                    try sourceLibrary.clearMediaCache()
                                } catch {
                                    alertMessage = error.localizedDescription
                                }
                            } label: {
                                SettingsActionRow(
                                    title: "清理媒体缓存",
                                    subtitle: sourceLibrary.mediaCacheSummary.isEmpty ? "当前没有缓存文件" : "删除已缓存的音频文件",
                                    symbol: "externaldrive.badge.minus"
                                )
                                .opacity(sourceLibrary.mediaCacheSummary.isEmpty ? 0.55 : 1)
                            }
                            .buttonStyle(.plain)
                            .disabled(sourceLibrary.mediaCacheSummary.isEmpty)
                        }
                    }

                    SettingsPanel(
                        title: "关于当前会话",
                        subtitle: "把当前状态整理成一张小卡片，方便快速确认。"
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            SettingsStatusRow(title: "当前页面", value: player.selectedTab.title)
                            SettingsStatusRow(
                                title: "当前播放",
                                value: player.currentTrack?.title ?? "尚未开始播放"
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    dismiss()
                }
                .foregroundStyle(.white)
            }
        }
        .sheet(isPresented: $isSourceManagerPresented) {
            MusicSourceManagementView()
                .environmentObject(sourceLibrary)
                .environmentObject(player)
                .environmentObject(musicSearch)
        }
        .alert(
            "设置操作失败",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        alertMessage = nil
                    }
                }
            ),
            actions: {
                Button("知道了", role: .cancel) {}
            },
            message: {
                Text(alertMessage ?? "")
            }
        )
    }

    private var settingsHeroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("XMusic 设置")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("把常用控制收进一个入口里。现在可以直接从底部导航进入设置，不用再到各个页面里找入口。")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                SettingsInfoPill(
                    title: "音源",
                    value: sourceLibrary.sources.isEmpty ? "0 个" : "\(sourceLibrary.sources.count) 个"
                )

                SettingsInfoPill(
                    title: "搜索记录",
                    value: musicSearch.searchHistory.isEmpty ? "空" : "\(musicSearch.searchHistory.count) 条"
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct SettingsPanel<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.62))
            }

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct SettingsActionRow: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay {
                    Image(systemName: symbol)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.34))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct SettingsStatusRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.66))

            Spacer(minLength: 0)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct SettingsQualityIconOption: View {
    let quality: PlaybackQualityPreference
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isSelected
                            ? Color(red: 0.48, green: 0.92, blue: 0.72).opacity(0.18)
                            : Color.white.opacity(0.06)
                    )

                Image(systemName: quality.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : Color.white.opacity(0.74))
            }
            .frame(width: 54, height: 54)

            Text(quality.shortLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? .white : Color.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(.horizontal, 6)
        .padding(.vertical, 12)
        .background(Color.white.opacity(isSelected ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    isSelected ? Color(red: 0.48, green: 0.92, blue: 0.72).opacity(0.28) : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
    }
}

private struct SettingsInfoPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.48))

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct SectionHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.62))
        }
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.07, blue: 0.10),
                    Color(red: 0.04, green: 0.04, blue: 0.06),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.99, green: 0.28, blue: 0.32).opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: -120, y: -260)

            Circle()
                .fill(Color(red: 0.23, green: 0.66, blue: 0.88).opacity(0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 86)
                .offset(x: 140, y: 120)
        }
    }
}

enum ChromeBarMetrics {
    static func height(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 56 : 60
    }

    static func miniPlayerArtworkSize(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 40 : 44
    }

    static func miniPlayerControlSize(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 34 : 36
    }

    static func tabItemHeight(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        height(for: sizeClass) - 6
    }
}

private struct TrackRow: View {
    let track: Track
    let index: Int
    let isCurrent: Bool
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        return Button(action: action) {
            HStack(spacing: 14) {
                Text(index.formatted())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .frame(width: 22)

                ArtworkView(track: track, cornerRadius: 18, iconSize: 18)
                    .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: 6) {
                    Text(track.title)
                        .font(.headline)
                        .foregroundStyle(isCurrent ? Color(red: 1.00, green: 0.43, blue: 0.42) : .white)
                        .lineLimit(1)

                    Text("\(track.artist) • \(track.album)")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.64))
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Image(systemName: isCurrent && isPlaying ? "speaker.wave.2.fill" : "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isCurrent ? Color(red: 1.00, green: 0.43, blue: 0.42) : Color.white.opacity(0.86))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(isCurrent ? 0.11 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(isCurrent ? 0.16 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
