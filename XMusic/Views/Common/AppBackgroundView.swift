import SwiftUI

/// 应用全局背景层，提供统一的渐变和光斑氛围。
struct AppBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.07, blue: 0.10),
                    Color(red: 0.04, green: 0.04, blue: 0.06),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.99, green: 0.28, blue: 0.32).opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: -120, y: -260)

            Circle()
                .fill(Color(red: 0.23, green: 0.66, blue: 0.88).opacity(0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 86)
                .offset(x: 140, y: 120)
        }
    }
}
