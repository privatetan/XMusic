import SwiftUI

struct ContentView: View {
    private static let tabSwitchAnimation = Animation.spring(response: 0.34, dampingFraction: 0.86)

    @ObservedObject private var player: MusicPlayerViewModel
    @ObservedObject private var sourceLibrary: MusicSourceLibrary
    @ObservedObject private var musicSearch: MusicSearchViewModel
    @ObservedObject private var library: MusicLibraryViewModel
    @ObservedObject private var playlistModel: MusicPlaylistViewModel
    @ObservedObject private var scrollState: AppScrollState
    @Namespace private var playerAnimation
    @FocusState private var isSearchFieldFocused: Bool

    @State private var showBrowseSongs = false
    @State private var showBrowseAlbums = false
    @State private var showBrowsePlaylists = false
    @State private var showBrowseCached = false

    @MainActor
    init(context: XMusicAppContext) {
        _player = ObservedObject(wrappedValue: context.player)
        _sourceLibrary = ObservedObject(wrappedValue: context.sourceLibrary)
        _musicSearch = ObservedObject(wrappedValue: context.musicSearch)
        _library = ObservedObject(wrappedValue: context.library)
        _playlistModel = ObservedObject(wrappedValue: context.playlistModel)
        _scrollState = ObservedObject(wrappedValue: context.scrollState)
    }

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
            if showBrowseAlbums {
                AllAlbumsSheet(onDismiss: { withAnimation(.easeInOut(duration: 0.28)) { showBrowseAlbums = false } })
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
        .animation(.easeInOut(duration: 0.28), value: showBrowseAlbums)
        .animation(.easeInOut(duration: 0.28), value: showBrowsePlaylists)
        .animation(.easeInOut(duration: 0.28), value: showBrowseCached)
        .appOnChange(of: player.selectedTab) {
            showBrowseSongs = false
            showBrowseAlbums = false
            showBrowsePlaylists = false
            showBrowseCached = false
            scrollState.reset()
        }
        .preferredColorScheme(.dark)
        .safeAreaInset(edge: .bottom) {
            let supportsCompactChrome =
                player.selectedTab == .browse ||
                player.selectedTab == .radio ||
                player.selectedTab == .settings
            let isCompactScrolledMode =
                supportsCompactChrome &&
                player.currentTrack != nil &&
                scrollState.isScrolled
            let shouldHidePlayBarForSearchFocus = isSearchFieldFocused && player.selectedTab == .search
            let bottomChromePadding = isSearchFieldFocused ? 12.0 : -8.0

            VStack(spacing: 8) {
                if !isCompactScrolledMode &&
                    !shouldHidePlayBarForSearchFocus &&
                    player.currentTrack != nil {
                    PlayBarView(animation: playerAnimation)  //播放栏
                        .environmentObject(player)
                        .transition(.opacity)
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
            .padding(.bottom, bottomChromePadding)
            .animation(.easeInOut(duration: 0.18), value: isCompactScrolledMode)
            .animation(.easeInOut(duration: 0.18), value: shouldHidePlayBarForSearchFocus)
            .animation(.easeInOut(duration: 0.18), value: isSearchFieldFocused)
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

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .browse:
            BrowseView(
                showingSongs: $showBrowseSongs,
                showingAlbums: $showBrowseAlbums,
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
    ContentView(context: .shared)
}
