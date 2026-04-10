import SwiftUI

struct ParsedLyricLine: Identifiable, Equatable {
    let id: String
    let time: Int
    let text: String
    var extendedLyrics: [String]
}

struct HeroLyricsPreview: View {
    let track: Track
    let lines: [ParsedLyricLine]
    let activeLineID: String?
    let compactHeight: Bool

    var body: some View {
        let focusIndex = resolvedFocusIndex
        let window = previewWindow(around: focusIndex)

        VStack(alignment: .leading, spacing: compactHeight ? 18 : 22) {
            HStack(alignment: .center, spacing: compactHeight ? 12 : 14) {
                ArtworkView(track: track, cornerRadius: 18, iconSize: 18)
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
                        size: compactHeight ? (isActive ? 28 : 22) : (isActive ? 34 : 26),
                        weight: isActive ? .bold : .semibold
                    )
                )
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isActive {
                ForEach(line.extendedLyrics, id: \.self) { extendedLine in
                    Text(extendedLine)
                        .font(.system(size: compactHeight ? 17 : 19, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.70))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
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
        case ..<0: return 0.18
        case 0: return 0.96
        case 1: return 0.38
        default: return 0.2
        }
    }

    private func blurRadius(for distance: Int) -> CGFloat {
        switch distance {
        case ..<0: return compactHeight ? 5 : 6
        case 0: return 0
        case 1: return compactHeight ? 2.5 : 3
        default: return compactHeight ? 4.5 : 5
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

struct SyncedLyricsListView: View {
    let lines: [ParsedLyricLine]
    let activeLineID: String?
    let compactHeight: Bool

    @State private var lastScrolledLineID: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: compactHeight ? 14 : 16) {
                    Spacer()
                        .frame(height: compactHeight ? 120 : 150)

                    ForEach(lines) { line in
                        lyricLineView(line)
                            .id(line.id)
                    }

                    Spacer()
                        .frame(height: compactHeight ? 180 : 220)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .onAppear {
                scrollToActiveLine(with: proxy, animated: false)
            }
            .onChange(of: activeLineID) { _ in
                scrollToActiveLine(with: proxy, animated: true)
            }
        }
    }

    @ViewBuilder
    private func lyricLineView(_ line: ParsedLyricLine) -> some View {
        let isActive = line.id == activeLineID

        VStack(spacing: line.extendedLyrics.isEmpty ? 0 : 8) {
            Text(line.text)
                .font(.system(size: compactHeight ? (isActive ? 22 : 18) : (isActive ? 24 : 19), weight: isActive ? .bold : .semibold))
                .foregroundStyle(Color.white.opacity(isActive ? 0.98 : 0.46))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            ForEach(line.extendedLyrics, id: \.self) { extendedLine in
                Text(extendedLine)
                    .font(.system(size: compactHeight ? 14 : 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(isActive ? 0.78 : 0.34))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, compactHeight ? 6 : 8)
        .scaleEffect(isActive ? 1 : 0.96)
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: isActive)
    }

    private func scrollToActiveLine(with proxy: ScrollViewProxy, animated: Bool) {
        guard let activeLineID, activeLineID != lastScrolledLineID else { return }
        lastScrolledLineID = activeLineID

        let action = {
            proxy.scrollTo(activeLineID, anchor: .center)
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.28)) {
                action()
            }
        } else {
            action()
        }
    }
}
