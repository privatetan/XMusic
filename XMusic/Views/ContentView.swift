import SwiftUI

struct ContentView: View {
    private static let tabSwitchAnimation = Animation.spring(response: 0.34, dampingFraction: 0.86)

    @StateObject private var player = MusicPlayerViewModel()
    @StateObject private var sourceLibrary = MusicSourceLibrary()
    @StateObject private var musicSearch = MusicSearchViewModel()
    @StateObject private var library = MusicLibraryViewModel()
    @StateObject private var playlistModel = MusicPlaylistViewModel()
    @StateObject private var scrollState = AppScrollState()
    @Namespace private var playerAnimation
    @FocusState private var isSearchFieldFocused: Bool

    @State private var showBrowseSongs = false
    @State private var showBrowsePlaylists = false
    @State private var showBrowseCached = false

    var body: some View {
        ZStack(alignment: .top) {
            AppBackgroundView()

            tabContent(for: player.selectedTab)
                .id(player.selectedTab)
                .transition(.opacity)
            .environmentObject(player)
            .environmentObject(sourceLibrary)
            .environmentObject(musicSearch)
            .environmentObject(library)
            .environmentObject(playlistModel)
            .environmentObject(scrollState)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .animation(Self.tabSwitchAnimation, value: player.selectedTab)
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
                .environmentObject(library)
                .environmentObject(player)
                .environmentObject(playlistModel)
                .environmentObject(sourceLibrary)
                .offset(x: showBrowseCached ? 0 : UIScreen.main.bounds.width)
                .opacity(showBrowseCached ? 1 : 0.001)
                .allowsHitTesting(showBrowseCached)
                .zIndex(10)
        }
        .animation(.easeInOut(duration: 0.28), value: showBrowseSongs)
        .animation(.easeInOut(duration: 0.28), value: showBrowsePlaylists)
        .animation(.easeInOut(duration: 0.28), value: showBrowseCached)
        .appOnChange(of: player.selectedTab) {
            showBrowseSongs = false
            showBrowsePlaylists = false
            showBrowseCached = false
            scrollState.reset()
        }
        .preferredColorScheme(.dark)
        .onAppear {
            installSearchPlaybackResolver()
        }
        .appOnChange(of: sourceLibrary.activeSourceID) {
            installSearchPlaybackResolver()
        }
        .safeAreaInset(edge: .bottom) {
            let supportsCompactChrome =
                player.selectedTab == .browse ||
                player.selectedTab == .radio ||
                player.selectedTab == .settings
            let isSearchBlockingMiniPlayer = player.selectedTab == .search && isSearchFieldFocused
            let isCompactScrolledMode =
                supportsCompactChrome &&
                player.currentTrack != nil &&
                scrollState.isScrolled &&
                !isSearchBlockingMiniPlayer

            VStack(spacing: 8) {
                if !isCompactScrolledMode && player.currentTrack != nil && !isSearchBlockingMiniPlayer {
                    PlayBarView(animation: playerAnimation)  //播放栏
                        .environmentObject(player)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                MenuBarView(    //菜单栏
                    selectedTab: $player.selectedTab,
                    searchQuery: $musicSearch.query,
                    isSearchFieldFocused: $isSearchFieldFocused,
                    onSearchSubmit: { musicSearch.submitSearch() },
                    isCompactScrolledMode: isCompactScrolledMode,
                    compactMiddleContent: isCompactScrolledMode ? {
                        AnyView(
                            PlayBarView(
                                animation: playerAnimation,
                                displayMode: .compactEmbedded
                            )
                            .environmentObject(player)
                        )
                    } : nil
                )
            }
            .padding(.horizontal, 24) //控制菜单栏和播放栏的左右间距
            .padding(.top, 8)
            .padding(.bottom, -8)
        }
        .overlay {
            GeometryReader { proxy in
                if player.isNowPlayingPresented, player.currentTrack != nil {
                    PlayPagePanelView(
                        timeline: player.playbackTimeline,
                        animation: playerAnimation,
                        containerSize: proxy.size
                    ) {
                        player.dismissNowPlaying(animated: true)
                    }
                    .id(player.nowPlayingPresentationID)
                    .environmentObject(player)
                    .environmentObject(sourceLibrary)
                    .environmentObject(musicSearch)
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

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .browse:
            BrowseView(
                showingSongs: $showBrowseSongs,
                showingPlaylists: $showBrowsePlaylists,
                showingCached: $showBrowseCached
            )
        case .radio:
            PlaylistView()
        case .settings:
            AppSettingsView()
        case .search:
            SearchView()
        }
    }
}

#Preview {
    ContentView()
}
