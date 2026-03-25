import SwiftUI

struct PlaylistView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    @EnvironmentObject private var musicSearch: MusicSearchViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var playlistModel = MusicPlaylistViewModel()
    @State private var isSourceManagerPresented = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                PageHeader(title: "歌单", subtitle: "先挑一张，再把整张列表顺着放下去")

                SourceManagerEntryCard(
                    sourceCount: sourceLibrary.sources.count,
                    activeSourceName: sourceLibrary.activeSource?.name
                ) {
                    isSourceManagerPresented = true
                }

                if sourceLibrary.activeSource == nil {
                    playlistNoticeCard(
                        title: "还没有激活音乐源",
                        message: "歌单页会按当前激活音源支持的平台去加载真实歌单。先导入并激活一个音源，再回来浏览。"
                    )
                } else if playlistModel.supportedSources.isEmpty {
                    playlistNoticeCard(
                        title: "当前音源不包含在线平台",
                        message: "这个音源没有声明可用的歌单平台能力，所以暂时没法加载平台歌单。你可以切换到支持 kw / kg / tx / wy / mg 的音源。"
                    )
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeading(title: "数据来源", subtitle: "歌单列表会跟随当前激活音源支持的平台变化")

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(playlistModel.supportedSources) { source in
                                    PlaylistFilterPill(
                                        title: source.title,
                                        isSelected: playlistModel.selectedSource == source
                                    ) {
                                        playlistModel.selectedSource = source
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }

                        if playlistModel.availableSorts.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(playlistModel.availableSorts) { sort in
                                        PlaylistFilterPill(
                                            title: sort.title,
                                            isSelected: playlistModel.selectedSort == sort
                                        ) {
                                            playlistModel.selectedSort = sort
                                        }
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                    }

                    if let errorMessage = playlistModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Color(red: 1.00, green: 0.66, blue: 0.38))
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }

                    if playlistModel.isLoadingList && playlistModel.playlists.isEmpty {
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.white)

                            Text("正在从 \(playlistModel.selectedSource?.title ?? "当前平台") 加载歌单…")
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.68))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                    } else if playlistModel.playlists.isEmpty {
                        playlistNoticeCard(
                            title: "这一页没有歌单",
                            message: "当前平台返回了空列表。你可以换一个支持的平台，或者重新导入别的音源试试。"
                        )
                    } else {
                        if let selectedPlaylist = playlistModel.selectedPlaylist {
                            PlaylistDetailHeroCard(playlist: selectedPlaylist)
                        }

                        LazyVGrid(columns: playlistColumns, spacing: 14) {
                            ForEach(playlistModel.playlists) { playlist in
                                PlaylistRowCard(
                                    playlist: playlist,
                                    isSelected: playlistModel.selectedPlaylistKey == playlist.stableKey
                                ) {
                                    switchPlaylistAndPlay(playlist)
                                }
                            }
                        }

                        if let selectedPlaylist = playlistModel.selectedPlaylist {
                            if playlistModel.isLoadingDetail && selectedPlaylist.tracks.isEmpty {
                                VStack(spacing: 14) {
                                    ProgressView()
                                        .tint(.white)
                                    Text("正在加载歌单详情和曲目…")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.white.opacity(0.66))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)
                            } else if !selectedPlaylist.tracks.isEmpty {
                                TrackStack(
                                    title: "\(selectedPlaylist.title) 曲目",
                                    subtitle: "\(selectedPlaylist.curator) · 共 \(selectedPlaylist.trackCount) 首",
                                    tracks: selectedPlaylist.tracks
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
        .onAppear {
            syncPlaylists()
        }
        .onChange(of: sourceLibrary.activeSourceID) { _ in
            syncPlaylists()
        }
        .onChange(of: playlistModel.selectedSource) { _ in
            if !playlistModel.availableSorts.contains(playlistModel.selectedSort),
               let firstSort = playlistModel.availableSorts.first {
                playlistModel.selectedSort = firstSort
            }
            if playlistModel.selectedSource != nil {
                playlistModel.reload()
            }
        }
        .onChange(of: playlistModel.selectedSort) { _ in
            if playlistModel.selectedSource != nil {
                playlistModel.reload()
            }
        }
        .sheet(isPresented: $isSourceManagerPresented) {
            MusicSourceManagementView()
                .environmentObject(sourceLibrary)
                .environmentObject(musicSearch)
                .environmentObject(player)
        }
    }

    @ViewBuilder
    private func playlistNoticeCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func syncPlaylists() {
        playlistModel.configure(with: sourceLibrary.activeSource)
        if playlistModel.selectedSource != nil {
            playlistModel.reload()
        }
    }

    private func switchPlaylistAndPlay(_ playlist: Playlist) {
        playlistModel.selectPlaylist(with: playlist.stableKey)

        Task {
            if playlist.tracks.isEmpty {
                await playlistModel.ensureDetailLoaded(for: playlist.stableKey)
            }

            guard let loadedPlaylist = playlistModel.playlists.first(where: { $0.stableKey == playlist.stableKey }),
                  let firstTrack = loadedPlaylist.tracks.first else {
                return
            }

            await MainActor.run {
                player.play(firstTrack, from: loadedPlaylist.tracks)
            }
        }
    }

    private var playlistColumns: [GridItem] {
        [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 248 : 290), spacing: 14)]
    }
}

private struct PlaylistDetailHeroCard: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let playlist: Playlist
    private let metricColumns = [GridItem(.adaptive(minimum: 112), spacing: 10)]

    var body: some View {
        let metaLine = [playlist.curator, playlist.updatedLabel.isEmpty ? nil : playlist.updatedLabel]
            .compactMap { $0 }
            .joined(separator: " · ")
        let descriptionText = playlist.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "来自 \(playlist.source?.title ?? "当前平台") 的歌单详情。"
            : playlist.description

        HStack(alignment: .top, spacing: isCompactLayout ? 14 : 20) {
            PlaylistCoverView(playlist: playlist, cornerRadius: 30, iconSize: 34)
                .frame(width: artworkSize, height: artworkSize)

            VStack(alignment: .leading, spacing: 14) {
                Text(playlist.primaryCategory.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.58))

                Text(playlist.title)
                    .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(isCompactLayout ? 3 : 2)
                    .minimumScaleFactor(0.86)

                if !metaLine.isEmpty {
                    Text(metaLine)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                }

                Text(descriptionText)
                    .font(isCompactLayout ? .subheadline : .body)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .lineLimit(isCompactLayout ? 4 : nil)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 10) {
                    PlaylistMetricPill(title: "曲目", value: "\(playlist.trackCount) 首")
                    if playlist.hasPlayCount {
                        PlaylistMetricPill(title: "播放", value: playlist.playCountText)
                    }
                    PlaylistMetricPill(title: "来源", value: playlist.source?.title ?? "本地")
                    if !playlist.updatedLabel.isEmpty {
                        PlaylistMetricPill(title: "更新", value: playlist.updatedLabel)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        if let firstTrack = playlist.tracks.first {
                            player.play(firstTrack, from: playlist.tracks)
                        }
                    } label: {
                        Label("播放歌单", systemImage: "play.fill")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white, in: Capsule())
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)

                    Button {
                        if let randomTrack = playlist.tracks.randomElement() {
                            player.play(randomTrack, from: playlist.tracks)
                        }
                    } label: {
                        Label("随机播放", systemImage: "shuffle")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.10), in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(isCompactLayout ? 18 : 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: playlist.artwork.colors.map { $0.opacity(0.92) } + [Color.black.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
        .shadow(color: playlist.artwork.glow.opacity(0.20), radius: 32, x: 0, y: 18)
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var artworkSize: CGFloat {
        isCompactLayout ? 132 : 172
    }

    private var titleFontSize: CGFloat {
        isCompactLayout ? 27 : 32
    }
}

private struct PlaylistRowCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let playlist: Playlist
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: horizontalSizeClass == .compact ? 12 : 16) {
                PlaylistCoverView(playlist: playlist, cornerRadius: 26, iconSize: 24)
                    .frame(width: coverSize, height: coverSize)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 8) {
                        PlaylistSelectionBadge(
                            title: isSelected ? "已选中" : playlist.primaryCategory,
                            systemImage: isSelected ? "checkmark.circle.fill" : "square.stack.3d.up.fill",
                            isHighlighted: isSelected,
                            tint: playlist.artwork.glow
                        )

                        Spacer(minLength: 0)

                        Image(systemName: isSelected ? "waveform.circle.fill" : "arrow.up.forward.circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? .white : Color.white.opacity(0.32))
                    }

                    Text(playlist.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(playlist.curator)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.68))
                        .lineLimit(1)

                    Text(playlist.summary)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(isSelected ? 0.72 : 0.58))
                        .lineLimit(isSelected ? 3 : 2)

                    HStack(spacing: 12) {
                        Label("\(playlist.trackCount)", systemImage: "music.note.list")
                        if playlist.hasPlayCount {
                            Label(playlist.playCountText, systemImage: "headphones")
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.62))

                    HStack(spacing: 8) {
                        ForEach(Array(playlist.categories.prefix(3)), id: \.self) { category in
                            Text(category)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isSelected ? .white : .white.opacity(0.82))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? playlist.artwork.glow.opacity(0.22) : Color.white.opacity(0.08))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(isSelected ? 0.12 : 0), lineWidth: 1)
                                )
                        }
                    }

                    if isSelected {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("当前正在查看这张歌单的详情和曲目")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.84))
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 0)
            }
            .padding(horizontalSizeClass == .compact ? 14 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .fill(Color.white.opacity(isSelected ? 0.10 : 0.06))

                    if isSelected {
                        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        playlist.artwork.glow.opacity(0.26),
                                        playlist.artwork.colors.first?.opacity(0.18) ?? Color.white.opacity(0.10),
                                        Color.white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Circle()
                            .fill(playlist.artwork.glow.opacity(0.30))
                            .frame(width: coverSize * 1.05, height: coverSize * 1.05)
                            .blur(radius: 28)
                            .offset(x: -coverSize * 0.12, y: -coverSize * 0.08)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.62),
                                        playlist.artwork.glow.opacity(0.88)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(Color.white.opacity(0.08)),
                        lineWidth: isSelected ? 1.2 : 1
                    )
            )
            .shadow(
                color: isSelected ? playlist.artwork.glow.opacity(0.32) : Color.black.opacity(0.16),
                radius: isSelected ? 24 : 12,
                x: 0,
                y: isSelected ? 16 : 8
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isSelected)
    }

    private var coverSize: CGFloat {
        horizontalSizeClass == .compact ? 92 : 108
    }

    private var cardCornerRadius: CGFloat {
        30
    }
}

private struct PlaylistSelectionBadge: View {
    let title: String
    let systemImage: String
    let isHighlighted: Bool
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(isHighlighted ? 0.96 : 0.72))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isHighlighted ? tint.opacity(0.22) : Color.white.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(isHighlighted ? 0.12 : 0.08), lineWidth: 1)
            )
    }
}

private struct PlaylistFilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(isSelected ? 0 : 0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct PlaylistMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.52))

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct PlaylistCoverView: View {
    let playlist: Playlist
    let cornerRadius: CGFloat
    let iconSize: CGFloat

    var body: some View {
        ZStack {
            if let remoteArtworkURL = playlist.remoteArtworkURL {
                AsyncImage(url: remoteArtworkURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: playlist.artwork.colors + [Color.black.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: playlist.artwork.colors + [Color.black.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.08), Color.black.opacity(0.62)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(alignment: .leading, spacing: iconSize * 0.26) {
                HStack(alignment: .top) {
                    Text((playlist.source?.title ?? playlist.primaryCategory).uppercased())
                        .font(.system(size: max(9, iconSize * 0.28), weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.64))

                    Spacer()

                    Image(systemName: playlist.artwork.symbol)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                }

                Spacer()

                Text(playlist.artwork.label.uppercased())
                    .font(.system(size: max(10, iconSize * 0.32), weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.58))

                Text(playlist.title)
                    .font(.system(size: max(11, iconSize * 0.42), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .padding(iconSize * 0.54)
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: playlist.artwork.glow.opacity(0.18), radius: 24, x: 0, y: 14)
    }
}

#Preview {
    let player = MusicPlayerViewModel()
    player.currentTrack = DemoLibrary.featuredTrack
    player.isNowPlayingPresented = true

    return InlineNowPlayingPanel {
    }
    .environmentObject(player)
}
