import SwiftUI

/// 渲染页面顶部标题区，可选展示设置入口按钮。
struct PageHeaderView: View {
    let title: String
    var subtitle: String = ""
    var showsSettingsButton: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Date(), format: .dateTime.month(.abbreviated).day())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.45))

                Text(title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
            }
            .layoutPriority(1)

            if showsSettingsButton {
                SettingsEntryButtonView()
                    .padding(.top, 2)
            }
        }
    }
}
