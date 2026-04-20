import SwiftUI

private struct SearchPlaylistDraftSession: Identifiable {
    let id = UUID()
    let draft: CustomPlaylistDraft
}

private struct SearchAlbumDetailSession: Identifiable {
    let id = UUID()
    let album: SearchAlbum
}

struct SearchView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    @EnvironmentObject private var musicSearch: MusicSearchViewModel
    @EnvironmentObject private var library: MusicLibraryViewModel
    @EnvironmentObject private var playlistModel: MusicPlaylistViewModel
    @State private var resolvingSongID: String?
    @State private var playbackError: String?
    @State private var actionMessage: String?
    @State private var isDebugPanelExpanded = true
    @State private var playbackDebugInfo: PlaybackDebugInfo?
    @State private var playlistDraftSession: SearchPlaylistDraftSession?
    @State private var albumDetailSession: SearchAlbumDetailSession?
    @State private var workingAlbumID: String?
    @State private var isEditingHistory = false
    private let isPlaybackDebugCardVisible = false
    private let isSearchDebugPanelVisible = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("搜索")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(SearchResultKind.allCases) { kind in
                            SearchSourcePill(
                                title: kind.title,
                                isSelected: musicSearch.selectedKind == kind
                            ) {
                                guard musicSearch.selectedKind != kind else { return }
                                musicSearch.selectedKind = kind
                                ensureSelectedSourceIsValid()
                                musicSearch.reload(allowedSources: searchableSources)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(searchableSourceTabs, id: \.rawValue) { source in
                            SearchSourcePill(
                                title: source.title,
                                isSelected: musicSearch.selectedSource == source
                            ) {
                                musicSearch.selectedSource = source
                                musicSearch.reload(allowedSources: searchableSources)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }

                if isSearchDebugPanelVisible,
                   !musicSearch.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    SearchDebugPanel(
                        entries: musicSearch.debugItems,
                        isExpanded: $isDebugPanelExpanded,
                        isSearching: musicSearch.isLoading || musicSearch.isLoadingMore
                    )
                }

                if musicSearch.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .firstTextBaseline) {
                            SectionHeadingView(title: "搜索记录")
                            Spacer()
                            if !musicSearch.searchHistory.isEmpty {
                                Button(isEditingHistory ? "完成" : "编辑") {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isEditingHistory.toggle()
                                    }
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.white.opacity(0.55))
                            }
                        }

                        if musicSearch.searchHistory.isEmpty {
                            Text("还没有搜索记录。")
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.62))
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        } else {
                            FlexibleTags(items: musicSearch.searchHistory, isEditing: isEditingHistory) { keyword in
                                musicSearch.query = keyword
                                musicSearch.reload(allowedSources: searchableSources)
                            } onDelete: { keyword in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    musicSearch.removeSearchHistory(keyword)
                                    if musicSearch.searchHistory.isEmpty {
                                        isEditingHistory = false
                                    }
                                }
                            }
                        }
                    }

                    SearchStatusCard(
                        activeSourceName: sourceLibrary.activeSource?.name,
                        fallbackEnabled: sourceLibrary.enableAutomaticSourceFallback
                    )
                } else if musicSearch.isLoading && activeResultCount == 0 {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)

                        Text("正在搜索 \(musicSearch.selectedSource.title)…")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.68))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 12) {
                            Text("搜索结果")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)

                            Spacer(minLength: 0)

                            Text(searchResultSummary)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.white.opacity(0.58))
                        }

                        if let playbackError {
                            Text(playbackError)
                                .font(.footnote)
                                .foregroundStyle(Color(red: 1.00, green: 0.66, blue: 0.38))
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }

                        if let actionMessage {
                            Text(actionMessage)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color(red: 0.57, green: 0.90, blue: 0.72))
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(red: 0.24, green: 0.55, blue: 0.38).opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color(red: 0.57, green: 0.90, blue: 0.72).opacity(0.18), lineWidth: 1)
                                )
                        }

                        if let playbackDebugInfo, isPlaybackDebugCardVisible {
                            PlaybackDebugCard(info: playbackDebugInfo)
                        }

                        if let errorMessage = musicSearch.errorMessage, activeResultCount == 0 {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(Color.white.opacity(0.72))
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }

                        switch musicSearch.selectedKind {
                        case .song:
                            ForEach(musicSearch.results) { song in
                                let track = Track.searchResultTrack(from: song)
                                OnlineSearchResultRow(
                                    song: song,
                                    isCurrent: player.isCurrentTrack(track),
                                    isResolving: resolvingSongID == song.id,
                                    isInLibrary: library.contains(track),
                                    customPlaylists: playlistModel.customPlaylists,
                                    playlistContainsTrack: { playlist in
                                        playlistModel.contains(track, in: playlist)
                                    }
                                ) {
                                    play(song)
                                } onAddToLibrary: {
                                    addToLibrary(song)
                                } onAddToCustomPlaylist: { playlist in
                                    addToCustomPlaylist(song, playlist: playlist)
                                } onCreateCustomPlaylist: {
                                    openCustomPlaylistEditor(prefilling: song)
                                }
                            }
                        case .album:
                            ForEach(musicSearch.albumResults) { album in
                                SearchAlbumResultRow(
                                    album: album,
                                    isWorking: workingAlbumID == album.id,
                                    isInLibrary: library.contains(
                                        album: LibraryAlbum(
                                            source: album.source,
                                            sourceAlbumID: album.sourceAlbumID,
                                            title: album.title,
                                            artist: album.artist,
                                            releaseDate: album.releaseDate,
                                            trackCount: 0,
                                            artworkURL: album.artworkURL,
                                            tracks: []
                                        )
                                    )
                                ) {
                                    openAlbumSongs(album)
                                } onPlayAlbum: {
                                    playAlbum(album)
                                } onAddToLibrary: {
                                    addAlbumToLibrary(album)
                                }
                            }
                        }

                        if musicSearch.canLoadMore {
                            Button {
                                musicSearch.loadMore(allowedSources: searchableSources)
                            } label: {
                                Text(musicSearch.isLoadingMore ? "正在加载…" : "加载更多")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
        .onAppear {
            if !musicSearch.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               activeResultCount == 0 {
                musicSearch.reload(allowedSources: searchableSources)
            }
        }
        .appOnChange(of: sourceLibrary.activeSourceID) {
            ensureSelectedSourceIsValid()
            if !musicSearch.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                musicSearch.reload(allowedSources: searchableSources)
            }
        }
        .sheet(item: $playlistDraftSession) { session in
            PlaylistCustomEditorSheet(
                draft: session.draft,
                isEditing: false
            ) { draft in
                playlistModel.saveCustomPlaylist(draft)
                actionMessage = "已创建自定义歌单。"
            }
        }
        .sheet(item: $albumDetailSession) { session in
            SearchAlbumDetailSheet(
                album: session.album,
                onPlay: play(_:),
                onAddToLibrary: addToLibrary(_:),
                onAddToCustomPlaylist: addToCustomPlaylist(_:playlist:),
                onCreateCustomPlaylist: openCustomPlaylistEditor(prefilling:)
            )
            .environmentObject(player)
            .environmentObject(sourceLibrary)
            .environmentObject(library)
            .environmentObject(playlistModel)
        }
        .appOnChange(of: musicSearch.query) {
            musicSearch.scheduleSearch(allowedSources: searchableSources)
            if !musicSearch.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                isEditingHistory = false
            }
        }
        .appOnChange(of: musicSearch.selectedKind) {
            ensureSelectedSourceIsValid()
        }
    }

    private var searchableSources: [SearchPlatformSource] {
        let sourceNames = sourceLibrary.activeSource?.capabilities.compactMap { SearchPlatformSource(rawValue: $0.source) } ?? []
        let allSources = sourceNames.isEmpty ? SearchPlatformSource.builtIn : sourceNames
        return allSources.filter { $0.supports(musicSearch.selectedKind) }
    }

    private var searchableSourceTabs: [SearchPlatformSource] {
        [.all] + searchableSources.sorted { lhs, rhs in
            searchSourcePriority(lhs) < searchSourcePriority(rhs)
        }
    }

    private var activeResultCount: Int {
        switch musicSearch.selectedKind {
        case .song:
            return musicSearch.results.count
        case .album:
            return musicSearch.albumResults.count
        }
    }

    private var searchResultSummary: String {
        switch musicSearch.selectedKind {
        case .song:
            return "\(musicSearch.results.count) 首"
        case .album:
            return "\(musicSearch.albumResults.count) 张专辑"
        }
    }

    private func searchSourcePriority(_ source: SearchPlatformSource) -> Int {
        switch source {
        case .tx:
            return 0
        case .kw:
            return 1
        case .kg:
            return 2
        case .wy:
            return 3
        case .mg:
            return 4
        case .all:
            return -1
        }
    }

    private func ensureSelectedSourceIsValid() {
        if !searchableSourceTabs.contains(musicSearch.selectedSource) {
            musicSearch.selectedSource = .all
        }
    }

    private func play(_ song: SearchSong) {
        let track = Track.searchResultTrack(from: song)
        guard !player.isCurrentTrack(track) else { return }

        playbackError = nil
        actionMessage = nil
        playbackDebugInfo = nil
        resolvingSongID = song.id

        Task {
            defer {
                Task { @MainActor in
                    resolvingSongID = nil
                }
            }

            guard let activeSource = sourceLibrary.activeSource else {
                await MainActor.run {
                    playbackError = "请先去设置页导入并激活一个音乐源，再播放搜索结果。"
                }
                return
            }

            await MainActor.run {
                playbackDebugInfo = sourceLibrary.inspectPlaybackPayload(for: song, with: activeSource)
            }

            do {
                player.setSearchPlaybackResolver { [sourceLibrary] nextSong in
                    guard let currentSource = sourceLibrary.activeSource else {
                        throw NSError(
                            domain: "XMusic.SearchPlayback",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "当前没有激活音乐源。"]
                        )
                    }
                    return try await sourceLibrary.resolvePlayback(for: nextSong, with: currentSource)
                }

                let resolution = try await sourceLibrary.resolvePlayback(
                    for: song,
                    with: activeSource
                )

                await MainActor.run {
                    playbackDebugInfo = resolution.debugInfo
                    let resolvedTrack = Track.searchResultTrack(
                        from: song,
                        sourceName: activeSource.name,
                        resolvedURL: resolution.playableURL
                    )
                    player.play(resolvedTrack, preferCachedQueue: true)
                }
            } catch {
                await MainActor.run {
                    if let latestDebugInfo = sourceLibrary.latestPlaybackDebugInfo {
                        playbackDebugInfo = latestDebugInfo
                    }
                    playbackError = error.localizedDescription
                }
            }
        }
    }

    private func addToLibrary(_ song: SearchSong) {
        playbackError = nil
        let track = Track.searchResultTrack(from: song)
        guard !library.contains(track) else {
            actionMessage = "这首歌已经在资料库里了。"
            return
        }

        library.add(track)
        actionMessage = "已加入资料库：\(song.title)"
    }

    private func addToCustomPlaylist(_ song: SearchSong, playlist: Playlist) {
        let track = Track.searchResultTrack(from: song)
        guard !playlistModel.contains(track, in: playlist) else {
            actionMessage = "“\(song.title)” 已经在歌单 “\(playlist.title)” 里了。"
            return
        }

        playlistModel.addTrack(track, to: playlist)
        actionMessage = "已加入歌单：\(playlist.title)"
    }

    private func openCustomPlaylistEditor(prefilling song: SearchSong) {
        let track = Track.searchResultTrack(from: song)
        playlistDraftSession = SearchPlaylistDraftSession(
            draft: playlistModel.draftForNewCustomPlaylist(
                prefilledTracks: [track],
                libraryTracks: library.savedTracks
            )
        )
    }

    private func openAlbumSongs(_ album: SearchAlbum) {
        playbackError = nil
        actionMessage = nil
        albumDetailSession = SearchAlbumDetailSession(album: album)
    }

    private func addAlbumToLibrary(_ album: SearchAlbum) {
        guard workingAlbumID != album.id else { return }

        let storedAlbum = LibraryAlbum(
            source: album.source,
            sourceAlbumID: album.sourceAlbumID,
            title: album.title,
            artist: album.artist,
            releaseDate: album.releaseDate,
            trackCount: 0,
            artworkURL: album.artworkURL,
            tracks: []
        )
        guard !library.contains(album: storedAlbum) else {
            actionMessage = "这张专辑已经在资料库里了。"
            return
        }

        playbackError = nil
        actionMessage = nil
        workingAlbumID = album.id

        Task {
            defer {
                Task { @MainActor in
                    workingAlbumID = nil
                }
            }

            do {
                let songs = try await AlbumSearchEntry().albumSongs(for: album)
                await MainActor.run {
                    library.add(album: album, songs: songs)
                    actionMessage = "已加入专辑：\(album.title)"
                }
            } catch {
                await MainActor.run {
                    playbackError = error.localizedDescription
                }
            }
        }
    }

    private func playAlbum(_ album: SearchAlbum) {
        guard workingAlbumID != album.id else { return }

        playbackError = nil
        actionMessage = nil
        workingAlbumID = album.id

        Task {
            defer {
                Task { @MainActor in
                    workingAlbumID = nil
                }
            }

            do {
                let songs = try await AlbumSearchEntry().albumSongs(for: album)
                guard let firstSong = songs.first else {
                    await MainActor.run {
                        playbackError = "这张专辑当前没有可播放的曲目。"
                    }
                    return
                }

                await MainActor.run {
                    actionMessage = "正在播放专辑：\(album.title)"
                    play(firstSong)
                }
            } catch {
                await MainActor.run {
                    playbackError = error.localizedDescription
                }
            }
        }
    }
}

struct PlaybackDebugCard: View {
    let info: PlaybackDebugInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("播放调试")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            if let strategy = info.resolutionStrategy {
                debugLine("解析策略", strategy)
            }
            if let requestedSource = info.requestedSource {
                debugLine("请求平台", displaySource(requestedSource))
            }
            if let resolvedSource = info.resolvedSource {
                debugLine("实际解析平台", displaySource(resolvedSource))
            }
            if let requestedQuality = info.requestedQuality {
                debugLine("请求音质", requestedQuality)
            }
            if let resolvedQuality = info.resolvedQuality {
                debugLine("实际音质", resolvedQuality)
            }
            if !info.attemptedSources.isEmpty {
                debugLine("尝试顺序", info.attemptedSources.map(displaySource).joined(separator: " -> "))
            }
            debugLine("命中解析缓存", info.usedResolverCache ? "是" : "否")
            if !info.originalURL.isEmpty {
                debugLine("原始地址", info.originalURL)
            }
            if !info.preparedURL.isEmpty {
                debugLine("准备后地址", info.preparedURL)
            }
            if !info.originalURL.isEmpty || !info.preparedURL.isEmpty {
                debugLine("走本地媒体缓存", info.usedLocalCache ? "是" : "否")
            }
            if let localPath = info.localPath {
                debugLine("本地路径", localPath)
                debugLine("文件存在", info.fileExists ? "是" : "否")
            }
            if let note = info.resolutionNote {
                debugLine("说明", note)
            }
            if !info.requestTrace.isEmpty {
                debugLine("请求轨迹", info.requestTrace.joined(separator: "\n"))
            }
            if !info.fieldChecks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("字段检查")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.5))
                    ForEach(info.fieldChecks) { check in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(check.isPresent ? "OK" : "MISS") · \(check.field): \(check.actualValue)")
                                .font(.footnote.monospaced())
                                .foregroundStyle(check.isPresent ? Color(red: 0.55, green: 0.90, blue: 0.72) : Color(red: 1.00, green: 0.63, blue: 0.45))
                            if let note = check.note {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(Color.white.opacity(0.52))
                            }
                        }
                    }
                }
            }
            if let legacyInfoJSON = info.legacyInfoJSON, !legacyInfoJSON.isEmpty {
                debugLine("实际传出的 legacyInfoJSON", legacyInfoJSON)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func debugLine(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.5))
            Text(value)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.76))
                .textSelection(.enabled)
        }
    }

    private func displaySource(_ sourceName: String) -> String {
        SearchPlatformSource(rawValue: sourceName)?.title ?? sourceName.uppercased()
    }
}

private struct SearchSourcePill: View {
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

private struct SearchStatusCard: View {
    let activeSourceName: String?
    let fallbackEnabled: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("当前音源")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.66))

                Text(activeSourceName ?? "未激活")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)

            Text(fallbackEnabled ? "自动换源已开启" : "自动换源已关闭")
                .font(.caption.weight(.semibold))
                .foregroundStyle(fallbackEnabled ? Color(red: 0.57, green: 0.86, blue: 0.73) : Color(red: 1.00, green: 0.72, blue: 0.47))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08), in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct SearchAlbumResultRow: View {
    let album: SearchAlbum
    let isWorking: Bool
    let isInLibrary: Bool
    let action: () -> Void
    let onPlayAlbum: () -> Void
    let onAddToLibrary: () -> Void

    private var coverTrack: Track {
        Track(
            title: album.title,
            artist: album.artist,
            album: album.title,
            blurb: "专辑搜索结果",
            genre: album.source.title,
            duration: 0,
            artwork: album.source.searchArtworkPalette,
            remoteArtworkURL: album.artworkURL,
            sourceName: album.source.title
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                HStack(spacing: 12) {
                    CoverImgView(track: coverTrack, cornerRadius: 10, iconSize: 16)
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(album.title)
                            .font(.body)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(album.artist)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.58))
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            if !album.releaseDate.isEmpty {
                                Text(album.releaseDate)
                            }
                            if !album.songCountText.isEmpty {
                                Text(album.songCountText)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.4))
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(album.source.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.52))

                        Text("搜歌曲")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(red: 0.58, green: 0.88, blue: 0.75))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isWorking {
                ProgressView()
                    .tint(.white)
                    .frame(width: 36, height: 44)
            } else {
                Menu {
                    Button("查看专辑", systemImage: "rectangle.stack") {
                        action()
                    }

                    Button("播放专辑", systemImage: "play.fill") {
                        onPlayAlbum()
                    }

                    Button(isInLibrary ? "已在资料库" : "加入资料库", systemImage: isInLibrary ? "checkmark" : "square.and.arrow.down") {
                        onAddToLibrary()
                    }
                    .disabled(isInLibrary)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .frame(width: 36, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
    }
}

private struct SearchAlbumDetailSheet: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    @EnvironmentObject private var library: MusicLibraryViewModel
    @EnvironmentObject private var playlistModel: MusicPlaylistViewModel
    @Environment(\.dismiss) private var dismiss

    let album: SearchAlbum
    let onPlay: (SearchSong) -> Void
    let onAddToLibrary: (SearchSong) -> Void
    let onAddToCustomPlaylist: (SearchSong, Playlist) -> Void
    let onCreateCustomPlaylist: (SearchSong) -> Void

    @State private var songs: [SearchSong] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    private let albumSearchEntry = AlbumSearchEntry()

    private var coverTrack: Track {
        Track(
            title: album.title,
            artist: album.artist,
            album: album.title,
            blurb: "专辑详情",
            genre: album.source.title,
            duration: 0,
            artwork: album.source.searchArtworkPalette,
            remoteArtworkURL: album.artworkURL,
            sourceName: album.source.title
        )
    }

    private var isAlbumInLibrary: Bool {
        library.contains(
            album: LibraryAlbum(
                source: album.source,
                sourceAlbumID: album.sourceAlbumID,
                title: album.title,
                artist: album.artist,
                releaseDate: album.releaseDate,
                trackCount: songs.count,
                artworkURL: album.artworkURL,
                tracks: songs.map { Track.searchResultTrack(from: $0) }
            )
        )
    }

    var body: some View {
        AppNavigationContainerView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    albumHeader

                    if isLoading {
                        VStack(spacing: 14) {
                            ProgressView()
                                .tint(.white)
                            Text("正在加载专辑曲目…")
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.68))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Color.white.opacity(0.72))
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                Text("曲目")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                            if !songs.isEmpty {
                                Button(isAlbumInLibrary ? "专辑已在资料库" : "加入整张专辑") {
                                    library.add(album: album, songs: songs)
                                }
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(isAlbumInLibrary ? Color.white.opacity(0.5) : Color(red: 0.57, green: 0.90, blue: 0.72))
                                .disabled(isAlbumInLibrary)
                            }

                            ForEach(songs) { song in
                                let track = Track.searchResultTrack(from: song)
                                OnlineSearchResultRow(
                                    song: song,
                                    isCurrent: player.isCurrentTrack(track),
                                    isResolving: false,
                                    isInLibrary: library.contains(track),
                                    customPlaylists: playlistModel.customPlaylists,
                                    playlistContainsTrack: { playlist in
                                        playlistModel.contains(track, in: playlist)
                                    }
                                ) {
                                    dismiss()
                                    onPlay(song)
                                } onAddToLibrary: {
                                    onAddToLibrary(song)
                                } onAddToCustomPlaylist: { playlist in
                                    onAddToCustomPlaylist(song, playlist)
                                } onCreateCustomPlaylist: {
                                    onCreateCustomPlaylist(song)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)
            }
            .navigationTitle(album.title)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadSongs()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private var albumHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            CoverImgView(track: coverTrack, cornerRadius: 18, iconSize: 22)
                .frame(width: 112, height: 112)

            VStack(alignment: .leading, spacing: 8) {
                Text(album.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(album.artist)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.68))

                HStack(spacing: 8) {
                    if !album.releaseDate.isEmpty {
                        infoPill(album.releaseDate)
                    }
                    if !album.songCountText.isEmpty {
                        infoPill(album.songCountText)
                    }
                    infoPill(album.source.title)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func infoPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.white.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08), in: Capsule())
    }

    @MainActor
    private func loadSongs() async {
        guard songs.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        do {
            songs = try await albumSearchEntry.albumSongs(for: album)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private struct OnlineSearchResultRow: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    let song: SearchSong
    let isCurrent: Bool
    let isResolving: Bool
    let isInLibrary: Bool
    let customPlaylists: [Playlist]
    let playlistContainsTrack: (Playlist) -> Bool
    let action: () -> Void
    let onAddToLibrary: () -> Void
    let onAddToCustomPlaylist: (Playlist) -> Void
    let onCreateCustomPlaylist: () -> Void

    var body: some View {
        let track = Track.searchResultTrack(from: song)
        let exportTrack = exportCandidateTrack(fallback: track)

        HStack(spacing: 12) {
            Button(action: action) {
                HStack(spacing: 12) {
                    CoverImgView(track: track, cornerRadius: 10, iconSize: 16)
                        .frame(width: 50, height: 50)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.title)
                            .font(.body)
                            .foregroundStyle(isCurrent ? Color(red: 0.50, green: 0.52, blue: 1.0) : .white)
                            .lineLimit(1)

                        Text(song.artist)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.5))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(song.source.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.52))
                            .lineLimit(1)

                        Text(sourceLibrary.preferredPlaybackQuality(for: song))
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.36))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isResolving || isCurrent)

            if isResolving {
                ProgressView()
                    .tint(.white)
                    .frame(width: 36, height: 44)
            } else {
                Menu {
                    TrackExportMenuItem(track: exportTrack)

                    Button(isInLibrary ? "已在资料库" : "加入资料库", systemImage: isInLibrary ? "checkmark" : "square.and.arrow.down") {
                        onAddToLibrary()
                    }
                    .disabled(isInLibrary)

                    Divider()

                    if customPlaylists.isEmpty {
                        Button("新建自定义歌单", systemImage: "plus.circle") {
                            onCreateCustomPlaylist()
                        }
                    } else {
                        Section("加入自定义歌单") {
                            ForEach(customPlaylists) { playlist in
                                if playlistContainsTrack(playlist) {
                                    Button("\(playlist.title) 已添加", systemImage: "checkmark") {
                                    }
                                    .disabled(true)
                                } else {
                                    Button(playlist.title, systemImage: "text.badge.plus") {
                                        onAddToCustomPlaylist(playlist)
                                    }
                                }
                            }
                        }

                        Divider()

                        Button("新建歌单", systemImage: "plus.circle") {
                            onCreateCustomPlaylist()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .frame(width: 36, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func exportCandidateTrack(fallback: Track) -> Track {
        if let currentTrack = player.currentTrack,
           currentTrack.searchSong?.id == song.id,
           canExportTrackFile(currentTrack) {
            return currentTrack
        }

        if let cachedTrack = player.cachedTracks.last(where: { cached in
            cached.searchSong?.id == song.id || cached.storageKey == fallback.storageKey
        }), canExportTrackFile(cachedTrack) {
            return cachedTrack
        }

        return fallback
    }
}

private struct SearchDebugPanel: View {
    let entries: [SearchDebugItem]
    @Binding var isExpanded: Bool
    let isSearching: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("搜索调试面板", systemImage: "wrench.and.screwdriver.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    if isSearching {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.52))
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                if entries.isEmpty {
                    Text("当前还没有调试结果。输入关键词后会显示每个平台是成功、无结果，还是直接报错。")
                        .font(.footnote)
                        .foregroundStyle(Color.white.opacity(0.64))
                } else {
                    VStack(spacing: 10) {
                        ForEach(entries) { entry in
                            SearchDebugRow(entry: entry)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct SearchDebugRow: View {
    let entry: SearchDebugItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.source.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(statusText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(statusColor)
                }

                Text("\(entry.message) · 本页 \(entry.resultCount) 首 · 总数 \(entry.total) · 页 \(entry.page)/\(max(entry.maxPage, 1))")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var statusColor: Color {
        switch entry.status {
        case .success:
            return Color(red: 0.48, green: 0.92, blue: 0.72)
        case .empty:
            return Color(red: 0.99, green: 0.78, blue: 0.39)
        case .error:
            return Color(red: 1.00, green: 0.50, blue: 0.42)
        }
    }

    private var statusText: String {
        switch entry.status {
        case .success:
            return "成功"
        case .empty:
            return "无结果"
        case .error:
            return "失败"
        }
    }
}

private struct FlexibleTags: View {
    let items: [String]
    var isEditing: Bool = false
    let action: (String) -> Void
    var onDelete: ((String) -> Void)? = nil
    private let columns = [
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 10, alignment: .top),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 10, alignment: .top),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 10, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                ZStack(alignment: .topTrailing) {
                    Button {
                        if !isEditing { action(item) }
                    } label: {
                        Text(item)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.07))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    if isEditing {
                        Button {
                            onDelete?(item)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .background(Color(white: 0.15), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .offset(x: 6, y: -6)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: isEditing)
            }
        }
    }
}
