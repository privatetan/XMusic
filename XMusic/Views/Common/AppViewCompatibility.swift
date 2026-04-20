import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

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

    @ViewBuilder
    func appInteractivePopEnabled() -> some View {
        #if canImport(UIKit)
        self.background(AppInteractivePopGestureEnabler())
        #else
        self
        #endif
    }

    @ViewBuilder
    func appEdgeSwipeToDismiss(onDismiss: @escaping () -> Void) -> some View {
        #if os(iOS)
        self.modifier(AppEdgeSwipeDismissModifier(onDismiss: onDismiss))
        #else
        self
        #endif
    }
}

private struct AppEdgeSwipeInProgressKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var appEdgeSwipeInProgress: Bool {
        get { self[AppEdgeSwipeInProgressKey.self] }
        set { self[AppEdgeSwipeInProgressKey.self] = newValue }
    }
}

#if canImport(UIKit)
private struct AppInteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.enableInteractivePopIfNeeded()
    }

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enableInteractivePopIfNeeded()
        }

        func enableInteractivePopIfNeeded() {
            guard let navigationController else { return }
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}
#endif

#if os(iOS)
private struct AppEdgeSwipeDismissModifier: ViewModifier {
    let onDismiss: () -> Void

    // Keep the swipe-to-dismiss gesture on the true screen edge so it doesn't
    // compete with leading back buttons on older iOS releases.
    private let activationWidth: CGFloat = 18
    private let dismissThreshold: CGFloat = 84
    @GestureState private var isTrackingEdgeSwipe = false

    func body(content: Content) -> some View {
        content
            .environment(\.appEdgeSwipeInProgress, isTrackingEdgeSwipe)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .local)
                    .updating($isTrackingEdgeSwipe) { value, state, _ in
                        let isFromLeadingEdge = value.startLocation.x <= activationWidth
                        let isHorizontalSwipe = value.translation.width > 0 &&
                            abs(value.translation.width) > abs(value.translation.height)
                        state = isFromLeadingEdge && isHorizontalSwipe
                    }
                    .onEnded { value in
                        let isFromLeadingEdge = value.startLocation.x <= activationWidth
                        let isHorizontalSwipe = value.translation.width > 0 &&
                            abs(value.translation.width) > abs(value.translation.height)
                        let shouldDismiss = value.translation.width >= dismissThreshold

                        guard isFromLeadingEdge, isHorizontalSwipe, shouldDismiss else { return }
                        onDismiss()
                    }
            )
    }
}
#endif
