import SwiftUI

struct TrackStack: View {
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
            SectionHeading(title: title, subtitle: subtitle)

            LazyVStack(spacing: 12) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRow(
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

struct ArtworkView: View {
    let track: Track
    let cornerRadius: CGFloat
    let iconSize: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let artworkURL = track.searchSong?.artworkURL {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    artworkFallback
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

struct TrackArtworkFallbackView: View {
    let platformTitle: String
    let trackTitle: String
    let cornerRadius: CGFloat
    let tintColors: [Color]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: tintColors + [Color.black.opacity(0.68)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.clear, Color.black.opacity(0.26)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(platformTitle.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(trackTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date(), format: .dateTime.month(.abbreviated).day())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.45))

            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.7))
        }
    }
}

struct SectionHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.62))
        }
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.07, blue: 0.10),
                    Color(red: 0.04, green: 0.04, blue: 0.06),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.99, green: 0.28, blue: 0.32).opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: -120, y: -260)

            Circle()
                .fill(Color(red: 0.23, green: 0.66, blue: 0.88).opacity(0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 86)
                .offset(x: 140, y: 120)
        }
    }
}

private struct TrackRow: View {
    let track: Track
    let index: Int
    let isCurrent: Bool
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        return Button(action: action) {
            HStack(spacing: 14) {
                Text(index.formatted())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .frame(width: 22)

                ArtworkView(track: track, cornerRadius: 18, iconSize: 18)
                    .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: 6) {
                    Text(track.title)
                        .font(.headline)
                        .foregroundStyle(isCurrent ? Color(red: 1.00, green: 0.43, blue: 0.42) : .white)
                        .lineLimit(1)

                    Text("\(track.artist) • \(track.album)")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.64))
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Image(systemName: isCurrent && isPlaying ? "speaker.wave.2.fill" : "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isCurrent ? Color(red: 1.00, green: 0.43, blue: 0.42) : Color.white.opacity(0.86))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(isCurrent ? 0.11 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(isCurrent ? 0.16 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
