import SwiftUI

struct BrowseListView: View {
    @EnvironmentObject private var library: MusicLibraryViewModel
    @EnvironmentObject private var playlistModel: MusicPlaylistViewModel
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary

    @Binding var showingSongs: Bool
    @Binding var showingPlaylists: Bool
    @Binding var showingCached: Bool

    private var effectiveMediaCacheSummary: MediaCacheSummary {
        mergedMediaCacheSummary(
            playerTracks: player.cachedTracks,
            cachedFiles: sourceLibrary.cachedMediaFilesSnapshot
        )
    }

    private var cachedTrackCount: Int {
        effectiveMediaCacheSummary.fileCount
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
                symbol: "arrow.down.circle",
                title: "缓存",
                count: cachedTrackCount
            ) {
                withAnimation(.easeInOut(duration: 0.28)) {
                    showingCached = true
                }
            }
        }
    }

}
