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
