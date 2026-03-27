import SwiftUI

struct ListenNowView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var library: MusicLibraryViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "现在听",
                    subtitle: player.currentTrack == nil
                        ? "只显示你正在播放和已经收进来的歌曲"
                        : "围绕当前播放和你的资料库继续听"
                )

                if let currentTrack = player.currentTrack {
                    ListenNowCurrentTrackCard(track: currentTrack)
                }

                if library.savedTracks.isEmpty {
                    ListenNowEmptyCard()
                } else {
                    TrackStack(
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
                .foregroundStyle(Color.white.opacity(0.62))
                .textCase(.uppercase)

            HStack(alignment: .center, spacing: 16) {
                ArtworkView(track: track, cornerRadius: 28, iconSize: 30)
                    .frame(width: 118, height: 118)

                VStack(alignment: .leading, spacing: 10) {
                    Text(track.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(track.artist)
                        .font(.headline)
                        .foregroundStyle(Color.white.opacity(0.74))
                        .lineLimit(1)

                    Text(track.album)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.56))
                        .lineLimit(1)

                    Button {
                        player.presentNowPlaying()
                    } label: {
                        Label("打开播放页", systemImage: "play.fill")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white, in: Capsule())
                            .foregroundStyle(.black)
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

private struct ListenNowEmptyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("还没有可继续播放的歌曲")
                .font(.headline)
                .foregroundStyle(.white)

            Text("去搜索页找到想听的歌，加入资料库之后，这里和资料库页都会同步显示。")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
