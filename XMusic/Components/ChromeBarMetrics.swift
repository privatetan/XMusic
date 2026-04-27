import SwiftUI

/// 统一管理底部栏和迷你播放器相关尺寸。
enum ChromeBarMetrics {
    // 菜单栏的高度
    static func menuBarHeight(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        55
    }

    // 播放栏的高度
    static func playBarHeight(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        // 分离出的播放栏高度控制
        55
    }

    // 收缩态的单行控件统一沿用原播放栏高度
    static func compactChromeHeight(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        playBarHeight(for: sizeClass)
    }

    // 迷你播放器封面的大小
    static func miniPlayerArtworkSize(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        30
    }

    // 迷你播放器控制按钮的大小
    static func miniPlayerControlSize(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        38
    }

    // 菜单栏标签项的高度
    static func tabItemHeight(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        48
    }
}
