import SwiftUI

struct DemoView: View {
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0
    @Namespace private var animationNamespace

    var body: some View {
        ZStack {
            // 桌面视图（图标网格）
            if !isExpanded {
                VStack(spacing: 30) {
                    Text("应用桌面")
                        .font(.title)
                        .padding()

                    HStack(spacing: 30) {
                        ForEach(0..<4, id: \.self) { index in
                            if index == 0 {
                                // 可点击的应用图标
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        isExpanded = true
                                    }
                                }) {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.blue)
                                        .frame(width: 80, height: 80)
                                        .overlay(Text("App"))
                                        .foregroundColor(AppThemeTextColors.primary)
                                        .matchedGeometryEffect(
                                            id: "appIcon",
                                            in: animationNamespace
                                        )
                                }
                            } else {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 80, height: 80)
                            }
                        }
                        Spacer()
                    }
                    .padding()

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemGray6))
            }

            // 应用全屏视图
            if isExpanded {
                ZStack(alignment: .topLeading) {
                    // 应用背景
                    Color.blue
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        HStack {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    isExpanded = false
                                    dragOffset = 0
                                }
                            }) {
                                Image(systemName: "house.fill")
                                    .font(.title)
                                    .foregroundColor(AppThemeTextColors.primary)
                                    .padding()
                            }
                            Spacer()
                        }

                        Text("App 内容")
                            .font(.title)
                            .foregroundColor(AppThemeTextColors.primary)

                        ScrollView {
                            VStack(spacing: 15) {
                                ForEach(0..<8, id: \.self) { index in
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.2))
                                        .frame(height: 80)
                                        .overlay(
                                            Text("内容 \(index + 1)")
                                                .foregroundColor(AppThemeTextColors.primary)
                                        )
                                }
                            }
                            .padding()
                        }

                        Spacer()
                    }
                    .matchedGeometryEffect(
                        id: "appIcon",
                        in: animationNamespace
                    )
                }
                .offset(y: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height > 0 {
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height > 80 {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    isExpanded = false
                                    dragOffset = 0
                                }
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                .transition(.opacity)
            }
        }
    }
}

#Preview {
    DemoView()
}
