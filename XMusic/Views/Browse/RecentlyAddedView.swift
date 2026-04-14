import SwiftUI

struct RecentlyAddedView: View {
    @EnvironmentObject private var library: MusicLibraryViewModel
    @EnvironmentObject private var player: MusicPlayerViewModel
     
    var body:some View{
        VStack(alignment: .leading, spacing: 16) {
            Text("最近加入")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
            
            if library.savedTracks.isEmpty {
                RecentlyAddedCardEmptyView()
                    .padding(.horizontal, 20)
            } else {
                let tracks = Array(library.savedTracks.prefix(20))
                let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(tracks) { track in
                        RecentlyAddedCardView(track: track) {
                            player.play(track, from: library.savedTracks)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
