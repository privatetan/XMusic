import SwiftUI

struct PlayBarView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let animation: Namespace.ID

    var body: some View {
        if let track = player.currentTrack {
            HStack(spacing: isCompactLayout ? 10 : 14) {
                Button {
                    player.presentNowPlaying()
                } label: {
                    HStack(spacing: isCompactLayout ? 10 : 14) {
                        CoverImgView(track: track, cornerRadius: 18, iconSize: 18)
                            .frame(width: artworkSize, height: artworkSize)
                            .matchedGeometryEffect(id: "Artwork", in: animation)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.86)

                            Text(track.artist)
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.65))
                                .lineLimit(1)
                        }
                        .layoutPriority(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Button {
                    player.togglePlayback()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: controlSize, height: controlSize)
                        .background(miniPlayerControlBackground())
                }
                .buttonStyle(.plain)

                Button {
                    player.playNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: controlSize, height: controlSize)
                        .background(miniPlayerControlBackground())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, isCompactLayout ? 10 : 12)
            .frame(height: barHeight)
            .contentShape(Rectangle())
            .background(miniPlayerBackground())
            .overlay(miniPlayerOutline())
            .onTapGesture {
                player.presentNowPlaying()
            }
        }
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var artworkSize: CGFloat {
        ChromeBarMetrics.miniPlayerArtworkSize(for: horizontalSizeClass)
    }

    private var controlSize: CGFloat {
        ChromeBarMetrics.miniPlayerControlSize(for: horizontalSizeClass)
    }

    private var barHeight: CGFloat {
        ChromeBarMetrics.height(for: horizontalSizeClass)
    }

    @ViewBuilder
    private func miniPlayerBackground() -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: shape)
                .overlay {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .matchedGeometryEffect(id: "PlayerBackground", in: animation)
        } else {
            shape.fill(.ultraThinMaterial)
                .matchedGeometryEffect(id: "PlayerBackground", in: animation)
        }
    }

    @ViewBuilder
    private func miniPlayerOutline() -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(Color.white.opacity(0.1), lineWidth: 1)
    }

    @ViewBuilder
    private func miniPlayerControlBackground() -> some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: Circle())
                .overlay {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                }
        } else {
            Circle()
                .fill(Color.white.opacity(0.08))
        }
    }
}
