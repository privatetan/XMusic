import SwiftUI

struct BrowseListView: View {
    @EnvironmentObject private var library: MusicLibraryViewModel
    @EnvironmentObject private var playlistModel: MusicPlaylistViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary

    @Binding var showingSongs: Bool
    @Binding var showingPlaylists: Bool
    @Binding var showingCached: Bool

    private var cachedTrackCount: Int {
        sourceLibrary.mediaCacheSummary.fileCount
    }

    var body: some View {
        VStack(spacing: 0) {
            BrowseListRowView(
                symbol: "music.note.list",
                title: "歌单",
                count: playlistModel.customPlaylists.count
            ) {
                withAnimation(.easeInOut(duration: 0.28)) {
                    showingPlaylists = true
                }
            }

            RowDividerView()

            BrowseListRowView(
                symbol: "music.note",
                title: "歌曲",
                count: library.savedTracks.count
            ) {
                withAnimation(.easeInOut(duration: 0.28)) {
                    showingSongs = true
                }
            }

            RowDividerView()

            BrowseListRowView(
                symbol: "arrow.down.circle.dotted",
                title: "已缓存",
                count: cachedTrackCount
            ) {
                withAnimation(.easeInOut(duration: 0.28)) {
                    showingCached = true
                }
            }

            RowDividerView()

            BrowseListRowView(
                symbol: "arrow.down.circle",
                title: "下载",
                count: cachedTrackCount
            ) {
                withAnimation(.easeInOut(duration: 0.28)) {
                    showingCached = true
                }
            }
        }
    }

}
