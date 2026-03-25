import SwiftUI

struct ListenNowView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                PageHeader(title: "现在听", subtitle: "为你挑了更顺耳的一组连播")

                HeroFeatureCard(track: DemoLibrary.featuredTrack)

                ForEach(DemoLibrary.listenNowShelves) { shelf in
                    ShelfSection(shelf: shelf)
                }

                TrackStack(
                    title: "快速选择",
                    subtitle: "直接播放，不需要想太多",
                    tracks: DemoLibrary.allTracks
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
    }
}

private struct HeroFeatureCard: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: isCompactLayout ? 14 : 18) {
                ArtworkView(track: track, cornerRadius: 30, iconSize: 34)
                    .frame(width: artworkSize, height: artworkSize)

                VStack(alignment: .leading, spacing: 12) {
                    Text("本周主打")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .textCase(.uppercase)

                    Text(track.title)
                        .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(isCompactLayout ? 3 : 2)
                        .minimumScaleFactor(0.84)

                    Text(track.artist)
                        .font((isCompactLayout ? Font.headline : .title3).weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.74))
                        .lineLimit(1)

                    Text(track.blurb)
                        .font(isCompactLayout ? .subheadline : .body)
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(isCompactLayout ? 3 : nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        player.play(track, from: DemoLibrary.allTracks)
                    } label: {
                        Label("播放专辑", systemImage: "play.fill")
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
        .padding(isCompactLayout ? 18 : 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: track.artwork.colors.map { $0.opacity(0.95) } + [Color.black.opacity(0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: track.artwork.glow.opacity(0.24), radius: 40, x: 0, y: 22)
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var artworkSize: CGFloat {
        isCompactLayout ? 136 : 180
    }

    private var titleFontSize: CGFloat {
        isCompactLayout ? 24 : 30
    }
}

private struct ShelfSection: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let shelf: Shelf

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: shelf.title, subtitle: shelf.subtitle)

            GeometryReader { geometry in
                let cardWidth = min(max(geometry.size.width * 0.44, 144), 176)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(shelf.tracks) { track in
                            AlbumCard(track: track, queue: shelf.tracks, width: cardWidth)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .frame(height: horizontalSizeClass == .compact ? 218 : 242)
        }
    }
}

private struct AlbumCard: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    let track: Track
    let queue: [Track]
    let width: CGFloat

    var body: some View {
        Button {
            player.play(track, from: queue)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                ArtworkView(track: track, cornerRadius: 26, iconSize: 26)
                    .frame(width: width, height: width)

                Text(track.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(width: width, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
