import SwiftUI
import UniformTypeIdentifiers

/// 应用设置页，集中管理播放、音源和缓存相关选项。
struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    @EnvironmentObject private var musicSearch: MusicSearchViewModel
    @AppStorage(AppThemePreset.storageKey) private var selectedThemeRawValue = AppThemePreset.midnight.rawValue
    @AppStorage(AppThemeStorage.customAccentDataKey) private var customAccentData = Data()
    @AppStorage(AppThemeStorage.customBackgroundRevisionKey) private var customBackgroundRevision = 0
    @AppStorage(AppThemeStorage.customBackgroundBlurKey) private var customBackgroundBlur = 0.0

    @State private var isSourceManagerPresented = false
    @State private var isPhotoLibraryPresented = false
    @State private var isBackgroundFileImporterPresented = false
    #if canImport(UIKit)
    @State private var pendingCropImage: UIImage?
    #endif
    @State private var isCustomThemeEditorExpanded = false
    @State private var alertMessage: String?

    private var currentTheme: AppThemeConfiguration {
        AppThemeConfiguration(
            selectedThemeRawValue: selectedThemeRawValue,
            customAccentData: customAccentData,
            customBackgroundRevision: customBackgroundRevision,
            customBackgroundBlur: customBackgroundBlur
        )
    }

    private var customAccentBinding: Binding<Color> {
        Binding(
            get: { currentTheme.customAccent },
            set: { newValue in
                customAccentData = AppThemeStorage.customAccentData(from: newValue)
            }
        )
    }

    private var effectiveMediaCacheSummary: MediaCacheSummary {
        mergedMediaCacheSummary(
            playerTracks: player.cachedTracks,
            cachedFiles: sourceLibrary.cachedMediaFilesSnapshot
        )
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("设置")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    SettingsPanelView(title: "外观与皮肤", subtitle: "切换主题或设置自定义背景。") {
                        VStack(alignment: .leading, spacing: 6) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(AppThemePreset.allCases) { preset in
                                        Button {
                                            selectedThemeRawValue = preset.rawValue
                                            if preset != .custom {
                                                isCustomThemeEditorExpanded = false
                                            }
                                        } label: {
                                            ThemeOptionCardView(
                                                theme: themeConfiguration(for: preset),
                                                isSelected: currentTheme.preset == preset
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 1)
                            }

                            if currentTheme.preset == .custom {
                                customThemeSummary

                                if isCustomThemeEditorExpanded {
                                    customThemeEditor
                                }
                            }
                        }
                    }

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
                            .tint(currentTheme.accent)

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
                                value: effectiveMediaCacheSummary.isEmpty
                                    ? "暂无缓存"
                                    : "\(effectiveMediaCacheSummary.fileCount) 个文件 · \(effectiveMediaCacheSummary.formattedSize)",
                                actionTitle: "清理",
                                symbol: "externaldrive.badge.minus",
                                isDisabled: false
                            ) {
                                do {
                                    try sourceLibrary.clearMediaCache()
                                    player.clearCachedTracks()
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
        #if canImport(UIKit)
        .sheet(isPresented: $isPhotoLibraryPresented) {
            ThemePhotoLibraryImagePicker { image in
                presentCropper(with: image)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { pendingCropImage != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingCropImage = nil
                    }
                }
            )
        ) {
            if let pendingCropImage {
                ThemeBackgroundCropperView(
                    image: pendingCropImage,
                    onCancel: { self.pendingCropImage = nil },
                    onConfirm: { croppedImage in
                        self.pendingCropImage = nil
                        saveCustomBackgroundImage(from: croppedImage)
                    }
                )
            }
        }
        #endif
        .fileImporter(
            isPresented: $isBackgroundFileImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }

                do {
                    let data = try Data(contentsOf: url)
                    try prepareCustomBackgroundImage(from: data)
                } catch {
                    alertMessage = error.localizedDescription
                }
            case let .failure(error):
                alertMessage = error.localizedDescription
            }
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

    @ViewBuilder
    private var customThemeSummary: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isCustomThemeEditorExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                customBackgroundPreview

                VStack(alignment: .leading, spacing: 4) {
                    Text("自定义外观")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(currentTheme.hasCustomBackgroundImage ? "已配置背景图和按钮色" : "未配置背景图")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.62))
                }

                Spacer(minLength: 0)

                Image(systemName: isCustomThemeEditorExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.46))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var customThemeEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    isPhotoLibraryPresented = true
                } label: {
                    Label("图库", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.plain)
                .modifier(ThemeActionButtonStyle(accent: currentTheme.accent))

                Button {
                    isBackgroundFileImporterPresented = true
                } label: {
                    Label("文件", systemImage: "folder")
                }
                .buttonStyle(.plain)
                .modifier(ThemeActionButtonStyle(accent: currentTheme.accent))

                if currentTheme.hasCustomBackgroundImage {
                    Button(role: .destructive) {
                        removeCustomBackgroundImage()
                    } label: {
                        Label("移除", systemImage: "trash")
                    }
                    .buttonStyle(.plain)
                    .modifier(ThemeSecondaryActionButtonStyle())
                }
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("按钮主色")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)

                    Circle()
                        .fill(currentTheme.accent)
                        .frame(width: 12, height: 12)
                }

                ColorPicker("选择按钮配色", selection: customAccentBinding, supportsOpacity: false)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tint(currentTheme.accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("背景模糊")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("\(Int(customBackgroundBlur))")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.58))
                }

                Slider(value: $customBackgroundBlur, in: 0...36, step: 1)
                    .tint(currentTheme.accent)
                    .disabled(!currentTheme.hasCustomBackgroundImage)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .padding(.top, 2)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private var customBackgroundPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: currentTheme.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let backgroundImage = customBackgroundPreviewImage {
                backgroundImage
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo.artframe")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    #if canImport(UIKit)
    private var customBackgroundPreviewImage: Image? {
        guard let data = currentTheme.customBackgroundImageData,
              let uiImage = UIImage(data: data)
        else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
    #else
    private var customBackgroundPreviewImage: Image? { nil }
    #endif

    private func themeConfiguration(for preset: AppThemePreset) -> AppThemeConfiguration {
        AppThemeConfiguration(
            selectedThemeRawValue: preset.rawValue,
            customAccentData: customAccentData,
            customBackgroundRevision: customBackgroundRevision,
            customBackgroundBlur: customBackgroundBlur
        )
    }

    #if canImport(UIKit)
    private func saveCustomBackgroundImage(from image: UIImage) {
        guard let data = ThemeBackgroundImageProcessor.makeBackgroundImageData(from: image) else {
            alertMessage = "所选图片无法处理，请换一张图片试试。"
            return
        }

        do {
            try AppThemeStorage.saveBackgroundImageData(data)
            selectedThemeRawValue = AppThemePreset.custom.rawValue
            customBackgroundRevision += 1
        } catch {
            alertMessage = error.localizedDescription
        }
    }
    #endif

    #if canImport(UIKit)
    private func presentCropper(with image: UIImage) {
        guard let editableImage = ThemeBackgroundImageProcessor.makeEditableImage(from: image) else {
            alertMessage = "图片处理失败，请换一张图片试试。"
            return
        }
        pendingCropImage = editableImage
    }

    private func prepareCustomBackgroundImage(from data: Data) throws {
        guard let image = ThemeBackgroundImageProcessor.loadImage(from: data) else {
            throw NSError(
                domain: "XMusic.AppTheme",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "导入的文件不是可用图片。"]
            )
        }
        presentCropper(with: image)
    }
    #else
    private func prepareCustomBackgroundImage(from data: Data) throws {
        _ = data
    }
    #endif

    private func removeCustomBackgroundImage() {
        do {
            try AppThemeStorage.removeBackgroundImage()
            customBackgroundRevision += 1
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}

private struct ThemeActionButtonStyle: ViewModifier {
    let accent: Color

    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(accent.opacity(0.22), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(accent.opacity(0.36), lineWidth: 1)
            )
    }
}

private struct ThemeSecondaryActionButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
