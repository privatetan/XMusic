import SwiftUI

/// 为工程内部常用的导航和状态监听行为提供兼容层封装。
extension View {
    @ViewBuilder
    func appRootNavigationHidden() -> some View {
        if #available(iOS 16.0, *) {
            self.toolbar(.hidden, for: .navigationBar)
        } else {
            self.navigationBarHidden(true)
        }
    }

    @ViewBuilder
    func appOnChange<Value: Equatable>(of value: Value, perform action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) {
                action()
            }
        } else {
            self.onChange(of: value) { _ in
                action()
            }
        }
    }
}
