import SwiftUI

struct RecentlyAddedCardEmptyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("你的资料库还空着")
                .font(.headline)
                .foregroundStyle(AppThemeTextColors.primary)

            Text("去搜索页找到想听的歌，点结果行右侧的三个点，可以直接加入资料库，也可以顺手放进自定义歌单。")
                .font(.subheadline)
                .foregroundStyle(AppThemeTextColors.primary.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
