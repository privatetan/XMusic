import SwiftUI

struct PlayBarModel {
    enum DisplayMode {
        case regular
        case compactEmbedded
    }

    let horizontalSizeClass: UserInterfaceSizeClass?
    let displayMode: DisplayMode

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    var artworkSize: CGFloat {
        switch displayMode {
        case .regular:
            return ChromeBarMetrics.miniPlayerArtworkSize(for: horizontalSizeClass)
        case .compactEmbedded:
            return isCompactLayout ? 34 : 36
        }
    }

    var controlSize: CGFloat {
        switch displayMode {
        case .regular:
            return ChromeBarMetrics.miniPlayerControlSize(for: horizontalSizeClass)
        case .compactEmbedded:
            return isCompactLayout ? 34 : 36
        }
    }

    var barHeight: CGFloat {
        switch displayMode {
        case .regular:
            return ChromeBarMetrics.playBarHeight(for: horizontalSizeClass)
        case .compactEmbedded:
            return ChromeBarMetrics.compactChromeHeight(for: horizontalSizeClass)
        }
    }

    var contentSpacing: CGFloat {
        switch displayMode {
        case .regular:
            return isCompactLayout ? 16 : 20
        case .compactEmbedded:
            return isCompactLayout ? 10 : 12
        }
    }

    var horizontalPadding: CGFloat {
        switch displayMode {
        case .regular:
            return isCompactLayout ? 16 : 20
        case .compactEmbedded:
            return isCompactLayout ? 14 : 16
        }
    }

    var miniPlayerCornerRadius: CGFloat {
        switch displayMode {
        case .regular:
            return isCompactLayout ? 20 : 22
        case .compactEmbedded:
            return isCompactLayout ? 18 : 20
        }
    }

    var metadataSpacing: CGFloat {
        displayMode == .regular ? (isCompactLayout ? 12 : 16) : 12
    }

    var controlSpacing: CGFloat {
        displayMode == .regular ? (isCompactLayout ? 8 : 10) : 4
    }

    var titleFont: Font {
        displayMode == .regular ? .headline : .system(size: 15, weight: .semibold)
    }

    var subtitleFont: Font {
        displayMode == .regular ? .subheadline : .system(size: 13, weight: .medium)
    }

    var playPauseFont: Font {
        displayMode == .regular ? .title2.weight(.bold) : .system(size: 20, weight: .bold)
    }

    var nextFont: Font {
        displayMode == .regular ? .title3.weight(.bold) : .system(size: 18, weight: .bold)
    }

    var artworkCornerRadius: CGFloat {
        displayMode == .regular ? 8 : 10
    }
}
