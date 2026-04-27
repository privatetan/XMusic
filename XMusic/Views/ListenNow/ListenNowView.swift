import SwiftUI

struct ListenNowView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var library: MusicLibraryViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                PageHeaderView(
                    title: "现在听",
                    subtitle: player.currentTrack == nil
                        ? "只显示你正在播放和已经收进来的歌曲"
                        : "围绕当前播放和你的资料库继续听"
                )

                if let currentTrack = player.currentTrack {
                    ListenNowCurrentTrackCard(track: currentTrack)
                }

                if library.savedTracks.isEmpty {
                    ListenNowEmptyCardView()
                } else {
                    TrackStackView(
                        title: "资料库里的歌",
                        subtitle: "共 \(library.savedTracks.count) 首，按加入时间倒序排列",
                        tracks: library.savedTracks,
                        queueOverride: library.savedTracks
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
    }
}

private struct ListenNowCurrentTrackCard: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("当前播放")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppThemeTextColors.primary.opacity(0.62))
                .textCase(.uppercase)

            HStack(alignment: .center, spacing: 16) {
                CoverImgView(track: track, cornerRadius: 28, iconSize: 30)
                    .frame(width: 118, height: 118)

                VStack(alignment: .leading, spacing: 10) {
                    Text(track.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppThemeTextColors.primary)
                        .lineLimit(2)

                    Text(track.artist)
                        .font(.headline)
                        .foregroundStyle(AppThemeTextColors.primary.opacity(0.74))
                        .lineLimit(1)

                    Text(track.album)
                        .font(.subheadline)
                        .foregroundStyle(AppThemeTextColors.primary.opacity(0.56))
                        .lineLimit(1)

                    Button {
                        player.presentNowPlaying()
                    } label: {
                        Label("打开播放页", systemImage: "play.fill")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white, in: Capsule())
                            .foregroundStyle(AppThemeTextColors.selectedOnLight)
                    }
                    .buttonStyle(.plain)
                }
                .layoutPriority(1)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: track.artwork.colors.map { $0.opacity(0.95) } + [Color.black.opacity(0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
