import SwiftUI

/// 以统一样式渲染一组可播放歌曲列表，并负责把点击行为转成播放队列。
struct TrackStackView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    let title: String
    let subtitle: String
    let tracks: [Track]
    var queueOverride: [Track]? = nil

    var body: some View {
        let currentTrackID = player.currentTrack?.id
        let isPlaying = player.isPlaying
        let queue = queueOverride ?? tracks

        VStack(alignment: .leading, spacing: 16) {
            SectionHeadingView(title: title, subtitle: subtitle)

            LazyVStack(spacing: 12) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRowView(
                        track: track,
                        index: index + 1,
                        isCurrent: currentTrackID == track.id,
                        isPlaying: isPlaying
                    ) {
                        player.play(track, from: queue)
                    }
                }
            }
        }
    }
}
