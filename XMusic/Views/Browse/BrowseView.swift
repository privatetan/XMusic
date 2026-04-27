import SwiftUI

struct BrowseView: View {
    @EnvironmentObject private var scrollState: AppScrollState
    @Binding var showingSongs: Bool
    @Binding var showingAlbums: Bool
    @Binding var showingPlaylists: Bool
    @Binding var showingCached: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("资料库")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppThemeTextColors.primary)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 22)

                BrowseListView(
                    showingSongs: $showingSongs,
                    showingAlbums: $showingAlbums,
                    showingPlaylists: $showingPlaylists,
                    showingCached: $showingCached
                )
                    .padding(.horizontal, 20)

                RowDividerView()
                    .padding(.top, 8)

                RecentlyAddedView()
                    .padding(.top, 28)

                Spacer(minLength: 80)
            }
        }
        .modifier(ChromeScrollTrackingModifier(scrollState: scrollState))
        .onDisappear {
            scrollState.reset()
        }
    }
}
