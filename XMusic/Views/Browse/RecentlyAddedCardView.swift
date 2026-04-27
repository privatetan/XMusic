import SwiftUI

struct RecentlyAddedCardView: View {
    @Environment(\.appEdgeSwipeInProgress) private var isEdgeSwipeInProgress
    let item: LibraryRecentItem
    let action: () -> Void

    private var coverTrack: Track {
        switch item {
        case let .track(track):
            return track
        case let .album(album):
            return Track(
                title: album.title,
                artist: album.artist,
                album: album.title,
                blurb: "已加入资料库的专辑",
                genre: album.source.title,
                duration: 0,
                artwork: album.source.searchArtworkPalette,
                remoteArtworkURL: album.artworkURL,
                sourceName: album.source.title
            )
        }
    }

    private var titleText: String {
        switch item {
        case let .track(track):
            return track.title
        case let .album(album):
            return album.title
        }
    }

    private var subtitleText: String {
        switch item {
        case let .track(track):
            return track.artist
        case let .album(album):
            return album.artist
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    CoverImgView(track: coverTrack, cornerRadius: 10, iconSize: 18)
                        .frame(width: geo.size.width, height: geo.size.width)
                }
                .aspectRatio(1, contentMode: .fit)

                VStack(alignment: .leading, spacing: 3) {
                    Text(titleText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppThemeTextColors.primary)
                        .lineLimit(1)

                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(AppThemeTextColors.primary.opacity(0.55))
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isEdgeSwipeInProgress)
    }
}
