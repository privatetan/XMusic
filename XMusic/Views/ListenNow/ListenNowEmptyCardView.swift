import SwiftUI

struct ListenNowEmptyCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("还没有可继续播放的歌曲")
                .font(.headline)
                .foregroundStyle(AppThemeTextColors.primary)

            Text("去搜索页找到想听的歌，加入资料库之后，这里和资料库页都会同步显示。")
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
