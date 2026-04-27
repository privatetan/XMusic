import Foundation
import SwiftUI

struct MenuBarView: View {
    private static let tabSelectionAnimation = Animation.spring(response: 0.34, dampingFraction: 0.86)

    @Binding var selectedTab: AppTab
    @Binding var searchQuery: String
    var isSearchFieldFocused: FocusState<Bool>.Binding
    var onSearchSubmit: (() -> Void)? = nil
    var isCompactScrolledMode: Bool = false
    var compactMiddleContent: (() -> AnyView)? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Namespace private var navigationAnimation
    @State private var lastNonSearchTab: AppTab = .browse

    private let accentColor = Color.blue

    private var isSearchMode: Bool { selectedTab == .search }

    var body: some View {
        HStack(spacing: isCompactLayout ? 12 : 16) {
            if isCompactScrolledMode {
                tabButton(for: selectedTab, isSearchShortcut: true)
                    .transition(.opacity)

                if let compactMiddleContent {
                    compactMiddleContent()
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                }
            } else {
                if isSearchMode {
                    Button {
                        isSearchFieldFocused.wrappedValue = false
                        selectedTab = lastNonSearchTab
                    } label: {
                        Image(systemName: lastNonSearchTab.symbol)
                            .font(.system(size: isCompactLayout ? 20 : 22, weight: .semibold))
                            .foregroundStyle(AppThemeTextColors.primary)
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
                        .foregroundStyle(AppThemeTextColors.primary.opacity(0.55))

                    TextField("搜索歌名、艺人、专辑", text: $searchQuery)
                        .focused(isSearchFieldFocused)
                        .textFieldStyle(.plain)
                        .foregroundStyle(AppThemeTextColors.primary)
                        .font(.system(size: 16, weight: .medium))
                        .submitLabel(.search)
                        .onSubmit { onSearchSubmit?() }

                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(AppThemeTextColors.primary.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: searchBarHeight)
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
        .animation(Self.tabSelectionAnimation, value: selectedTab)
        .animation(Self.tabSelectionAnimation, value: isSearchMode)
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
            guard selectedTab != tab else { return }
            if tab == .search {
                isSearchFieldFocused.wrappedValue = false
            } else {
                isSearchFieldFocused.wrappedValue = false
            }
            selectedTab = tab
        } label: {
            if isSearchShortcut {
                Image(systemName: tab.symbol)
                    .font(.system(size: isCompactLayout ? 22 : 24, weight: .semibold))
                    .foregroundStyle(isSelected ? accentColor : AppThemeTextColors.primary)
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
                .foregroundStyle(isSelected ? accentColor : AppThemeTextColors.primary)
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
        isCompactScrolledMode ? compactChromeHeight : menuBarHeight
    }

    private var searchBarHeight: CGFloat {
        isCompactScrolledMode ? compactChromeHeight : menuBarHeight
    }

    @ViewBuilder
    private func searchButtonBackground(isSelected: Bool) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                Color.clear
                    .glassEffect(.regular, in: Circle())
                    .overlay {
                        if isSelected {
                            Circle().fill(accentColor).opacity(0.15)
                        } else {
                            Circle().fill(Color.primary).opacity(0.04)
                        }
                    }
            } else {
                if isSelected {
                    Circle()
                        .fill(accentColor).opacity(0.15)
                        .overlay(Circle().fill(LinearGradient(colors: [Color.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
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
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
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
                    .overlay(Capsule().fill(accentColor).opacity(0.15))
            } else {
                Capsule()
                    .fill(accentColor).opacity(0.15)
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
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
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
