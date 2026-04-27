import SwiftUI

enum LyricsVisualStyle {
    case half
    case full
}

struct PlayPageSyncedLyricsListView: View {
    let lines: [ParsedLyricLine]
    let activeLineID: String?
    let compactHeight: Bool
    let visualStyle: LyricsVisualStyle
    var horizontalPadding: CGFloat = 20
    var topPadding: CGFloat? = nil
    var bottomPadding: CGFloat? = nil
    var onTopStateChange: ((Bool) -> Void)? = nil

    @State private var lastScrolledLineID: String?
    @State private var isAtTop = true

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: compactHeight ? 10 : 12) {
                        Spacer()
                            .frame(height: centeredVerticalInset(for: geometry.size.height))

                        topProbe

                        ForEach(lines) { line in
                            lyricLineView(line)
                                .id(line.id)
                        }

                        Spacer()
                            .frame(height: centeredVerticalInset(for: geometry.size.height))
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 14)
                }
                .coordinateSpace(name: "lyrics-scroll")
                .onAppear {
                    scrollToActiveLine(with: proxy, animated: false)
                    onTopStateChange?(true)
                }
                .appOnChange(of: activeLineID) {
                    scrollToActiveLine(with: proxy, animated: true)
                }
                .onPreferenceChange(LyricsTopOffsetPreferenceKey.self) { value in
                    let nextIsAtTop = value >= -6
                    guard nextIsAtTop != isAtTop else { return }
                    isAtTop = nextIsAtTop
                    onTopStateChange?(nextIsAtTop)
                }
            }
        }
    }

    @ViewBuilder
    private func lyricLineView(_ line: ParsedLyricLine) -> some View {
        let isActive = line.id == activeLineID
        let distance = lineDistance(from: line)

        VStack(alignment: .leading, spacing: line.extendedLyrics.isEmpty ? 0 : 6) {
            Text(line.text)
                .font(
                    .system(
                        size: primaryFontSize(isActive: isActive, distance: distance),
                        weight: isActive ? .bold : .semibold
                    )
                )
                .foregroundStyle(primaryOpacity(isActive: isActive, distance: distance))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(line.extendedLyrics, id: \.self) { extendedLine in
                Text(extendedLine)
                    .font(.system(size: secondaryFontSize(isActive: isActive), weight: .medium))
                    .foregroundStyle(AppThemeTextColors.primary.opacity(isActive ? secondaryOpacity : 0.18))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, verticalPadding(for: distance))
        .blur(radius: blurRadius(for: distance))
        .opacity(rowOpacity(isActive: isActive, distance: distance))
        .scaleEffect(scale(for: distance), anchor: .leading)
    }

    private func scrollToActiveLine(with proxy: ScrollViewProxy, animated: Bool) {
        guard let activeLineID, activeLineID != lastScrolledLineID else { return }
        lastScrolledLineID = activeLineID

        let action = {
            proxy.scrollTo(activeLineID, anchor: .center)
        }
        if animated {
            withAnimation(.easeOut(duration: 0.20)) {
                action()
            }
        } else {
            action()
        }
    }

    private var resolvedTopPadding: CGFloat {
        topPadding ?? (compactHeight ? 120 : 150)
    }

    private var resolvedBottomPadding: CGFloat {
        bottomPadding ?? (compactHeight ? 180 : 220)
    }

    private func centeredVerticalInset(for viewportHeight: CGFloat) -> CGFloat {
        let minimumInset = max(resolvedTopPadding, resolvedBottomPadding)
        let estimatedActiveHeight = compactHeight ? 74.0 : 86.0
        let centeredInset = max((viewportHeight - estimatedActiveHeight) / 2, 0)
        return max(minimumInset, centeredInset)
    }

    private var topProbe: some View {
        Color.clear
            .frame(height: 1)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: LyricsTopOffsetPreferenceKey.self,
                        value: geometry.frame(in: .named("lyrics-scroll")).minY
                    )
                }
            )
    }

    private func lineDistance(from line: ParsedLyricLine) -> Int {
        guard let activeLineID,
              let activeIndex = lines.firstIndex(where: { $0.id == activeLineID }),
              let lineIndex = lines.firstIndex(where: { $0.id == line.id }) else {
            return 99
        }
        return abs(lineIndex - activeIndex)
    }

    private func primaryFontSize(isActive: Bool, distance: Int) -> CGFloat {
        switch visualStyle {
        case .half:
            if isActive { return compactHeight ? 24 : 28 }
            if distance == 1 { return compactHeight ? 19 : 22 }
            return compactHeight ? 17 : 19
        case .full:
            if isActive { return compactHeight ? 24 : 28 }
            if distance == 1 { return compactHeight ? 19 : 22 }
            return compactHeight ? 17 : 19
        }
    }

    private func secondaryFontSize(isActive: Bool) -> CGFloat {
        switch visualStyle {
        case .half:
            return isActive ? (compactHeight ? 14 : 16) : (compactHeight ? 12 : 13)
        case .full:
            return isActive ? (compactHeight ? 14 : 16) : (compactHeight ? 12 : 13)
        }
    }

    private func primaryOpacity(isActive: Bool, distance: Int) -> Color {
        Color.white.opacity(textOpacity(isActive: isActive, distance: distance))
    }

    private func textOpacity(isActive: Bool, distance: Int) -> Double {
        switch visualStyle {
        case .half:
            if isActive { return 0.98 }
            switch distance {
            case 1: return 0.54
            case 2: return 0.30
            default: return 0.18
            }
        case .full:
            return isActive ? 0.98 : 0.58
        }
    }

    private var secondaryOpacity: Double {
        visualStyle == .full ? 0.42 : 0.68
    }

    private func blurRadius(for distance: Int) -> CGFloat {
        switch visualStyle {
        case .half:
            switch distance {
            case 0: return 0
            case 1: return compactHeight ? 0.6 : 0.9
            case 2: return compactHeight ? 1.8 : 2.2
            default: return compactHeight ? 3.2 : 3.8
            }
        case .full:
            return 0
        }
    }

    private func rowOpacity(isActive: Bool, distance: Int) -> Double {
        if isActive { return 1 }
        return visualStyle == .full ? 1 : 0.96
    }

    private func scale(for distance: Int) -> CGFloat {
        switch distance {
        case 0: return 1
        case 1: return 0.99
        case 2: return 0.975
        default: return visualStyle == .full ? 0.95 : 0.97
        }
    }

    private func verticalPadding(for distance: Int) -> CGFloat {
        switch visualStyle {
        case .half:
            return distance == 0 ? (compactHeight ? 4 : 6) : (compactHeight ? 2 : 3)
        case .full:
            return distance == 0 ? (compactHeight ? 4 : 6) : (compactHeight ? 2 : 3)
        }
    }
}

private struct LyricsTopOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
