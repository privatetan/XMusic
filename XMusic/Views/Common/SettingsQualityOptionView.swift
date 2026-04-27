import SwiftUI

/// 默认音质的图标化选项按钮。
struct SettingsQualityOptionView: View {
    @AppStorage(AppThemePreset.storageKey) private var selectedThemeRawValue = AppThemePreset.midnight.rawValue
    @AppStorage(AppThemeStorage.customAccentDataKey) private var customAccentData = Data()

    let quality: PlaybackQualityPreference
    let isSelected: Bool

    private var theme: AppThemeConfiguration {
        AppThemeConfiguration(
            selectedThemeRawValue: selectedThemeRawValue,
            customAccentData: customAccentData,
            customBackgroundRevision: 0
        )
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isSelected
                            ? theme.accent.opacity(0.18)
                            : Color.white.opacity(0.06)
                    )

                Image(systemName: quality.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? AppThemeTextColors.selectedOnAccent : AppThemeTextColors.primary.opacity(0.74))
            }
            .frame(width: 42, height: 42)

            Text(quality.shortLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? AppThemeTextColors.selectedOnAccent : AppThemeTextColors.primary.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 68)
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(Color.white.opacity(isSelected ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected ? theme.accent.opacity(0.28) : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
    }
}
