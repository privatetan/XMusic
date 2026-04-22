import SwiftUI

enum LyricsPresentationMode {
    case hidden
    case half
    case full

    var isPresented: Bool {
        self != .hidden
    }
}

struct PlayPageArtworkSectionView: View {
    let track: Track
    let layout: PlayPagePanelLayout
    let squeezeProgress: CGFloat
    let lines: [ParsedLyricLine]
    let activeLineID: String?
    let isLoadingLyrics: Bool
    let lyricsErrorMessage: String?
    let lyricsPresentationMode: LyricsPresentationMode
    let showContent: Bool
    let onArtistTap: () -> Void
    let onRetryLyrics: () -> Void
    let onLyricsTopStateChange: (Bool) -> Void
    let onLyricsHeaderTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            heroContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 22)
                .padding(.horizontal, layout.compactHeight ? 2 : 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .scaleEffect(1.0 - (squeezeProgress * 0.05))
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var heroContent: some View {
        if !lyricsPresentationMode.isPresented {
            artworkHeroContent
        } else {
            lyricsHeroContent
        }
    }

    @ViewBuilder
    private var artworkHeroContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: layout.topReservedHeight)

            VStack(spacing: layout.compactHeight ? 28 : 32) {
                CoverImgView(track: track, cornerRadius: 28, iconSize: layout.compactHeight ? 28 : 32)
                    .frame(width: layout.artworkSize, height: layout.artworkSize)
                    .clipped()
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
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: layout.topSectionBottomPadding)
        }
    }

    @ViewBuilder
    private var lyricsHeroContent: some View {
        VStack(alignment: .leading, spacing: lyricsPresentationMode == .full ? 18 : 22) {
            lyricsTopHandle
            lyricsCompactHeader

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
                syncedLyricsContent
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
        .padding(.top, lyricsPresentationMode == .full ? max(layout.safeTop + 40, 44) : max(layout.safeTop + 30, 36))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var syncedLyricsContent: some View {
        PlayPageSyncedLyricsListView(
            lines: lines,
            activeLineID: activeLineID,
            compactHeight: layout.compactHeight,
            visualStyle: lyricsPresentationMode == .full ? .full : .half,
            horizontalPadding: layout.compactHeight ? 2 : 4,
            topPadding: lyricsPresentationMode == .full ? 10 : 22,
            bottomPadding: lyricsPresentationMode == .full ? max(layout.safeBottom + 82, 116) : max(layout.safeBottom + layout.topSectionBottomPadding + 48, 96),
            onTopStateChange: onLyricsTopStateChange
        )
        .modifier(LyricsViewportMaskModifier(mode: lyricsPresentationMode))
    }

    @ViewBuilder
    private var lyricsTopHandle: some View {
        Capsule()
            .fill(Color.white.opacity(lyricsPresentationMode == .full ? 0.20 : 0.18))
            .frame(width: lyricsPresentationMode == .full ? 74 : 54, height: 5)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, lyricsPresentationMode == .full ? 6 : 4)
            .contentShape(Rectangle())
            .onTapGesture(perform: onLyricsHeaderTap)
    }

    @ViewBuilder
    private var lyricsCompactHeader: some View {
        HStack(alignment: .center, spacing: lyricsPresentationMode == .full ? 12 : 14) {
            CoverImgView(
                track: track,
                cornerRadius: lyricsPresentationMode == .full ? 14 : 16,
                iconSize: lyricsPresentationMode == .full ? 15 : 16
            )
            .frame(
                width: lyricsPresentationMode == .full ? (layout.compactHeight ? 48 : 54) : (layout.compactHeight ? 56 : 60),
                height: lyricsPresentationMode == .full ? (layout.compactHeight ? 48 : 54) : (layout.compactHeight ? 56 : 60)
            )
            .clipped()
            .shadow(color: Color.black.opacity(lyricsPresentationMode == .full ? 0.14 : 0.18), radius: 12, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(
                        .system(
                            size: lyricsPresentationMode == .full ? (layout.compactHeight ? 19 : 21) : (layout.compactHeight ? 20 : 22),
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(Color.white.opacity(0.94))
                    .lineLimit(1)

                Button(action: onArtistTap) {
                    Text(track.artist)
                        .font(
                            .system(
                                size: lyricsPresentationMode == .full ? (layout.compactHeight ? 15 : 16) : (layout.compactHeight ? 16 : 17),
                                weight: .medium
                            )
                        )
                        .foregroundStyle(Color.white.opacity(lyricsPresentationMode == .full ? 0.52 : 0.64))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 12)

            Circle()
                .fill(Color.white.opacity(lyricsPresentationMode == .full ? 0.09 : 0.12))
                .frame(width: lyricsPresentationMode == .full ? 38 : 40, height: lyricsPresentationMode == .full ? 38 : 40)
                .overlay {
                    Image(systemName: lyricsPresentationMode == .full ? "chevron.down" : "chevron.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.76))
                }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onLyricsHeaderTap)
    }
}

private struct LyricsViewportMaskModifier: ViewModifier {
    let mode: LyricsPresentationMode

    @ViewBuilder
    func body(content: Content) -> some View {
        if mode == .full {
            content
        } else {
            content.mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white, location: 0.07),
                        .init(color: .white, location: 0.86),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}
