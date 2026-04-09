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
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        artworkFallback
                    case .empty:
                        artworkFallback
                    @unknown default:
                        artworkFallback
                    }
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
        GeometryReader { geo in
            let isCompact = min(geo.size.width, geo.size.height) < 60

            ZStack {
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

                if isCompact {
                    Image(systemName: "music.note")
                        .font(.system(size: min(geo.size.width, geo.size.height) * 0.4, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                } else {
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
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct PageHeader: View {
    let title: String
    var subtitle: String = ""
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

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
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
                VStack(alignment: .leading, spacing: 16) {
                    Text("设置")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    SettingsPanel(
                        title: "播放偏好"
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("默认音质")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    Text(sourceLibrary.defaultPlaybackQuality.title)
                                        .font(.caption)
                                        .foregroundStyle(Color.white.opacity(0.58))
                                }

                                Spacer(minLength: 0)

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
                        }
                    }

                    SettingsPanel(
                        title: "音源与解析"
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $sourceLibrary.enableAutomaticSourceFallback) {
                                Text("自动切换可用音源")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                            .tint(Color(red: 0.48, green: 0.92, blue: 0.72))

                            SettingsInlineActionRow(
                                title: "当前音源",
                                value: sourceLibrary.activeSource?.name ?? "未激活",
                                actionTitle: "管理",
                                symbol: "waveform.and.magnifyingglass"
                            ) {
                                isSourceManagerPresented = true
                            }
                        }
                    }

                    SettingsPanel(
                        title: "数据与缓存"
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            SettingsInlineActionRow(
                                title: "搜索历史",
                                value: musicSearch.searchHistory.isEmpty ? "暂无记录" : "\(musicSearch.searchHistory.count) 条",
                                actionTitle: "清空",
                                symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                                isDisabled: musicSearch.searchHistory.isEmpty
                            ) {
                                musicSearch.clearSearchHistory()
                            }

                            SettingsInlineActionRow(
                                title: "媒体缓存",
                                value: sourceLibrary.mediaCacheSummary.isEmpty
                                    ? "暂无缓存"
                                    : "\(sourceLibrary.mediaCacheSummary.fileCount) 个文件 · \(sourceLibrary.mediaCacheSummary.formattedSize)",
                                actionTitle: "清理",
                                symbol: "externaldrive.badge.minus",
                                isDisabled: sourceLibrary.mediaCacheSummary.isEmpty
                            ) {
                                do {
                                    try sourceLibrary.clearMediaCache()
                                } catch {
                                    alertMessage = error.localizedDescription
                                }
                            }
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
}

private struct SettingsPanel<Content: View>: View {
    let title: String
    var subtitle: String = ""
    let content: Content

    init(
        title: String,
        subtitle: String = "",
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.62))
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct SettingsInlineActionRow: View {
    let title: String
    let value: String
    let actionTitle: String
    let symbol: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.66))

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            Button(action: action) {
                Label(actionTitle, systemImage: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.55 : 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct SettingsQualityIconOption: View {
    let quality: PlaybackQualityPreference
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isSelected
                            ? Color(red: 0.48, green: 0.92, blue: 0.72).opacity(0.18)
                            : Color.white.opacity(0.06)
                    )

                Image(systemName: quality.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : Color.white.opacity(0.74))
            }
            .frame(width: 42, height: 42)

            Text(quality.shortLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? .white : Color.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 68)
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(Color.white.opacity(isSelected ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected ? Color(red: 0.48, green: 0.92, blue: 0.72).opacity(0.28) : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.62))
            }
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
