import SwiftUI

/// 各模块通用的分区标题组件。
struct SectionHeadingView: View {
    let title: String
    var subtitle: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.62))
            }
        }
    }
}
