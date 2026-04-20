import AVFoundation
import SwiftUI

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
            AppBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                SheetHeaderBar(title: "歌曲", onBack: onDismiss)

                SheetSearchField(text: $searchText, isFocused: $searchFocused)
                    .padding(.bottom, 16)

                if library.savedTracks.isEmpty {
                    Spacer()
                    SheetCenteredMessage("还没有收藏的歌曲")
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
        .appEdgeSwipeToDismiss(onDismiss: onDismiss)
    }
}

struct AllAlbumsSheet: View {
    @EnvironmentObject private var library: MusicLibraryViewModel
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var playlistModel: MusicPlaylistViewModel
    var onDismiss: () -> Void

    @State private var searchText = ""
    @State private var selectedAlbum: LibraryAlbum?
    @FocusState private var searchFocused: Bool

    private var filteredAlbums: [LibraryAlbum] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return library.savedAlbums }
        return library.savedAlbums.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.artist.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                SheetHeaderBar(title: "专辑", onBack: onDismiss)

                SheetSearchField(text: $searchText, isFocused: $searchFocused)
                    .padding(.bottom, 16)

                if library.savedAlbums.isEmpty {
                    Spacer()
                    SheetCenteredMessage("还没有收藏的专辑")
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredAlbums.enumerated()), id: \.element.id) { index, album in
                                LibraryAlbumRow(album: album) {
                                    selectedAlbum = album
                                } onRemove: {
                                    withAnimation { library.remove(album: album) }
                                }

                                if index < filteredAlbums.count - 1 {
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
        .appEdgeSwipeToDismiss(onDismiss: onDismiss)
        .sheet(item: $selectedAlbum) { album in
            LibraryAlbumDetailSheet(album: album)
                .environmentObject(player)
                .environmentObject(library)
                .environmentObject(playlistModel)
        }
    }
}

struct AllPlaylistsSheet: View {
    @EnvironmentObject private var playlistModel: MusicPlaylistViewModel
    @EnvironmentObject private var library: MusicLibraryViewModel
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    var onDismiss: () -> Void
    @State private var isCreatingPlaylist = false

    var body: some View {
        AppNavigationContainerView {
            ZStack {
                AppBackgroundView()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    SheetHeaderBar(title: "歌单", onBack: onDismiss) {
                        Button {
                            isCreatingPlaylist = true
                        } label: {
                            SheetHeaderIcon(systemName: "plus")
                        }
                        .modifier(SheetHeaderButtonChrome())
                    }

                    if playlistModel.customPlaylists.isEmpty {
                        Spacer()
                        SheetCenteredMessage("还没有自定义歌单")
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
            .appRootNavigationHidden()
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
        .appEdgeSwipeToDismiss(onDismiss: onDismiss)
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

struct CachedSongsSheet: View {
    @EnvironmentObject private var library: MusicLibraryViewModel
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var playlistModel: MusicPlaylistViewModel
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
            AppBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                SheetHeaderBar(title: "已缓存", onBack: onDismiss)

                SheetSearchField(text: $searchText, isFocused: $searchFocused)
                    .padding(.bottom, 16)

                if !hasLoadedContent {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                } else if allTracks.isEmpty {
                    Spacer()
                    SheetCenteredMessage("还没有缓存的歌曲")
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
                                    isInLibrary: library.contains(track),
                                    customPlaylists: playlistModel.customPlaylists,
                                    playlistContainsTrack: { playlist in
                                        playlistModel.contains(track, in: playlist)
                                    },
                                    onAddToLibrary: {
                                        library.add(track)
                                    },
                                    onAddToPlaylist: { playlist in
                                        playlistModel.addTrack(track, to: playlist)
                                    },
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
        .appOnChange(of: player.cachedTracks) {
            guard hasLoadedContent else { return }
            reloadTracks()
        }
        .appOnChange(of: sourceLibrary.mediaCacheSummary) {
            guard hasLoadedContent else { return }
            reloadTracks()
        }
        .appEdgeSwipeToDismiss(onDismiss: onDismiss)
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
        player.pruneMissingCachedTracks()
        allTracks = mergedCachedTracks(
            playerTracks: player.cachedTracks,
            cachedFiles: sourceLibrary.cachedMediaFilesSnapshot
        )
    }
}

private struct LibraryAlbumRow: View {
    let album: LibraryAlbum
    let action: () -> Void
    let onRemove: () -> Void

    private var coverTrack: Track {
        Track(
            title: album.title,
            artist: album.artist,
            album: album.title,
            blurb: "已收藏专辑",
            genre: album.source.title,
            duration: 0,
            artwork: album.source.searchArtworkPalette,
            remoteArtworkURL: album.artworkURL,
            sourceName: album.source.title
        )
    }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: action) {
                HStack(spacing: 14) {
                    CoverImgView(track: coverTrack, cornerRadius: 12, iconSize: 18)
                        .frame(width: 60, height: 60)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(album.artist)
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.56))
                            .lineLimit(1)

                        Text(album.trackCount > 0 ? "\(album.trackCount) 首" : album.releaseDate)
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.4))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("从资料库移除", systemImage: "trash", role: .destructive) {
                    onRemove()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.34))
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }
}

struct LibraryAlbumDetailSheet: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var library: MusicLibraryViewModel
    @EnvironmentObject private var playlistModel: MusicPlaylistViewModel
    @Environment(\.dismiss) private var dismiss

    let album: LibraryAlbum

    private var coverTrack: Track {
        Track(
            title: album.title,
            artist: album.artist,
            album: album.title,
            blurb: "资料库专辑详情",
            genre: album.source.title,
            duration: 0,
            artwork: album.source.searchArtworkPalette,
            remoteArtworkURL: album.artworkURL,
            sourceName: album.source.title
        )
    }

    var body: some View {
        AppNavigationContainerView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
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
                                    detailPill(album.releaseDate)
                                }
                                if album.trackCount > 0 {
                                    detailPill("\(album.trackCount) 首")
                                }
                                detailPill(album.source.title)
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

                    HStack(spacing: 12) {
                        SongsActionButton(symbol: "play.fill", label: "播放专辑") {
                            if let first = album.tracks.first {
                                dismiss()
                                player.play(first, from: album.tracks)
                            }
                        }

                        SongsActionButton(symbol: "trash", label: "移除专辑") {
                            library.remove(album: album)
                            dismiss()
                        }
                    }

                    if album.tracks.isEmpty {
                        Text("这张专辑还没有可展示的曲目。")
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

                            ForEach(album.tracks) { track in
                                LibraryAlbumTrackRow(
                                    track: track,
                                    isCurrent: player.currentTrack?.storageKey == track.storageKey,
                                    isPlaying: player.isPlaying,
                                    playlists: playlistModel.customPlaylists
                                ) {
                                    dismiss()
                                    player.play(track, from: album.tracks)
                                } onAddToPlaylist: { playlist in
                                    playlistModel.addTrack(track, to: playlist)
                                } onRemoveSong: {
                                    library.remove(track)
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

    private func detailPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.white.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08), in: Capsule())
    }
}

private struct LibraryAlbumTrackRow: View {
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool
    let playlists: [Playlist]
    let action: () -> Void
    let onAddToPlaylist: (Playlist) -> Void
    let onRemoveSong: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: action) {
                HStack(spacing: 14) {
                    CoverImgView(track: track, cornerRadius: 12, iconSize: 18)
                        .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isCurrent && isPlaying ? Color(red: 0.50, green: 0.52, blue: 1.0) : .white)
                            .lineLimit(1)

                        Text(track.artist)
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.56))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                if playlists.isEmpty {
                    Button("暂无可加入歌单", systemImage: "text.badge.plus") { }
                        .disabled(true)
                } else {
                    Section("加入自定义歌单") {
                        ForEach(playlists) { playlist in
                            Button(playlist.title, systemImage: "text.badge.plus") {
                                onAddToPlaylist(playlist)
                            }
                        }
                    }
                }

                Divider()

                Button("从歌曲资料库移除", systemImage: "trash", role: .destructive) {
                    onRemoveSong()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.34))
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }
}

private func mergedCachedTracks(
    playerTracks: [Track],
    cachedFiles: [CachedMediaFile]
) -> [Track] {
    var merged = playerTracks.reversed().filter { track in
        guard let audioURL = track.audioURL, audioURL.isFileURL else { return false }
        return FileManager.default.fileExists(atPath: audioURL.path)
    }
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
    Track.cachedMediaPlaceholder(from: file)
}
