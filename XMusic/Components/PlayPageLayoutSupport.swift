import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// GeometryProxy 在转场动画期间可能返回 .zero 或不正确的尺寸。
/// 此包装器在 proxy 的值无效时使用外部传入的稳定 fallback 值。
struct StableGeometry {
    let size: CGSize
    let safeAreaInsets: EdgeInsets

    init(proposed: GeometryProxy, fallbackSize: CGSize) {
        let s = proposed.size
        if s.width > 10 && s.height > 10 {
            size = s
            safeAreaInsets = proposed.safeAreaInsets
        } else {
            size = fallbackSize.width > 10 && fallbackSize.height > 10
                ? fallbackSize
                : UIScreen.main.bounds.size
            safeAreaInsets = proposed.safeAreaInsets
        }
    }
}

struct PlayPagePanelLayout {
    let size: CGSize
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let horizontalPadding: CGFloat
    let availableHeight: CGFloat
    let compactHeight: Bool
    let topButtonPadding: CGFloat
    let topSectionHeight: CGFloat
    let bottomSectionHeight: CGFloat
    let contentWidth: CGFloat
    let topReservedHeight: CGFloat
    let artworkSize: CGFloat
    let topSectionBottomPadding: CGFloat
    let secondaryGap: CGFloat
    let controlsGap: CGFloat
    let volumeGap: CGFloat
    let bottomGap: CGFloat
    let actionIconSize: CGFloat

    init(size: CGSize, safeAreaInsets: EdgeInsets) {
        self.size = size
        safeTop = safeAreaInsets.top
        safeBottom = safeAreaInsets.bottom
        horizontalPadding = min(max(size.width * 0.075, 24.0), 32.0)
        availableHeight = size.height - safeTop - safeBottom
        compactHeight = availableHeight < 780
        topButtonPadding = max(safeTop + 2.0, 10.0)
        topSectionHeight = max(availableHeight * 0.65, 0.0)
        bottomSectionHeight = max(availableHeight - topSectionHeight, 0.0)
        contentWidth = max(size.width - horizontalPadding * 2.0, 0.0)
        topReservedHeight = max(topButtonPadding + 52.0, compactHeight ? 74.0 : 82.0)
        artworkSize = min(
            contentWidth * 0.82,
            compactHeight ? 236.0 : 320.0,
            max(topSectionHeight - topReservedHeight - (compactHeight ? 40.0 : 48.0), 140.0)
        )
        topSectionBottomPadding = compactHeight ? 18.0 : 24.0
        secondaryGap = compactHeight ? 6.0 : 10.0
        controlsGap = compactHeight ? 24.0 : 28.0
        volumeGap = compactHeight ? 28.0 : 34.0
        bottomGap = compactHeight ? 34.0 : 36.0
        actionIconSize = compactHeight ? 20.0 : 24.0
    }
}
