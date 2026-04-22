import SwiftUI

struct PlayBarControlBottonView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel

    let model: PlayBarModel
    let primaryControlColor: Color

    var body: some View {
        HStack(spacing: model.controlSpacing) {
            Button {
                player.togglePlayback()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(model.playPauseFont)
                    .foregroundStyle(primaryControlColor)
                    .frame(width: model.controlSize, height: model.controlSize)
            }
            .buttonStyle(.plain)

            Button {
                player.playNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(model.nextFont)
                    .foregroundStyle(primaryControlColor)
                    .frame(width: model.controlSize, height: model.controlSize)
            }
            .buttonStyle(.plain)
        }
    }
}
