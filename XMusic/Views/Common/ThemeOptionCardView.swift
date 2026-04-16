import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct ThemeOptionCardView: View {
    let theme: AppThemeConfiguration
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: theme.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    if let previewImage {
                        previewImage
                            .resizable()
                            .scaledToFill()
                    }

                    Circle()
                        .fill(theme.primaryGlow)
                        .frame(width: 30, height: 30)
                        .blur(radius: 12)
                        .offset(x: -16, y: -5)

                    Circle()
                        .fill(theme.secondaryGlow)
                        .frame(width: 24, height: 24)
                        .blur(radius: 10)
                        .offset(x: 16, y: 7)
                }
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isSelected ? theme.accent : Color.white.opacity(0.34))
                    .padding(5)
            }

            HStack(spacing: 5) {
                Text(theme.preset.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)

                Circle()
                    .fill(theme.accent)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(6)
        .frame(width: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? theme.accent.opacity(0.12) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? theme.accent.opacity(0.36) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    #if canImport(UIKit)
    private var previewImage: Image? {
        guard let data = theme.customBackgroundImageData,
              let uiImage = UIImage(data: data)
        else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
    #else
    private var previewImage: Image? { nil }
    #endif
}
