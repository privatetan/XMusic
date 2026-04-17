import SwiftUI
import Combine

final class AppScrollState: ObservableObject {
    @Published var isScrolled = false

    private let threshold: CGFloat = -40

    func update(offset: CGFloat) {
        let nextIsScrolled = offset < threshold
        guard nextIsScrolled != isScrolled else { return }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            isScrolled = nextIsScrolled
        }
    }

    func reset() {
        isScrolled = false
    }
}

struct ChromeScrollTrackingModifier: ViewModifier {
    @ObservedObject var scrollState: AppScrollState

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, newValue in
                scrollState.update(offset: -newValue)
            }
        } else {
            content
        }
    }
}
