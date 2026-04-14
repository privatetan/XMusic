import SwiftUI

struct PlayPageArtworkSectionView: View {
    let track: Track
    let animation: Namespace.ID
    let layout: PlayPagePanelLayout
    let squeezeProgress: CGFloat
    let lines: [ParsedLyricLine]
    let activeLineID: String?
    let isLoadingLyrics: Bool
    let lyricsErrorMessage: String?
    let isLyricsPresented: Bool
    let showContent: Bool
    let onArtistTap: () -> Void
    let onRetryLyrics: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: layout.topReservedHeight)

            heroContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 22)
                .padding(.horizontal, layout.compactHeight ? 2 : 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .scaleEffect(1.0 - (squeezeProgress * 0.05))

            Spacer(minLength: layout.topSectionBottomPadding)
        }
        .frame(height: layout.topSectionHeight, alignment: .top)
    }

    @ViewBuilder
    private var heroContent: some View {
        if !isLyricsPresented {
            artworkHeroContent
        } else {
            lyricsHeroContent
        }
    }

    @ViewBuilder
    private var artworkHeroContent: some View {
        Spacer()

        VStack(spacing: layout.compactHeight ? 28 : 32) {
            CoverImgView(track: track, cornerRadius: 28, iconSize: layout.compactHeight ? 28 : 32)
                .frame(width: layout.artworkSize, height: layout.artworkSize)
                .clipped()
                .matchedGeometryEffect(id: "Artwork", in: animation)
                .shadow(color: Color.black.opacity(0.14), radius: 24, x: 0, y: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

        Spacer()

        VStack(alignment: .leading, spacing: 1) {
            Text(track.title)
                .font(.system(size: layout.compactHeight ? 28 : 32, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .truncationMode(.tail)

            Button(action: onArtistTap) {
                HStack(spacing: 6) {
                    Text(track.artist)
                        .lineLimit(1)
                }
                .font(.system(size: layout.compactHeight ? 18 : 20, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.88))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("搜索歌手 \(track.artist)")
            .accessibilityHint("跳转到搜索结果页")
        }
        .frame(width: layout.artworkSize, alignment: .leading)
    }

    @ViewBuilder
    private var lyricsHeroContent: some View {
        if isLoadingLyrics {
            VStack(alignment: .leading, spacing: 12) {
                ProgressView()
                    .tint(.white.opacity(0.84))

                Text("正在加载歌词…")
                    .font(.system(size: layout.compactHeight ? 16 : 17, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if let lyricsErrorMessage {
            VStack(alignment: .leading, spacing: 14) {
                Text(lyricsErrorMessage)
                    .font(.system(size: layout.compactHeight ? 16 : 17, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .multilineTextAlignment(.leading)

                Button(action: onRetryLyrics) {
                    Label("重新加载歌词", systemImage: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if !lines.isEmpty {
            PlayPageLyricsPreviewView(
                track: track,
                lines: lines,
                activeLineID: activeLineID,
                compactHeight: layout.compactHeight
            )
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("当前歌曲暂无可显示的歌词")
                    .font(.system(size: layout.compactHeight ? 18 : 20, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.68))

                Text("播放页上半部分会优先展示同步歌词。")
                    .font(.system(size: layout.compactHeight ? 14 : 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.42))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
