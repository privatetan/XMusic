import SwiftUI

#if canImport(UIKit)
import UIKit

/// 通过零尺寸背景探针 UIView 将 UIPanGestureRecognizer 挂载到宿主视图上，
/// 实现「屏幕上半部分下滑关闭播放页」。
struct DismissPanCaptureView: UIViewRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat, CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: DismissPanCaptureView
        private let pan = UIPanGestureRecognizer()
        private weak var attachedHost: UIView?
        private weak var scrollView: UIScrollView?
        private var disabledScrollView: UIScrollView?

        init(parent: DismissPanCaptureView) {
            self.parent = parent
            super.init()
            pan.addTarget(self, action: #selector(handlePan(_:)))
            pan.delegate = self
            pan.cancelsTouchesInView = false
            pan.delaysTouchesBegan = false
            pan.delaysTouchesEnded = false
        }

        func attachIfNeeded(from probe: UIView) {
            var candidate = probe.superview
            while let c = candidate {
                if Self.findScrollView(in: c) != nil { break }
                candidate = c.superview
            }
            guard let host = candidate else { return }
            guard attachedHost !== host else { return }
            detach()

            host.addGestureRecognizer(pan)
            attachedHost = host
            scrollView = Self.findScrollView(in: host)
        }

        private func enableScrollView() {
            disabledScrollView?.isScrollEnabled = true
            disabledScrollView = nil
        }

        func detach() {
            enableScrollView()
            attachedHost?.removeGestureRecognizer(pan)
            attachedHost = nil
            scrollView = nil
        }

        private static func findScrollView(in view: UIView) -> UIScrollView? {
            if let sv = view as? UIScrollView { return sv }
            for child in view.subviews {
                if let found = findScrollView(in: child) { return found }
            }
            return nil
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let ty = max(recognizer.translation(in: view).y, 0)
            let vy = recognizer.velocity(in: view).y

            switch recognizer.state {
            case .began:
                disabledScrollView = scrollView
                disabledScrollView?.isScrollEnabled = false
            case .changed:
                parent.onChanged(ty)
            case .ended:
                enableScrollView()
                parent.onEnded(ty, vy)
            case .cancelled, .failed:
                enableScrollView()
                parent.onEnded(0, 0)
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let host = pan.view else { return false }

            let location = pan.location(in: host)
            guard location.y < host.bounds.height / 2 else { return false }

            let v = pan.velocity(in: host)
            return v.y > 0 && v.y > abs(v.x)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
#endif
