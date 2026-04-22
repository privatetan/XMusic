import SwiftUI

struct ContentNewView: View {
        @State private var isExpanded = false
        @Namespace private var animationNamespace
        
        var body: some View {
            ZStack {
                // 子视图 1：原始内容视图
                if !isExpanded {
                    OriginalView(
                        isExpanded: $isExpanded,
                        animationNamespace: animationNamespace
                    )
                }
                
                // 子视图 2：展开的内容视图
                if isExpanded {
                    ExpandedView(
                        isExpanded: $isExpanded,
                        animationNamespace: animationNamespace
                    )
                }
            }
        }
    }

    // 子视图 1：原始内容
    struct OriginalView: View {
        @Binding var isExpanded: Bool
        var animationNamespace: Namespace.ID
        
        var body: some View {
            VStack {
                Text("音乐播放器")
                    .font(.title)
                
                Spacer()
                
                // 播放控制
                HStack {
                    Button(action: {}) {
                        Image(systemName: "play.fill")
                    }
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "pause.fill")
                    }
                }
                .padding()
            }
            .preferredColorScheme(.dark)              // ← 深色模式
            .background(Color.black)
            .safeAreaInset(edge: .bottom) {           // ← 在底部安全区域插入
              Button(action: {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isExpanded = true
                }
               }) {
                Text("点击展开")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(8)
                    .matchedGeometryEffect(
                        id: "expandButton",
                        in: animationNamespace
                    )
             }
            
            }
            .padding(.bottom, 1)
        }
    }

    // 子视图 2：展开的内容
struct ExpandedView: View {
    @Binding var isExpanded: Bool
    var animationNamespace: Namespace.ID
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部拖动指示条
            VStack {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.gray)
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
            }
            .frame(height: 20)
            
            // 展开的内容
            ScrollView {
                VStack(spacing: 20) {
                    Text("展开的全屏内容")
                        .font(.title)
                        .padding(.top, 10)
                    
                    ForEach(0..<10, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.3))
                            .frame(height: 100)
                            .overlay(
                                Text("项目 \(index + 1)")
                            )
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .offset(y: dragOffset)
        .matchedGeometryEffect(
            id: "expandButton",
            in: animationNamespace
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 {
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

#Preview {
    ContentNewView()
}
