import SwiftUI

struct MenuBarNewView<TabContent: View>: View {
    private let tabItemView: () -> TabContent

    init(@ViewBuilder tabItemView: @escaping () -> TabContent) {
        self.tabItemView = tabItemView
    }

    var body: some View {
        tabItemView()
    }
}
