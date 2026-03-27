import SwiftUI

struct BrowseView: View {
    @EnvironmentObject private var library: MusicLibraryViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "资料库",
                    subtitle: library.savedTracks.isEmpty
                        ? "先把搜索结果收进来，这里会慢慢长成你的收藏夹"
                        : "你最近收下的歌和推荐内容都放在这里"
                )

                if library.savedTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeading(
                            title: "最近加入",
                            subtitle: "搜索结果点右侧三个点，就能把歌放进资料库"
                        )

                        BrowseLibraryEmptyCard()
                    }
                } else {
                    TrackStack(
                        title: "最近加入",
                        subtitle: "共 \(library.savedTracks.count) 首，按加入时间倒序排列",
                        tracks: library.savedTracks,
                        queueOverride: library.savedTracks
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
    }
}

private struct BrowseLibraryEmptyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("你的资料库还空着")
                .font(.headline)
                .foregroundStyle(.white)

            Text("去搜索页找到想听的歌，点结果行右侧的三个点，可以直接加入资料库，也可以顺手放进自定义歌单。")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.68))
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
