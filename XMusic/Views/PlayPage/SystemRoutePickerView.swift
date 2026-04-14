import SwiftUI

#if os(iOS)
import AVKit
import UIKit

struct SystemRoutePickerView: UIViewRepresentable {
    let trigger: Int

    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView(frame: .zero)
        routePickerView.backgroundColor = .clear
        routePickerView.tintColor = .clear
        routePickerView.activeTintColor = .clear
        routePickerView.prioritizesVideoDevices = false
        routePickerView.isUserInteractionEnabled = false
        context.coordinator.routePickerView = routePickerView
        return routePickerView
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = .clear
        uiView.activeTintColor = .clear
        context.coordinator.routePickerView = uiView

        guard context.coordinator.lastTrigger != trigger else { return }
        context.coordinator.lastTrigger = trigger
        context.coordinator.presentRoutePicker()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var routePickerView: AVRoutePickerView?
        var lastTrigger = 0

        func presentRoutePicker() {
            guard let routePickerView else { return }
            DispatchQueue.main.async {
                guard let button = self.findButton(in: routePickerView) else { return }
                button.sendActions(for: .touchUpInside)
            }
        }

        private func findButton(in view: UIView) -> UIButton? {
            if let button = view as? UIButton {
                return button
            }

            for subview in view.subviews {
                if let button = findButton(in: subview) {
                    return button
                }
            }
            return nil
        }
    }
}
#endif
