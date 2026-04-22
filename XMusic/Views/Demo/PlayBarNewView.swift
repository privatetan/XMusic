import SwiftUI

struct PlayBarNewView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(AppThemePreset.storageKey) private var selectedThemeRawValue = AppThemePreset.midnight.rawValue
    @AppStorage(AppThemeStorage.customAccentDataKey) private var customAccentData = Data()

    var displayMode: PlayBarModel.DisplayMode = .regular

    @Binding var isExpanded: Bool
    var animationNamespace: Namespace.ID

    private var theme: AppThemeConfiguration {
        AppThemeConfiguration(
            selectedThemeRawValue: selectedThemeRawValue,
            customAccentData: customAccentData,
            customBackgroundRevision: 0
        )
    }

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
                            visibleShape.fill(Color.primary).opacity(0.04)
                        }
                } else {
                    visibleShape
                        .fill(.regularMaterial)
                        .overlay(visibleShape.fill(LinearGradient(colors: [Color.white.opacity(0.15), .clear, Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .overlay(visibleShape.stroke(LinearGradient(colors: [Color.white.opacity(0.35), .clear, Color.white.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5))
                        .overlay(visibleShape.fill(Color.primary).opacity(0.02))
                }
            }
        }
        .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 12)
    }

    private var primaryControlColor: Color {
        displayMode == .regular ? theme.accent : .primary
    }
}
