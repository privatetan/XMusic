import Foundation
import SwiftUI

struct MenuBarView: View {
    @AppStorage(AppThemePreset.storageKey) private var selectedThemeRawValue = AppThemePreset.midnight.rawValue
    @AppStorage(AppThemeStorage.customAccentDataKey) private var customAccentData = Data()
    @Binding var selectedTab: AppTab
    @Binding var searchQuery: String
    var isSearchFieldFocused: FocusState<Bool>.Binding
    var onSearchSubmit: (() -> Void)? = nil
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
            if isSearchMode {
                Button {
                    isSearchFieldFocused.wrappedValue = false
                    withAnimation(.spring(response: 0.40, dampingFraction: 0.80)) {
                        selectedTab = lastNonSearchTab
                    }
                } label: {
                    Image(systemName: lastNonSearchTab.symbol)
                        .font(.system(size: isCompactLayout ? 20 : 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: barHeight, height: barHeight)
                        .background(searchButtonBackground(isSelected: false))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
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
                .frame(height: barHeight)
                .background(tabClusterBackground())
                .overlay(tabClusterOutline())
                .shadow(color: tabClusterShadowColor, radius: 18, x: 0, y: 8)
                .transition(.scale(scale: 0.8, anchor: .leading).combined(with: .opacity))
            }

            if isSearchMode {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))

                    TextField("搜索歌名、艺人、专辑", text: $searchQuery)
                        .focused(isSearchFieldFocused)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .medium))
                        .submitLabel(.search)
                        .onSubmit { onSearchSubmit?() }

                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: barHeight)
                .background(searchFieldBackground())
                .overlay(searchFieldOutline())
                .shadow(color: tabClusterShadowColor, radius: 18, x: 0, y: 8)
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
                    .foregroundStyle(isSelected ? theme.accent : .white)
                    .frame(width: barHeight, height: barHeight)
                    .background(searchButtonBackground(isSelected: isSelected))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(isSelected ? 0.18 : 0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
            } else {
                VStack(spacing: 3) {
                    Image(systemName: tab.symbol)
                        .font(.system(size: isSelected ? 18 : 16, weight: .semibold))

                    Text(tab.title)
                        .font(.system(size: isCompactLayout ? 10 : 11, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(isSelected ? theme.accent : Color.white.opacity(0.88))
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

    private var barHeight: CGFloat {
        ChromeBarMetrics.height(for: horizontalSizeClass)
    }

    @ViewBuilder
    private func searchButtonBackground(isSelected: Bool) -> some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: Circle())
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isSelected
                                    ? [theme.accent.opacity(0.22), Color.white.opacity(0.10)]
                                    : [Color.white.opacity(0.08), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        } else {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isSelected
                                    ? [Color.white.opacity(0.16), Color.white.opacity(0.06)]
                                    : [Color.white.opacity(0.08), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
        }
    }

    @ViewBuilder
    private func tabClusterBackground() -> some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: Capsule())
                .overlay {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func tabClusterOutline() -> some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
        } else {
            Capsule()
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func selectedTabBackground() -> some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: Capsule())
                .overlay {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [theme.accent.opacity(0.16), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.horizontal, 0.5)
                .padding(.vertical, 1)
                .matchedGeometryEffect(id: "tab-selection", in: navigationAnimation)
        } else {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            theme.accent.opacity(0.18),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .padding(.horizontal, 0.5)
                .padding(.vertical, 1)
                .matchedGeometryEffect(id: "tab-selection", in: navigationAnimation)
        }
    }

    @ViewBuilder
    private func searchFieldBackground() -> some View {
        let shape = Capsule()
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: shape)
                .overlay {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
        } else {
            shape.fill(Color.white.opacity(0.08))
        }
    }

    @ViewBuilder
    private func searchFieldOutline() -> some View {
        Capsule()
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
    }

    private var tabClusterShadowColor: Color {
        if #available(iOS 26.0, *) {
            return Color.black.opacity(0.14)
        }
        return Color.black.opacity(0.22)
    }
}
