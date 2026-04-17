import SwiftUI

struct PlayBarView: View {
    enum DisplayMode {
        case regular
        case compactEmbedded
    }

    @EnvironmentObject private var player: MusicPlayerViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(AppThemePreset.storageKey) private var selectedThemeRawValue = AppThemePreset.midnight.rawValue
    @AppStorage(AppThemeStorage.customAccentDataKey) private var customAccentData = Data()
    
    let animation: Namespace.ID
    var displayMode: DisplayMode = .regular

    private var theme: AppThemeConfiguration {
        AppThemeConfiguration(
            selectedThemeRawValue: selectedThemeRawValue,
            customAccentData: customAccentData,
            customBackgroundRevision: 0
        )
    }

    var body: some View {
        if let track = player.currentTrack {
            HStack(spacing: contentSpacing) {
                artworkAndMeta(for: track)
                controls
            }
            .padding(.leading, horizontalPadding)
            .padding(.trailing, horizontalPadding)
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
        switch displayMode {
        case .regular:
            return ChromeBarMetrics.miniPlayerArtworkSize(for: horizontalSizeClass)
        case .compactEmbedded:
            return isCompactLayout ? 34 : 36
        }
    }

    private var controlSize: CGFloat {
        switch displayMode {
        case .regular:
            return ChromeBarMetrics.miniPlayerControlSize(for: horizontalSizeClass)
        case .compactEmbedded:
            return isCompactLayout ? 34 : 36
        }
    }

    private var barHeight: CGFloat {
        switch displayMode {
        case .regular:
            return ChromeBarMetrics.playBarHeight(for: horizontalSizeClass)
        case .compactEmbedded:
            return ChromeBarMetrics.compactChromeHeight(for: horizontalSizeClass)
        }
    }

    private var contentSpacing: CGFloat {
        switch displayMode {
        case .regular:
            return isCompactLayout ? 16 : 20
        case .compactEmbedded:
            return isCompactLayout ? 10 : 12
        }
    }

    private var horizontalPadding: CGFloat {
        switch displayMode {
        case .regular:
            return isCompactLayout ? 16 : 20
        case .compactEmbedded:
            return isCompactLayout ? 14 : 16
        }
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

    private func artworkAndMeta(for track: Track) -> some View {
        Button {
            player.presentNowPlaying()
        } label: {
            HStack(spacing: displayMode == .regular ? (isCompactLayout ? 12 : 16) : 12) {
                CoverImgView(track: track, cornerRadius: displayMode == .regular ? 8 : 10, iconSize: 18)
                    .frame(width: artworkSize, height: artworkSize)
                    .matchedGeometryEffect(id: "Artwork", in: animation)

                VStack(alignment: .leading, spacing: displayMode == .regular ? 3 : 1) {
                    Text(track.title)
                        .font(displayMode == .regular ? .headline : .system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)

                    Text(track.artist)
                        .font(displayMode == .regular ? .subheadline : .system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var controls: some View {
        HStack(spacing: displayMode == .regular ? (isCompactLayout ? 8 : 10) : 4) {
            Button {
                player.togglePlayback()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(displayMode == .regular ? .title2.weight(.bold) : .system(size: 20, weight: .bold))
                    .foregroundStyle(displayMode == .regular ? theme.accent : .primary)
                    .frame(width: controlSize, height: controlSize)
            }
            .buttonStyle(.plain)

            Button {
                player.playNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(displayMode == .regular ? .title3.weight(.bold) : .system(size: 18, weight: .bold))
                    .foregroundStyle(displayMode == .regular ? Color.primary.opacity(0.25) : .primary)
                    .frame(width: controlSize, height: controlSize)
            }
            .buttonStyle(.plain)
        }
    }
}
