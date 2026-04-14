import SwiftUI

struct PlayPageLyricsPreviewView: View {
    let track: Track
    let lines: [ParsedLyricLine]
    let activeLineID: String?
    let compactHeight: Bool

    var body: some View {
        let focusIndex = resolvedFocusIndex
        let window = previewWindow(around: focusIndex)

        VStack(alignment: .leading, spacing: compactHeight ? 18 : 22) {
            HStack(alignment: .center, spacing: compactHeight ? 12 : 14) {
                CoverImgView(track: track, cornerRadius: 18, iconSize: 18)
                    .frame(width: compactHeight ? 52 : 60, height: compactHeight ? 52 : 60)
                    .clipped()
                    .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: compactHeight ? 24 : 26, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.96))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(track.artist)
                        .font(.system(size: compactHeight ? 17 : 18, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.76))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: compactHeight ? 12 : 16) {
                ForEach(window.indices, id: \.self) { index in
                    let line = window[index]
                    let absoluteIndex = absoluteIndex(for: line) ?? focusIndex
                    let distance = absoluteIndex - focusIndex

                    lyricLineView(line, distance: distance)
                }

                Spacer(minLength: 0)
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white, location: 0.12),
                        .init(color: .white, location: 0.78),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var resolvedFocusIndex: Int {
        guard let activeLineID,
              let index = lines.firstIndex(where: { $0.id == activeLineID }) else {
            return 0
        }
        return index
    }

    private func previewWindow(around index: Int) -> [ParsedLyricLine] {
        guard !lines.isEmpty else { return [] }

        let lowerBound = max(index - 1, 0)
        let upperBound = min(index + 3, lines.count - 1)
        return Array(lines[lowerBound...upperBound])
    }

    private func absoluteIndex(for line: ParsedLyricLine) -> Int? {
        lines.firstIndex(where: { $0.id == line.id })
    }

    @ViewBuilder
    private func lyricLineView(_ line: ParsedLyricLine, distance: Int) -> some View {
        let isActive = distance == 0
        let lineOpacity = opacity(for: distance)
        let blurRadius = blurRadius(for: distance)
        let scale = scale(for: distance)

        VStack(alignment: .leading, spacing: line.extendedLyrics.isEmpty ? 0 : 6) {
            Text(line.text)
                .font(
                    .system(
                        size: compactHeight ? (isActive ? 24 : 20) : (isActive ? 29 : 23),
                        weight: isActive ? .bold : .semibold
                    )
                )
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isActive {
                ForEach(line.extendedLyrics, id: \.self) { extendedLine in
                    Text(extendedLine)
                        .font(.system(size: compactHeight ? 15 : 17, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.70))
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .blur(radius: blurRadius)
        .opacity(lineOpacity)
        .scaleEffect(scale, anchor: .leading)
        .animation(.easeInOut(duration: 0.24), value: activeLineID)
    }

    private func opacity(for distance: Int) -> Double {
        switch distance {
        case ..<0: return 0.28
        case 0: return 0.96
        case 1: return 0.48
        default: return 0.3
        }
    }

    private func blurRadius(for distance: Int) -> CGFloat {
        switch distance {
        case ..<0: return compactHeight ? 2.2 : 2.8
        case 0: return 0
        case 1: return compactHeight ? 1.4 : 1.8
        default: return compactHeight ? 2.0 : 2.4
        }
    }

    private func scale(for distance: Int) -> CGFloat {
        switch distance {
        case ..<0: return 0.98
        case 0: return 1
        case 1: return 0.995
        default: return 0.99
        }
    }
}
