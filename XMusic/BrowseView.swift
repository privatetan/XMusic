import SwiftUI

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
                count: player.cachedTracks.count
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
                GeometryReader { geo in
                    let cardSize = (geo.size.width - 20 * 2 - 14) / 2
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 14) {
                            ForEach(stride(from: 0, to: min(library.savedTracks.count, 20), by: 2).map { $0 }, id: \.self) { i in
                                VStack(spacing: 14) {
                                    RecentlyAddedCard(track: library.savedTracks[i], size: cardSize) {
                                        player.play(library.savedTracks[i], from: library.savedTracks)
                                    }
                                    if i + 1 < library.savedTracks.count {
                                        RecentlyAddedCard(track: library.savedTracks[i + 1], size: cardSize) {
                                            player.play(library.savedTracks[i + 1], from: library.savedTracks)
                                        }
                                    }
                                }
                                .frame(width: cardSize)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                    }
                }
                .frame(height: recentlyAddedHeight)
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
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ArtworkView(track: track, cornerRadius: 10, iconSize: 18)
                    .frame(width: size, height: size)

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
            .frame(width: size)
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                    Text("歌单")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
    }
}

// MARK: - Cached Songs View

struct CachedSongsSheet: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    var onDismiss: () -> Void

    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private var tracks: [Track] { player.cachedTracks.reversed() }

    private var filteredTracks: [Track] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return tracks }
        return tracks.filter {
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

                if tracks.isEmpty {
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
                                    isPlaying: player.isPlaying
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
    let action: () -> Void

    var body: some View {
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

                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
