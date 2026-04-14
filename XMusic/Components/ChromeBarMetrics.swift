import SwiftUI

/// 统一管理底部栏和迷你播放器相关尺寸。
enum ChromeBarMetrics {
    static func height(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 56 : 60
    }

    static func miniPlayerArtworkSize(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 40 : 44
    }

    static func miniPlayerControlSize(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 34 : 36
    }

    static func tabItemHeight(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        height(for: sizeClass) - 6
    }
}
