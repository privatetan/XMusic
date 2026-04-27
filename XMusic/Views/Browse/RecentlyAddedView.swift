import SwiftUI

struct RecentlyAddedView: View {
    @EnvironmentObject private var library: MusicLibraryViewModel
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var playlistModel: MusicPlaylistViewModel
    @State private var selectedAlbum: LibraryAlbum?

    var body:some View{
        VStack(alignment: .leading, spacing: 16) {
            Text("最近加入")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppThemeTextColors.primary)
                .padding(.horizontal, 20)
            
            if library.recentItems.isEmpty {
                RecentlyAddedCardEmptyView()
                    .padding(.horizontal, 20)
            } else {
                let items = Array(library.recentItems.prefix(20))
                let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(items) { item in
                        RecentlyAddedCardView(item: item) {
                            switch item {
                            case let .track(track):
                                player.play(track, from: library.savedTracks)
                            case let .album(album):
                                selectedAlbum = album
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(item: $selectedAlbum) { album in
            LibraryAlbumDetailSheet(album: album)
                .environmentObject(player)
                .environmentObject(library)
                .environmentObject(playlistModel)
        }
    }
}
