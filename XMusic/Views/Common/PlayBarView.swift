import SwiftUI

struct PlayBarView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var displayMode: PlayBarModel.DisplayMode = .regular

    private var model: PlayBarModel {
        PlayBarModel(
            horizontalSizeClass: horizontalSizeClass,
            displayMode: displayMode
        )
    }

    var body: some View {
        HStack(spacing: model.contentSpacing) {
            PlayingSongInfoView(
                model: model
            )
            PlayBarControlBottonView(
                model: model,
                primaryControlColor: primaryControlColor
            )
        }
        .padding(.leading, model.horizontalPadding)
        .padding(.trailing, model.horizontalPadding)
        .frame(height: model.barHeight)
        .contentShape(Capsule())
        .background(miniPlayerBackground())
        .onTapGesture {
            player.presentNowPlaying()
        }
    }

    @ViewBuilder
    private func miniPlayerBackground() -> some View {
        let visibleShape = Capsule()

        ZStack {
            Group {
                if #available(iOS 26.0, *) {
                    Color.clear
                        .glassEffect(.regular, in: visibleShape)
                        .overlay {
                            visibleShape.fill(AppThemeTextColors.primary).opacity(0.04)
                        }
                } else {
                    visibleShape
                        .fill(.ultraThinMaterial)
                        .overlay(visibleShape.stroke(Color.white.opacity(0.18), lineWidth: 1))
                }
            }
        }
        .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 12)
    }

    private var primaryControlColor: Color {
        displayMode == .regular ? AppThemeTextColors.accent : AppThemeTextColors.primary
    }
}
