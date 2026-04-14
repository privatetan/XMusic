import SwiftUI

struct PlayPageSyncedLyricsListView: View {
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
            .appOnChange(of: activeLineID) {
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
