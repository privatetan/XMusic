import SwiftUI

struct PlayingSongInfoView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel

    let model: PlayBarModel

    var body:some View{
        if let track = player.currentTrack{
            Button {
                player.presentNowPlaying()
            } label: {
                HStack(spacing: model.metadataSpacing) {
                    CoverImgView(track: track, cornerRadius: model.artworkCornerRadius, iconSize: 18)
                        .frame(width: model.artworkSize, height: model.artworkSize)

                    VStack(alignment: .leading, spacing: model.displayMode == .regular ? 3 : 1) {
                        Text(track.title)
                            .font(model.titleFont)
                            .foregroundStyle(AppThemeTextColors.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.86)

                        Text(track.artist)
                            .font(model.subtitleFont)
                            .foregroundStyle(AppThemeTextColors.secondary)
                            .lineLimit(1)
                    }
                        .layoutPriority(1)
                }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        .buttonStyle(.plain)
        }
    }

}
