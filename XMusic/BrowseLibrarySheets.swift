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
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.10), in: Circle())
                        }
                        .buttonStyle(.plain)
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
            symbol: "arrow.down.circle.dotted",
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
