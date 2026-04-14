import SwiftUI

struct CoverImgView: View {
    let track: Track
    let cornerRadius: CGFloat
    let iconSize: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let artworkURL = track.searchSong?.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        artworkFallback
                    case .empty:
                        artworkFallback
                    @unknown default:
                        artworkFallback
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else if shouldUseTextOnlyFallback {
                artworkFallback
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: track.artwork.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(track.artwork.glow.opacity(0.55))
                    .frame(width: iconSize * 4.3, height: iconSize * 4.3)
                    .blur(radius: iconSize * 1.2)
                    .offset(x: iconSize * 0.55, y: -iconSize * 0.7)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.5)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )

                VStack(alignment: .leading, spacing: iconSize * 0.18) {
                    HStack {
                        Spacer()

                        Text(track.artwork.label.uppercased())
                            .font(.system(size: max(9, iconSize * 0.32), weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.62))
                    }

                    Spacer()

                    Image(systemName: track.artwork.symbol)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(track.title)
                        .font(.system(size: max(10, iconSize * 0.38), weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                .padding(iconSize * 0.56)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var shouldUseTextOnlyFallback: Bool {
        track.searchSong != nil || track.sourceName != nil
    }

    @ViewBuilder
    private var artworkFallback: some View {
        TrackArtworkFallbackView(
            platformTitle: track.searchSong?.source.title ?? track.sourceName ?? track.artwork.label,
            trackTitle: track.title,
            cornerRadius: cornerRadius,
            tintColors: track.artwork.colors
        )
    }
}
