import SwiftUI

/// 各模块通用的分区标题组件。
struct SectionHeadingView: View {
    let title: String
    var subtitle: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppThemeTextColors.primary)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppThemeTextColors.primary.opacity(0.62))
            }
        }
    }
}
