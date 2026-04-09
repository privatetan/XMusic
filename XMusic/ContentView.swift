import SwiftUI

struct ContentView: View {
    @StateObject private var player = MusicPlayerViewModel()
    @StateObject private var sourceLibrary = MusicSourceLibrary()
    @StateObject private var musicSearch = MusicSearchViewModel()
    @StateObject private var library = MusicLibraryViewModel()
    @StateObject private var playlistModel = MusicPlaylistViewModel()
    @Namespace private var playerAnimation
    @FocusState private var isSearchFieldFocused: Bool

    @State private var showBrowseSongs = false
    @State private var showBrowsePlaylists = false
    @State private var showBrowseCached = false

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()

            Group {
                switch player.selectedTab {
                case .browse:
                    BrowseView(
                        showingSongs: $showBrowseSongs,
                        showingPlaylists: $showBrowsePlaylists,
                        showingCached: $showBrowseCached
                    )
                case .radio:
                    PlaylistView()
                case .settings:
                    SettingsView()
                case .search:
                    SearchView()
                }
            }
            .environmentObject(player)
            .environmentObject(sourceLibrary)
            .environmentObject(musicSearch)
            .environmentObject(library)
            .environmentObject(playlistModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .overlay(alignment: .top) {
            if showBrowseSongs {
                AllSongsSheet(onDismiss: { withAnimation(.easeInOut(duration: 0.28)) { showBrowseSongs = false } })
                    .environmentObject(library)
                    .environmentObject(player)
                    .environmentObject(playlistModel)
                    .transition(.move(edge: .trailing))
                    .zIndex(10)
            }
            if showBrowsePlaylists {
                AllPlaylistsSheet(onDismiss: { withAnimation(.easeInOut(duration: 0.28)) { showBrowsePlaylists = false } })
                    .environmentObject(playlistModel)
                    .environmentObject(library)
                    .environmentObject(player)
                    .environmentObject(sourceLibrary)
                    .transition(.move(edge: .trailing))
                    .zIndex(10)
            }
            CachedSongsSheet(onDismiss: { withAnimation(.easeInOut(duration: 0.28)) { showBrowseCached = false } })
                .environmentObject(player)
                .environmentObject(sourceLibrary)
                .offset(x: showBrowseCached ? 0 : UIScreen.main.bounds.width)
                .opacity(showBrowseCached ? 1 : 0.001)
                .allowsHitTesting(showBrowseCached)
                .zIndex(10)
        }
        .animation(.easeInOut(duration: 0.28), value: showBrowseSongs)
        .animation(.easeInOut(duration: 0.28), value: showBrowsePlaylists)
        .animation(.easeInOut(duration: 0.28), value: showBrowseCached)
        .onChange(of: player.selectedTab) { _ in
            showBrowseSongs = false
            showBrowsePlaylists = false
            showBrowseCached = false
        }
        .preferredColorScheme(.dark)
        .onAppear {
            installSearchPlaybackResolver()
        }
        .onChange(of: sourceLibrary.activeSourceID) { _ in
            installSearchPlaybackResolver()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if player.currentTrack != nil && !(player.selectedTab == .search && isSearchFieldFocused) {
                    MiniPlayerView(animation: playerAnimation)
                        .environmentObject(player)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                AppTabBar(
                    selectedTab: $player.selectedTab,
                    searchQuery: $musicSearch.query,
                    isSearchFieldFocused: $isSearchFieldFocused,
                    onSearchSubmit: { musicSearch.submitSearch() }
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .overlay {
            GeometryReader { proxy in
                if player.isNowPlayingPresented, player.currentTrack != nil {
                    InlineNowPlayingPanel(animation: playerAnimation, containerSize: proxy.size) {
                        player.dismissNowPlaying(animated: true)
                    }
                    .id(player.nowPlayingPresentationID)
                    .environmentObject(player)
                    .environmentObject(sourceLibrary)
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .scale(scale: 0.95, anchor: .center).combined(with: .opacity)
                    ))
                    .zIndex(20)
                }
            }
        }
    }

    private func installSearchPlaybackResolver() {
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
    }
}

#Preview {
    ContentView()
}
