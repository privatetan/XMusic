import SwiftUI

struct ContentView: View {
    @StateObject private var player = MusicPlayerViewModel()
    @StateObject private var sourceLibrary = MusicSourceLibrary()
    @StateObject private var musicSearch = MusicSearchViewModel()

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()

            Group {
                switch player.selectedTab {
                case .listenNow:
                    ListenNowView()
                case .browse:
                    BrowseView()
                case .radio:
                    PlaylistView()
                case .search:
                    SearchView()
                }
            }
            .environmentObject(player)
            .environmentObject(sourceLibrary)
            .environmentObject(musicSearch)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                if player.currentTrack != nil {
                    MiniPlayerView()
                        .environmentObject(player)
                }

                AppTabBar(selectedTab: $player.selectedTab)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .overlay {
            if player.isNowPlayingPresented, player.currentTrack != nil {
                InlineNowPlayingPanel {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                        player.isNowPlayingPresented = false
                    }
                }
                .environmentObject(player)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(20)
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
