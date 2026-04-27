import SwiftUI

/// 在没有真实封面图时显示统一的渐变占位封面。
struct TrackArtworkFallbackView: View {
    let platformTitle: String
    let trackTitle: String
    let cornerRadius: CGFloat
    let tintColors: [Color]

    var body: some View {
        GeometryReader { geo in
            let isCompact = min(geo.size.width, geo.size.height) < 60

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: tintColors + [Color.black.opacity(0.68)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.10), Color.clear, Color.black.opacity(0.26)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                if isCompact {
                    Image(systemName: "music.note")
                        .font(.system(size: min(geo.size.width, geo.size.height) * 0.4, weight: .semibold))
                        .foregroundStyle(AppThemeTextColors.primary.opacity(0.8))
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(platformTitle.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppThemeTextColors.primary.opacity(0.72))
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Text(trackTitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppThemeTextColors.primary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(10)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
