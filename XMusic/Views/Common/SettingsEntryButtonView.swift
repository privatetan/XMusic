import SwiftUI

/// 头部设置入口按钮，负责弹出设置页。
struct SettingsEntryButtonView: View {
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "gearshape.fill")
                    .font(.subheadline.weight(.semibold))

                Text("设置")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) {
            AppNavigationContainerView {
                AppSettingsView()
            }
            .preferredColorScheme(.dark)
        }
    }
}
