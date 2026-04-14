import SwiftUI

struct PlayPageSliderBarView: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let activeColor: Color
    let trackColor: Color
    let height: CGFloat
    let onEditingChanged: ((Bool) -> Void)?

    @State private var isDragging = false

    init(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        activeColor: Color,
        trackColor: Color,
        height: CGFloat,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        _value = value
        self.range = range
        self.activeColor = activeColor
        self.trackColor = trackColor
        self.height = height
        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        GeometryReader { geometry in
            let progress = CGFloat(normalizedProgress)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)

                Capsule()
                    .fill(activeColor)
                    .frame(width: geometry.size.width * progress)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged?(true)
                        }

                        let width = max(geometry.size.width, 1)
                        let ratio = min(max(gesture.location.x / width, 0), 1)
                        value = range.lowerBound + (range.upperBound - range.lowerBound) * ratio
                    }
                    .onEnded { _ in
                        if isDragging {
                            isDragging = false
                            onEditingChanged?(false)
                        }
                    }
            )
        }
        .frame(height: height)
    }

    private var normalizedProgress: Double {
        let span = max(range.upperBound - range.lowerBound, 0.0001)
        return min(max((value - range.lowerBound) / span, 0), 1)
    }
}
