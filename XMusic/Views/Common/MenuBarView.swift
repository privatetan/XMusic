import Foundation
import SwiftUI

struct MenuBarView: View {
    @AppStorage(AppThemePreset.storageKey) private var selectedThemeRawValue = AppThemePreset.midnight.rawValue
    @AppStorage(AppThemeStorage.customAccentDataKey) private var customAccentData = Data()
    @Binding var selectedTab: AppTab
    @Binding var searchQuery: String
    var isSearchFieldFocused: FocusState<Bool>.Binding
    var onSearchSubmit: (() -> Void)? = nil
    var isCompactScrolledMode: Bool = false
    var compactMiddleContent: (() -> AnyView)? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Namespace private var navigationAnimation
    @State private var lastNonSearchTab: AppTab = .browse

    private var theme: AppThemeConfiguration {
        AppThemeConfiguration(
            selectedThemeRawValue: selectedThemeRawValue,
            customAccentData: customAccentData,
            customBackgroundRevision: 0
        )
    }

    private var isSearchMode: Bool { selectedTab == .search }

    var body: some View {
        HStack(spacing: isCompactLayout ? 12 : 16) {
            if isCompactScrolledMode {
                tabButton(for: selectedTab, isSearchShortcut: true)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))

                if let compactMiddleContent {
                    compactMiddleContent()
                        .frame(maxWidth: .infinity)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            } else {
                if isSearchMode {
                    Button {
                        isSearchFieldFocused.wrappedValue = false
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.80)) {
                            selectedTab = lastNonSearchTab
                        }
                    } label: {
                        Image(systemName: lastNonSearchTab.symbol)
                            .font(.system(size: isCompactLayout ? 20 : 22, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: shortcutControlHeight, height: shortcutControlHeight)
                            .background(searchButtonBackground(isSelected: false))
                    }
                    .buttonStyle(.plain)
                    .shadow(color: tabClusterShadowColor, radius: 18, x: 0, y: 8)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else {
                    HStack(spacing: isCompactLayout ? 4 : 6) {
                        ForEach(AppTab.mainNavigationTabs) { tab in
                            tabButton(for: tab)
                        }
                    }
                    .padding(.horizontal, isCompactLayout ? 3 : 4)
                    .frame(maxWidth: .infinity)
                    .frame(height: menuBarHeight)
                    .background(tabClusterBackground())
                    .contentShape(Capsule())
                    .onTapGesture {}
                    .overlay(tabClusterOutline())
                    .shadow(color: tabClusterShadowColor, radius: 24, x: 0, y: 12)
                    .transition(.scale(scale: 0.8, anchor: .leading).combined(with: .opacity))
                }
            }

            if isSearchMode {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.55))

                    TextField("搜索歌名、艺人、专辑", text: $searchQuery)
                        .focused(isSearchFieldFocused)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.primary)
                        .font(.system(size: 16, weight: .medium))
                        .submitLabel(.search)
                        .onSubmit { onSearchSubmit?() }

                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.primary.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: compactChromeHeight)
                .background(searchFieldBackground())
                .contentShape(Capsule())
                .onTapGesture {}
                .overlay(searchFieldOutline())
                .shadow(color: tabClusterShadowColor, radius: 24, x: 0, y: 12)
                .transition(.scale(scale: 0.5, anchor: .trailing).combined(with: .opacity))
            } else {
                tabButton(for: .search, isSearchShortcut: true)
                    .transition(.scale(scale: 0.5, anchor: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.40, dampingFraction: 0.80), value: isSearchMode)
        .onAppear {
            if selectedTab != .search {
                lastNonSearchTab = selectedTab
            }
        }
        .appOnChange(of: selectedTab) {
            if selectedTab != .search {
                lastNonSearchTab = selectedTab
            }
        }
    }

    private func tabButton(for tab: AppTab, isSearchShortcut: Bool = false) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                selectedTab = tab
            }
        } label: {
            if isSearchShortcut {
                Image(systemName: tab.symbol)
                    .font(.system(size: isCompactLayout ? 22 : 24, weight: .semibold))
                    .foregroundStyle(isSelected ? theme.accent : .primary)
                    .frame(width: shortcutControlHeight, height: shortcutControlHeight)
                    .background(searchButtonBackground(isSelected: isSelected))
                    .shadow(color: tabClusterShadowColor, radius: 24, x: 0, y: 12)
            } else {
                VStack(spacing: 3) {
                    Image(systemName: tab.symbol)
                        .font(.system(size: isSelected ? 20 : 18, weight: .semibold))

                    Text(tab.title)
                        .font(.system(size: isCompactLayout ? 10 : 11, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(isSelected ? theme.accent : Color.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: tabItemHeight)
                .background {
                    if isSelected {
                        selectedTabBackground()
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var tabItemHeight: CGFloat {
        ChromeBarMetrics.tabItemHeight(for: horizontalSizeClass)
    }

    private var menuBarHeight: CGFloat {
        ChromeBarMetrics.menuBarHeight(for: horizontalSizeClass)
    }

    private var compactChromeHeight: CGFloat {
        ChromeBarMetrics.compactChromeHeight(for: horizontalSizeClass)
    }

    private var shortcutControlHeight: CGFloat {
        (isCompactScrolledMode || isSearchMode) ? compactChromeHeight : menuBarHeight
    }

    @ViewBuilder
    private func searchButtonBackground(isSelected: Bool) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                Color.clear
                    .glassEffect(.regular, in: Circle())
                    .overlay {
                        if isSelected {
                            Circle().fill(theme.accent).opacity(0.15)
                        } else {
                            Circle().fill(Color.primary).opacity(0.04)
                        }
                    }
            } else {
                if isSelected {
                    Circle()
                        .fill(theme.accent).opacity(0.15)
                        .overlay(Circle().fill(LinearGradient(colors: [Color.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                } else {
                    Circle()
                        .fill(.regularMaterial)
                        .overlay(Circle().fill(LinearGradient(colors: [Color.white.opacity(0.15), .clear, Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .overlay(Circle().stroke(LinearGradient(colors: [Color.white.opacity(0.35), .clear, Color.white.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5))
                        .overlay(Circle().fill(Color.primary).opacity(0.02))
                }
            }
        }
    }

    @ViewBuilder
    private func tabClusterBackground() -> some View {
        Group {
            if #available(iOS 26.0, *) {
                Color.clear
                    .glassEffect(.regular, in: Capsule())
                    .overlay { Capsule().fill(Color.primary).opacity(0.04) }
            } else {
                Capsule()
                    .fill(.regularMaterial)
                    .overlay(Capsule().fill(LinearGradient(colors: [Color.white.opacity(0.15), .clear, Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), .clear, Color.white.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5))
                    .overlay(Capsule().fill(Color.primary).opacity(0.02))
            }
        }
    }

    @ViewBuilder
    private func tabClusterOutline() -> some View {
        EmptyView()
    }

    @ViewBuilder
    private func selectedTabBackground() -> some View {
        Group {
            if #available(iOS 26.0, *) {
                Color.clear
                    .glassEffect(.regular, in: Capsule())
                    .overlay(Capsule().fill(theme.accent).opacity(0.15))
            } else {
                Capsule()
                    .fill(theme.accent).opacity(0.15)
                    .overlay(Capsule().fill(LinearGradient(colors: [Color.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            }
        }
        .matchedGeometryEffect(id: "tab-selection", in: navigationAnimation)
    }

    @ViewBuilder
    private func searchFieldBackground() -> some View {
        Group {
            if #available(iOS 26.0, *) {
                Color.clear
                    .glassEffect(.regular, in: Capsule())
                    .overlay { Capsule().fill(Color.primary).opacity(0.04) }
            } else {
                Capsule()
                    .fill(.regularMaterial)
                    .overlay(Capsule().fill(LinearGradient(colors: [Color.white.opacity(0.15), .clear, Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), .clear, Color.white.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5))
                    .overlay(Capsule().fill(Color.primary).opacity(0.02))
            }
        }
    }

    @ViewBuilder
    private func searchFieldOutline() -> some View {
        EmptyView()
    }

    private var tabClusterShadowColor: Color {
        Color.black.opacity(0.08)
    }
}
