import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private struct PlaylistNavigationContainer<Content: View>: View {
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

private extension View {
    @ViewBuilder
    func playlistRootNavigationHidden() -> some View {
        if #available(iOS 16.0, *) {
            self.toolbar(.hidden, for: .navigationBar)
        } else {
            self.navigationBarHidden(true)
        }
    }
}

private struct PlaylistDetailScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#if canImport(UIKit)
private struct PlaylistNavigationBarConfigurator: UIViewControllerRepresentable {
    let backgroundColor: UIColor
    let foregroundColor: UIColor
    let shadowColor: UIColor?

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.apply(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            shadowColor: shadowColor
        )
    }

    final class Controller: UIViewController {
        private var backgroundColor: UIColor = .white
        private var foregroundColor: UIColor = .black
        private var shadowColor: UIColor?

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            updateAppearance()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            updateAppearance()
        }

        func apply(backgroundColor: UIColor, foregroundColor: UIColor, shadowColor: UIColor?) {
            self.backgroundColor = backgroundColor
            self.foregroundColor = foregroundColor
            self.shadowColor = shadowColor
            updateAppearance()
        }

        private func updateAppearance() {
            guard let navigationBar = navigationController?.navigationBar else { return }

            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = backgroundColor
            appearance.shadowColor = shadowColor
            appearance.titleTextAttributes = [.foregroundColor: foregroundColor]

            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
            navigationBar.tintColor = foregroundColor
            navigationBar.isTranslucent = false
        }
    }
}
#endif

struct PlaylistView: View {
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var playlistModel = MusicPlaylistViewModel()
    @State private var isSourceManagerPresented = false

    var body: some View {
        PlaylistNavigationContainer {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 28) {
                    PageHeader(title: "歌单", subtitle: "先挑一张，再点进详情页慢慢看")

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
                            LazyVGrid(columns: playlistColumns, spacing: 14) {
                                ForEach(playlistModel.playlists) { playlist in
                                    NavigationLink {
                                        PlaylistDetailPage(
                                            playlistModel: playlistModel,
                                            playlistKey: playlist.stableKey
                                        )
                                    } label: {
                                        PlaylistRowCard(
                                            playlist: playlist,
                                            isSelected: playlistModel.selectedPlaylistKey == playlist.stableKey
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .simultaneousGesture(
                                        TapGesture().onEnded {
                                            playlistModel.selectPlaylist(with: playlist.stableKey)
                                        }
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
            .playlistRootNavigationHidden()
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
            PlaylistSourceManagementSheet()
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

    private var playlistColumns: [GridItem] {
        [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 268 : 300), spacing: 14)]
    }
}

private struct PlaylistDetailHeroCard: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let playlist: Playlist
    let resolvePlaybackQueue: @MainActor () async -> [Track]
    private let metricColumns = [GridItem(.adaptive(minimum: 112), spacing: 10)]

    var body: some View {
        let metaLine = [playlist.curator, playlist.updatedLabel.isEmpty ? nil : playlist.updatedLabel]
            .compactMap { $0 }
            .joined(separator: " · ")
        let descriptionText = playlist.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "来自 \(playlist.source?.title ?? "当前平台") 的歌单详情。"
            : playlist.description

        Group {
            if isCompactLayout {
                compactContent(metaLine: metaLine, descriptionText: descriptionText)
            } else {
                regularContent(metaLine: metaLine, descriptionText: descriptionText)
            }
        }
        .padding(isCompactLayout ? 16 : 22)
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
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var artworkSize: CGFloat {
        isCompactLayout ? 132 : 172
    }

    private var compactArtworkSize: CGFloat {
        104
    }

    private var titleFontSize: CGFloat {
        isCompactLayout ? 27 : 32
    }

    @ViewBuilder
    private func regularContent(metaLine: String, descriptionText: String) -> some View {
        HStack(alignment: .top, spacing: 20) {
            PlaylistCoverView(playlist: playlist, cornerRadius: 30, iconSize: 34)
                .frame(width: artworkSize, height: artworkSize)

            VStack(alignment: .leading, spacing: 14) {
                Text(playlist.primaryCategory.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.58))

                Text(playlist.title)
                    .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                if !metaLine.isEmpty {
                    Text(metaLine)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                }

                Text(descriptionText)
                    .font(.body)
                    .foregroundStyle(Color.white.opacity(0.78))
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

                detailActions(compact: false)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func compactContent(metaLine: String, descriptionText: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                PlaylistCoverView(playlist: playlist, cornerRadius: 26, iconSize: 26)
                    .frame(width: compactArtworkSize, height: compactArtworkSize)

                VStack(alignment: .leading, spacing: 8) {
                    Text(playlist.source?.title ?? playlist.primaryCategory)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.58))

                    Text(playlist.title)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if !metaLine.isEmpty {
                        Text(metaLine)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)
            }

            Text(descriptionText)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.74))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            compactMetrics

            detailActions(compact: true)
        }
    }

    @ViewBuilder
    private var compactMetrics: some View {
        HStack(spacing: 8) {
            CompactPlaylistMetricChip(title: "曲目", value: "\(playlist.trackCount) 首")
            if playlist.hasPlayCount {
                CompactPlaylistMetricChip(title: "播放", value: playlist.playCountText)
            }
            CompactPlaylistMetricChip(title: "来源", value: playlist.source?.title ?? "本地")
        }
    }

    @ViewBuilder
    private func detailActions(compact: Bool) -> some View {
        HStack(spacing: 10) {
            Button {
                Task {
                    await playPlaylist(shuffled: false)
                }
            } label: {
                Label("播放歌单", systemImage: "play.fill")
                    .font(compact ? .subheadline.weight(.bold) : .headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, compact ? 12 : 16)
                    .padding(.vertical, compact ? 12 : 10)
                    .background(Color.white, in: Capsule())
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    await playPlaylist(shuffled: true)
                }
            } label: {
                Label("随机播放", systemImage: "shuffle")
                    .font(compact ? .subheadline.weight(.bold) : .headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, compact ? 12 : 16)
                    .padding(.vertical, compact ? 12 : 10)
                    .background(Color.white.opacity(0.10), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .labelStyle(.titleAndIcon)
    }

    @MainActor
    private func playPlaylist(shuffled: Bool) async {
        let queue = await resolvePlaybackQueue()
        guard !queue.isEmpty else { return }

        let track = shuffled ? (queue.randomElement() ?? queue[0]) : queue[0]
        player.play(track, from: queue)
    }
}

private struct CompactPlaylistMetricChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.52))

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct PlaylistDetailPage: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var player: MusicPlayerViewModel
    @ObservedObject var playlistModel: MusicPlaylistViewModel
    let playlistKey: String
    @State private var showsNavigationTitle = false
    @State private var playbackTask: Task<Void, Never>?
    @State private var isStartingPlayback = false

    private let accentColor = Color(red: 0.89, green: 0.28, blue: 0.32)

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    if let playlist = currentPlaylist {
                        VStack(spacing: 26) {
                            PlaylistCoverView(
                                playlist: playlist,
                                cornerRadius: 26,
                                iconSize: 32,
                                showsGradientOverlay: false
                            )
                            .frame(width: coverSize, height: coverSize)
                            .padding(.top, 10)

                            VStack(spacing: 8) {
                                Text(playlist.title)
                                    .font(.system(size: 31, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.black)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)

                                Text(playlist.curator)
                                    .font(.title3.weight(.medium))
                                    .foregroundStyle(accentColor)
                                    .lineLimit(1)

                                Text(subtitleText(for: playlist))
                                    .font(.subheadline)
                                    .foregroundStyle(Color.black.opacity(0.46))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: 320)

                            HStack(spacing: 12) {
                            PlaylistDetailActionButton(
                                title: "播放",
                                systemImage: "play.fill",
                                tint: accentColor
                            ) {
                                startPlayback(shuffled: false)
                            }

                            PlaylistDetailActionButton(
                                title: "随机",
                                systemImage: "shuffle",
                                tint: accentColor
                            ) {
                                startPlayback(shuffled: true)
                            }
                        }
                        .disabled(isStartingPlayback)
                        }
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .preference(
                                        key: PlaylistDetailScrollOffsetKey.self,
                                        value: geometry.frame(in: .named("playlist-detail-scroll")).maxY
                                    )
                            }
                        )

                        if currentTracks.isEmpty, playlistModel.isLoadingDetail {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(accentColor)
                                Text("正在加载歌单曲目…")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.black.opacity(0.52))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                        } else if currentTracks.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "music.note.list")
                                    .font(.title2)
                                    .foregroundStyle(Color.black.opacity(0.35))

                                Text("这张歌单暂时还没有可展示的曲目")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.black.opacity(0.54))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(currentTracks.enumerated()), id: \.element.id) { index, track in
                                    PlaylistDetailTrackRow(
                                        track: track,
                                        index: index + 1,
                                        tracks: currentTracks,
                                        accentColor: accentColor
                                    )

                                    if index < currentTracks.count - 1 {
                                        Divider()
                                            .padding(.leading, 66)
                                    }
                                }
                            }
                            .padding(.horizontal, 6)
                        }
                    } else {
                        ProgressView()
                            .tint(accentColor)
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            .coordinateSpace(name: "playlist-detail-scroll")
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .frame(width: 32, height: 32)
                }
            }

            ToolbarItem(placement: .principal) {
                Text(currentPlaylist?.title ?? "")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .opacity(showsNavigationTitle ? 1 : 0)
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task {
                        await playlistModel.ensureDetailLoaded(for: playlistKey)
                    }
                } label: {
                    detailToolbarIcon("arrow.clockwise")
                }

                Menu {
                    Button("播放歌单", systemImage: "play.fill") {
                        startPlayback(shuffled: false)
                    }
                    Button("随机播放", systemImage: "shuffle") {
                        startPlayback(shuffled: true)
                    }
                } label: {
                    detailToolbarIcon("ellipsis")
                }
            }
        }
        .task(id: playlistKey) {
            await MainActor.run {
                playlistModel.selectedPlaylistKey = playlistKey
                showsNavigationTitle = false
            }
            await playlistModel.ensureDetailLoaded(for: playlistKey)
        }
        .onDisappear {
            playbackTask?.cancel()
            playbackTask = nil
            isStartingPlayback = false
        }
        .onPreferenceChange(PlaylistDetailScrollOffsetKey.self) { value in
            let nextValue = value < 120
            guard nextValue != showsNavigationTitle else { return }

            withAnimation(.easeInOut(duration: 0.18)) {
                showsNavigationTitle = nextValue
            }
        }
        .preferredColorScheme(ColorScheme.light)
#if canImport(UIKit)
        .background(
            PlaylistNavigationBarConfigurator(
                backgroundColor: .white,
                foregroundColor: .black,
                shadowColor: .clear
            )
        )
#endif
    }

    private var currentPlaylist: Playlist? {
        playlistModel.playlists.first(where: { $0.stableKey == playlistKey })
    }

    private var currentTracks: [Track] {
        currentPlaylist?.tracks ?? []
    }

    private var coverSize: CGFloat {
        224
    }

    private func subtitleText(for playlist: Playlist) -> String {
        var parts = [playlist.source?.title ?? playlist.primaryCategory, "\(playlist.trackCount) 首"]
        if playlist.hasPlayCount {
            parts.append("\(playlist.playCountText) 播放")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func detailToolbarIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.black.opacity(0.72))
            .frame(width: 34, height: 34)
            .background(Color.black.opacity(0.05), in: Circle())
    }

    @MainActor
    private func playPlaylist(shuffled: Bool) async {
        if currentTracks.isEmpty {
            await playlistModel.ensureDetailLoaded(for: playlistKey)
        }

        let tracks = currentTracks
        guard !tracks.isEmpty else { return }

        let track = shuffled ? (tracks.randomElement() ?? tracks[0]) : tracks[0]
        player.play(track, from: tracks)
    }

    private func startPlayback(shuffled: Bool) {
        guard playbackTask == nil else { return }

        isStartingPlayback = true
        playbackTask = Task { @MainActor in
            defer {
                playbackTask = nil
                isStartingPlayback = false
            }
            await playPlaylist(shuffled: shuffled)
        }
    }
}

private struct PlaylistDetailActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(red: 0.95, green: 0.95, blue: 0.96), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct PlaylistDetailTrackRow: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    let track: Track
    let index: Int
    let tracks: [Track]
    let accentColor: Color

    var body: some View {
        let isCurrent = player.currentTrack == track

        Button {
            player.play(track, from: tracks)
        } label: {
            HStack(spacing: 12) {
                PlaylistTrackArtwork(track: track)
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.black)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(Color.black.opacity(0.52))
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                Text(index.formatted())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.26))

                Image(systemName: isCurrent && player.isPlaying ? "speaker.wave.2.fill" : "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isCurrent ? accentColor : Color.black.opacity(0.55))
                    .frame(width: 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PlaylistTrackArtwork: View {
    let track: Track

    var body: some View {
        ZStack {
            if let artworkURL = track.searchSong?.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackArtwork
                    }
                }
            } else {
                fallbackArtwork
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var fallbackArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: track.artwork.colors + [Color.black.opacity(0.24)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: track.artwork.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

private struct PlaylistRowCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let playlist: Playlist
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: horizontalSizeClass == .compact ? 10 : 14) {
            PlaylistCoverView(playlist: playlist, cornerRadius: 26, iconSize: 24)
                .frame(width: coverSize, height: coverSize)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    PlaylistSelectionBadge(
                        title: isSelected ? "已浏览" : playlist.primaryCategory,
                        systemImage: isSelected ? "checkmark.circle.fill" : "square.stack.3d.up.fill",
                        isHighlighted: isSelected,
                        tint: playlist.artwork.glow
                    )

                    Spacer(minLength: 0)
                }

                Text(playlist.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

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
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isSelected)
    }

    private var coverSize: CGFloat {
        horizontalSizeClass == .compact ? 82 : 98
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
    var showsGradientOverlay = true

    var body: some View {
        ZStack {
            coverArtwork

            if showsGradientOverlay {
                LinearGradient(
                    colors: [Color.white.opacity(0.06), Color.clear, Color.black.opacity(0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var coverArtwork: some View {
        if let remoteArtworkURL = playlist.remoteArtworkURL {
            AsyncImage(url: remoteArtworkURL) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    fallbackCover
                }
            }
        } else {
            fallbackCover
        }
    }

    private var fallbackCover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: playlist.artwork.colors + [Color.black.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: playlist.artwork.symbol)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}

private struct PlaylistSourceManagementSheet: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary

    var body: some View {
        MusicSourceManagementView()
            .environmentObject(player)
            .environmentObject(sourceLibrary)
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
