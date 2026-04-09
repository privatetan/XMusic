import SwiftUI
import AVFoundation

// MARK: - BrowseView

struct BrowseView: View {
    @EnvironmentObject private var library: MusicLibraryViewModel
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var playlistModel: MusicPlaylistViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary

    @Binding var showingSongs: Bool
    @Binding var showingPlaylists: Bool
    @Binding var showingCached: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("资料库")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 22)

                libraryCategories
                    .padding(.horizontal, 20)

                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                recentlyAddedSection
                    .padding(.top, 28)

                Spacer(minLength: 80)
            }
        }
    }

    private var cachedTrackCount: Int {
        sourceLibrary.mediaCacheSummary.fileCount
    }

    private var recentlyAddedHeight: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let cardSize = (screenWidth - 40 - 14) / 2
        return cardSize * 2 + 14 + 44 * 2 + 8
    }

    @ViewBuilder
    private var libraryCategories: some View {
        VStack(spacing: 0) {
            LibraryCategoryRow(
                symbol: "music.note.list",
                symbolColor: Color(red: 1.0, green: 0.45, blue: 0.45),
                title: "歌单",
                count: playlistModel.customPlaylists.count
            ) {
                withAnimation(.easeInOut(duration: 0.28)) { showingPlaylists = true }
            }

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.leading, 52)

            LibraryCategoryRow(
                symbol: "music.note",
                symbolColor: Color(red: 0.50, green: 0.52, blue: 1.0),
                title: "歌曲",
                count: library.savedTracks.count
            ) {
                withAnimation(.easeInOut(duration: 0.28)) { showingSongs = true }
            }

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.leading, 52)

            LibraryCategoryRow(
                symbol: "arrow.down.circle.fill",
                symbolColor: Color(red: 0.20, green: 0.78, blue: 0.55),
                title: "已缓存",
                count: cachedTrackCount
            ) {
                withAnimation(.easeInOut(duration: 0.28)) { showingCached = true }
            }
        }
    }

    @ViewBuilder
    private var recentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最近加入")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)

            if library.savedTracks.isEmpty {
                BrowseLibraryEmptyCard()
                    .padding(.horizontal, 20)
            } else {
                let tracks = Array(library.savedTracks.prefix(20))
                let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(tracks) { track in
                        RecentlyAddedCard(track: track) {
                            player.play(track, from: library.savedTracks)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - LibraryCategoryRow

private struct LibraryCategoryRow: View {
    let symbol: String
    let symbolColor: Color
    let title: String
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(symbolColor)
                        .frame(width: 36, height: 36)
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(title)
                    .font(.body)
                    .foregroundStyle(.white)

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.4))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - RecentlyAddedCard

private struct RecentlyAddedCard: View {
    let track: Track
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    ArtworkView(track: track, cornerRadius: 10, iconSize: 18)
                        .frame(width: geo.size.width, height: geo.size.width)
                }
                .aspectRatio(1, contentMode: .fit)

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - All Songs View

struct AllSongsSheet: View {
    @EnvironmentObject private var library: MusicLibraryViewModel
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var playlistModel: MusicPlaylistViewModel
    var onDismiss: () -> Void

    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private var filteredTracks: [Track] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return library.savedTracks }
        return library.savedTracks.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.artist.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { onDismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.10), in: Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)

                Text("歌曲")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                    TextField("搜索", text: $searchText)
                        .focused($searchFocused)
                        .foregroundStyle(.white)
                        .tint(.white)
                        .submitLabel(.search)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                if library.savedTracks.isEmpty {
                    Spacer()
                    Text("还没有收藏的歌曲")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.45))
                    Spacer()
                } else {
                    HStack(spacing: 12) {
                        SongsActionButton(symbol: "play.fill", label: "播放") {
                            if let first = filteredTracks.first {
                                player.play(first, from: filteredTracks)
                            }
                        }
                        SongsActionButton(symbol: "shuffle", label: "随机播放") {
                            if let random = filteredTracks.randomElement() {
                                player.play(random, from: filteredTracks.shuffled())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredTracks.enumerated()), id: \.element.id) { index, track in
                                LibrarySongRow(
                                    track: track,
                                    isCurrent: player.currentTrack?.id == track.id,
                                    isPlaying: player.isPlaying,
                                    playlists: playlistModel.customPlaylists
                                ) {
                                    player.play(track, from: filteredTracks)
                                } onAddToPlaylist: { playlist in
                                    playlistModel.addTrack(track, to: playlist)
                                } onRemove: {
                                    withAnimation { library.remove(track) }
                                }

                                if index < filteredTracks.count - 1 {
                                    Divider()
                                        .background(Color.white.opacity(0.07))
                                        .padding(.leading, 74)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                    .simultaneousGesture(DragGesture().onChanged { _ in searchFocused = false })
                }
            }
        }
    }
}

// MARK: - All Playlists View

struct AllPlaylistsSheet: View {
    @EnvironmentObject private var playlistModel: MusicPlaylistViewModel
    @EnvironmentObject private var library: MusicLibraryViewModel
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    var onDismiss: () -> Void
    @State private var isCreatingPlaylist = false

    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Button { onDismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.white.opacity(0.72))
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.10), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            isCreatingPlaylist = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.10), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                    HStack(alignment: .center, spacing: 12) {
                        Text("歌单")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    if playlistModel.customPlaylists.isEmpty {
                        Spacer()
                        Text("还没有自定义歌单")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.45))
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(playlistModel.customPlaylists.enumerated()), id: \.element.id) { index, playlist in
                                    NavigationLink {
                                        PlaylistDetailPage(
                                            playlistModel: playlistModel,
                                            playlistKey: playlist.stableKey
                                        )
                                        .environmentObject(player)
                                        .environmentObject(library)
                                    } label: {
                                        PlaylistSheetRow(playlist: playlist)
                                    }
                                    .buttonStyle(.plain)
                                    .simultaneousGesture(
                                        TapGesture().onEnded {
                                            playlistModel.selectPlaylist(with: playlist.stableKey)
                                        }
                                    )

                                    if index < playlistModel.customPlaylists.count - 1 {
                                        Divider()
                                            .background(Color.white.opacity(0.06))
                                            .padding(.leading, 74)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            #if canImport(UIKit)
            .background(
                PlaylistNavigationBarConfigurator(
                    backgroundColor: UIColor(red: 0.07, green: 0.07, blue: 0.12, alpha: 1),
                    foregroundColor: .white,
                    shadowColor: .clear
                )
            )
            #endif
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $isCreatingPlaylist) {
            PlaylistCustomEditorSheet(
                draft: playlistModel.draftForNewCustomPlaylist(libraryTracks: library.savedTracks),
                isEditing: false
            ) { draft in
                playlistModel.saveCustomPlaylist(draft)
            }
        }
    }
}

// MARK: - Cached Songs View

struct CachedSongsSheet: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    var onDismiss: () -> Void

    @State private var searchText = ""
    @State private var trackPendingRemoval: Track?
    @State private var allTracks: [Track] = []
    @State private var hasLoadedContent = false
    @FocusState private var searchFocused: Bool

    private var filteredTracks: [Track] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return allTracks }
        return allTracks.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.artist.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { onDismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.10), in: Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)

                Text("已缓存")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                    TextField("搜索", text: $searchText)
                        .focused($searchFocused)
                        .foregroundStyle(.white)
                        .tint(.white)
                        .submitLabel(.search)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                if !hasLoadedContent {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                } else if allTracks.isEmpty {
                    Spacer()
                    Text("还没有缓存的歌曲")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.45))
                    Spacer()
                } else {
                    HStack(spacing: 12) {
                        SongsActionButton(symbol: "play.fill", label: "播放") {
                            if let first = filteredTracks.first {
                                player.play(first, from: filteredTracks)
                            }
                        }
                        SongsActionButton(symbol: "shuffle", label: "随机播放") {
                            if let random = filteredTracks.randomElement() {
                                player.play(random, from: filteredTracks.shuffled())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredTracks.enumerated()), id: \.element.id) { index, track in
                                SheetSongRow(
                                    track: track,
                                    isCurrent: player.currentTrack?.id == track.id,
                                    isPlaying: player.isPlaying,
                                    onRemove: {
                                        trackPendingRemoval = track
                                    }
                                ) {
                                    player.play(track, from: filteredTracks)
                                }

                                if index < filteredTracks.count - 1 {
                                    Divider()
                                        .background(Color.white.opacity(0.07))
                                        .padding(.leading, 74)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                    .simultaneousGesture(DragGesture().onChanged { _ in searchFocused = false })
                }
            }
        }
        .confirmationDialog(
            "删除这份缓存？",
            isPresented: Binding(
                get: { trackPendingRemoval != nil },
                set: { isPresented in
                    if !isPresented {
                        trackPendingRemoval = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                guard let track = trackPendingRemoval else { return }
                removeCachedTrack(track)
                trackPendingRemoval = nil
            }
            Button("取消", role: .cancel) {
                trackPendingRemoval = nil
            }
        } message: {
            if let trackPendingRemoval {
                Text("“\(trackPendingRemoval.title)” 的本地缓存文件会被移除。")
            }
        }
        .onAppear {
            guard !hasLoadedContent else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                hasLoadedContent = true
                reloadTracks()
            }
        }
        .onChange(of: player.cachedTracks) { _ in
            guard hasLoadedContent else { return }
            reloadTracks()
        }
        .onChange(of: sourceLibrary.mediaCacheSummary) { _ in
            guard hasLoadedContent else { return }
            reloadTracks()
        }
    }

    private func removeCachedTrack(_ track: Track) {
        player.removeCachedTrack(track)

        guard let audioURL = track.audioURL, audioURL.isFileURL else { return }
        do {
            try sourceLibrary.removeCachedMediaFile(at: audioURL)
        } catch {
            #if DEBUG
            print("[cache] Failed to remove cached media file: \(error)")
            #endif
        }
    }

    private func reloadTracks() {
        allTracks = mergedCachedTracks(
            playerTracks: player.cachedTracks,
            cachedFiles: sourceLibrary.cachedMediaFilesSnapshot
        )
    }
}

private func mergedCachedTracks(
    playerTracks: [Track],
    cachedFiles: [CachedMediaFile]
) -> [Track] {
    var merged = Array(playerTracks.reversed())
    let existingLocalPaths: Set<String> = Set(
        merged.compactMap { track in
            guard let audioURL = track.audioURL, audioURL.isFileURL else { return nil }
            return audioURL.standardizedFileURL.path
        }
    )

    let fallbackTracks = cachedFiles.compactMap { file -> Track? in
        let normalizedPath = file.localURL.standardizedFileURL.path
        guard !existingLocalPaths.contains(normalizedPath) else { return nil }
        return cachedMediaPlaceholderTrack(from: file)
    }

    merged.append(contentsOf: fallbackTracks)
    return merged
}

private func cachedMediaPlaceholderTrack(from file: CachedMediaFile) -> Track {
    let baseName = URL(fileURLWithPath: file.fileName).deletingPathExtension().lastPathComponent
    let inferredTitle = file.title?.nilIfBlank
        ?? (baseName.isEmpty ? "缓存音频" : baseName)
    let inferredArtist = file.artist?.nilIfBlank
        ?? file.originalURL?.host?.replacingOccurrences(of: "www.", with: "")
        ?? "媒体缓存"
    let inferredAlbum = file.album?.nilIfBlank
        ?? "本地缓存"

    return Track(
        title: inferredTitle,
        artist: inferredArtist,
        album: inferredAlbum,
        blurb: file.originalURL?.absoluteString ?? "本地媒体缓存文件",
        genre: "Cache",
        duration: 0,
        audioURL: file.localURL,
        artwork: ArtworkPalette(
            colors: [Color(red: 0.23, green: 0.56, blue: 0.42), Color(red: 0.09, green: 0.18, blue: 0.16)],
            glow: Color(red: 0.34, green: 0.86, blue: 0.62),
            symbol: "arrow.down.circle.fill",
            label: "Cache"
        ),
        sourceName: file.sourceName?.nilIfBlank ?? "媒体缓存"
    )
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Shared subviews

private struct SongsActionButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct LibrarySongRow: View {
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool
    let playlists: [Playlist]
    let onPlay: () -> Void
    let onAddToPlaylist: (Playlist) -> Void
    let onRemove: () -> Void

    @State private var showingRemoveConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                HStack(spacing: 12) {
                    ArtworkView(track: track, cornerRadius: 10, iconSize: 16)
                        .frame(width: 50, height: 50)
                        .overlay(alignment: .bottomTrailing) {
                            if isCurrent {
                                Image(systemName: isPlaying ? "waveform" : "pause.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .padding(3)
                            }
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.body)
                            .foregroundStyle(isCurrent ? Color(red: 0.50, green: 0.52, blue: 1.0) : .white)
                            .lineLimit(1)

                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Menu {
                if !playlists.isEmpty {
                    Menu {
                        ForEach(playlists) { playlist in
                            Button {
                                onAddToPlaylist(playlist)
                            } label: {
                                Label(playlist.title, systemImage: "music.note.list")
                            }
                        }
                    } label: {
                        Label("加入歌单", systemImage: "text.badge.plus")
                    }
                }

                Button(role: .destructive) {
                    showingRemoveConfirm = true
                } label: {
                    Label("从资料库移除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(width: 36, height: 44)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .confirmationDialog("从资料库移除《\(track.title)》？", isPresented: $showingRemoveConfirm, titleVisibility: .visible) {
            Button("移除", role: .destructive) { onRemove() }
            Button("取消", role: .cancel) {}
        }
    }
}

private struct SheetSongRow: View {
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool
    let onRemove: () -> Void
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                HStack(spacing: 12) {
                    ArtworkView(track: track, cornerRadius: 10, iconSize: 16)
                        .frame(width: 50, height: 50)
                        .overlay(alignment: .bottomTrailing) {
                            if isCurrent {
                                Image(systemName: isPlaying ? "waveform" : "pause.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .padding(3)
                            }
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.body)
                            .foregroundStyle(isCurrent ? Color(red: 0.50, green: 0.52, blue: 1.0) : .white)
                            .lineLimit(1)

                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.5))
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("删除缓存", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(width: 36, height: 44)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct PlaylistSheetRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.22, green: 0.25, blue: 0.40), Color(red: 0.10, green: 0.11, blue: 0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "music.note.list")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.title)
                    .font(.body)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(playlist.tracks.count) 首歌曲")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.25))
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct BrowseLibraryEmptyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("你的资料库还空着")
                .font(.headline)
                .foregroundStyle(.white)

            Text("去搜索页找到想听的歌，点结果行右侧的三个点，可以直接加入资料库，也可以顺手放进自定义歌单。")
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
}
