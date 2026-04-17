import SwiftUI

struct PlayBarView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(AppThemePreset.storageKey) private var selectedThemeRawValue = AppThemePreset.midnight.rawValue
    @AppStorage(AppThemeStorage.customAccentDataKey) private var customAccentData = Data()
    
    let animation: Namespace.ID

    private var theme: AppThemeConfiguration {
        AppThemeConfiguration(
            selectedThemeRawValue: selectedThemeRawValue,
            customAccentData: customAccentData,
            customBackgroundRevision: 0
        )
    }

    var body: some View {
        if let track = player.currentTrack {
            HStack(spacing: isCompactLayout ? 16 : 20) { //控制播放栏的左右间距
                Button {
                    player.presentNowPlaying()
                } label: {
                    HStack(spacing: isCompactLayout ? 12 : 16) {
                        CoverImgView(track: track, cornerRadius: 8, iconSize: 18)
                            .frame(width: artworkSize, height: artworkSize)
                            .matchedGeometryEffect(id: "Artwork", in: animation)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.86)

                            Text(track.artist)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.accent)
                        .frame(width: controlSize, height: controlSize)
                }
                .buttonStyle(.plain)

                Button {
                    player.playNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.primary.opacity(0.25))
                        .frame(width: controlSize, height: controlSize)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, isCompactLayout ? 16 : 20)
            .padding(.trailing, isCompactLayout ? 16 : 20)
            .frame(height: barHeight)
            .contentShape(Capsule())
            .background(miniPlayerBackground())
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
        ChromeBarMetrics.playBarHeight(for: horizontalSizeClass)
    }

    @ViewBuilder
    private func miniPlayerBackground() -> some View {
        let shape = Capsule()
        
        Group {
            if #available(iOS 26.0, *) {
                Color.clear
                    .glassEffect(.regular, in: shape)
                    .overlay {
                        shape.fill(Color.primary).opacity(0.04)
                    }
            } else {
                shape
                    .fill(.regularMaterial)
                    .overlay(shape.fill(LinearGradient(colors: [Color.white.opacity(0.15), .clear, Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .overlay(shape.stroke(LinearGradient(colors: [Color.white.opacity(0.35), .clear, Color.white.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5))
                    .overlay(shape.fill(Color.primary).opacity(0.02))
            }
        }
        .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 12)
        .matchedGeometryEffect(id: "PlayerBackground", in: animation)
    }
}
