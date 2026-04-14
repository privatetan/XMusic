import SwiftUI

/// 应用设置页，集中管理播放、音源和缓存相关选项。
struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    @EnvironmentObject private var musicSearch: MusicSearchViewModel

    @State private var isSourceManagerPresented = false
    @State private var alertMessage: String?

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("设置")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    SettingsPanelView(title: "播放偏好") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("默认音质")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    Text(sourceLibrary.defaultPlaybackQuality.title)
                                        .font(.caption)
                                        .foregroundStyle(Color.white.opacity(0.58))
                                }

                                Spacer(minLength: 0)

                                Text(sourceLibrary.defaultPlaybackQuality.shortLabel)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.white.opacity(0.66))
                            }

                            HStack(spacing: 8) {
                                ForEach(PlaybackQualityPreference.allCases) { quality in
                                    Button {
                                        sourceLibrary.defaultPlaybackQuality = quality
                                    } label: {
                                        SettingsQualityOptionView(
                                            quality: quality,
                                            isSelected: sourceLibrary.defaultPlaybackQuality == quality
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    SettingsPanelView(title: "音源与解析") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $sourceLibrary.enableAutomaticSourceFallback) {
                                Text("自动切换可用音源")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                            .tint(Color(red: 0.48, green: 0.92, blue: 0.72))

                            SettingsInlineActionRowView(
                                title: "当前音源",
                                value: sourceLibrary.activeSource?.name ?? "未激活",
                                actionTitle: "管理",
                                symbol: "waveform.and.magnifyingglass"
                            ) {
                                isSourceManagerPresented = true
                            }
                        }
                    }

                    SettingsPanelView(title: "数据与缓存") {
                        VStack(alignment: .leading, spacing: 12) {
                            SettingsInlineActionRowView(
                                title: "搜索历史",
                                value: musicSearch.searchHistory.isEmpty ? "暂无记录" : "\(musicSearch.searchHistory.count) 条",
                                actionTitle: "清空",
                                symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                                isDisabled: musicSearch.searchHistory.isEmpty
                            ) {
                                musicSearch.clearSearchHistory()
                            }

                            SettingsInlineActionRowView(
                                title: "媒体缓存",
                                value: sourceLibrary.mediaCacheSummary.isEmpty
                                    ? "暂无缓存"
                                    : "\(sourceLibrary.mediaCacheSummary.fileCount) 个文件 · \(sourceLibrary.mediaCacheSummary.formattedSize)",
                                actionTitle: "清理",
                                symbol: "externaldrive.badge.minus",
                                isDisabled: sourceLibrary.mediaCacheSummary.isEmpty
                            ) {
                                do {
                                    try sourceLibrary.clearMediaCache()
                                } catch {
                                    alertMessage = error.localizedDescription
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    dismiss()
                }
                .foregroundStyle(.white)
            }
        }
        .sheet(isPresented: $isSourceManagerPresented) {
            MusicSourceManagementView()
                .environmentObject(sourceLibrary)
                .environmentObject(player)
                .environmentObject(musicSearch)
        }
        .alert(
            "设置操作失败",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        alertMessage = nil
                    }
                }
            ),
            actions: {
                Button("知道了", role: .cancel) {}
            },
            message: {
                Text(alertMessage ?? "")
            }
        )
    }
}
