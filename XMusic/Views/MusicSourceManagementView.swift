//
//  MusicSourceManagementView.swift
//  XMusic
//
//  Created by Codex on 2026/3/20.
//

import SwiftUI
import UniformTypeIdentifiers

private extension View {
    @ViewBuilder
    func compatibleSheetPresentation() -> some View {
        if #available(iOS 16.0, *) {
            self
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatibleScrollContentBackgroundHidden() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

struct MusicSourceManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary

    @State private var isFileImporterPresented = false
    @State private var isPasteSheetPresented = false
    @State private var alertMessage: String?
    @State private var isImporting = false
    @State private var isRuntimeLabExpanded = false

    private var effectiveMediaCacheSummary: MediaCacheSummary {
        mergedMediaCacheSummary(
            playerTracks: player.cachedTracks,
            cachedFiles: sourceLibrary.cachedMediaFilesSnapshot
        )
    }

    var body: some View {
        AppNavigationContainerView {
            ZStack {
                AppBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("音乐源管理")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        HStack(spacing: 12) {
                            ActionPill(title: "导入文件", symbol: "square.and.arrow.down") {
                                isFileImporterPresented = true
                            }

                            ActionPill(title: "粘贴脚本或链接", symbol: "doc.badge.plus") {
                                isPasteSheetPresented = true
                            }
                        }

                        mediaCacheCard

                        if sourceLibrary.sources.isEmpty {
                            emptyState
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                sectionHeader(title: "已导入的音乐源")

                                ForEach(sourceLibrary.sources) { source in
                                    MusicSourceCard(
                                        source: source,
                                        isActive: sourceLibrary.activeSourceID == source.id,
                                        onActivate: { handleAction { try sourceLibrary.activate(source) } },
                                        onReparse: { handleAction { try sourceLibrary.reparse(source) } },
                                        onRemove: { handleAction { try sourceLibrary.remove(source) } }
                                    )
                                }
                            }
                        }

                        if let activeSource = sourceLibrary.activeSource {
                            runtimeLabSection(activeSource: activeSource)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("音乐源")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: supportedFileTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                handleAction {
                    try sourceLibrary.importFile(from: url)
                }
            case let .failure(error):
                alertMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $isPasteSheetPresented) {
            MusicSourcePasteView { script in
                handleAsyncAction {
                    try await sourceLibrary.importInput(script)
                }
            }
            .compatibleSheetPresentation()
        }
        .alert(
            "音乐源处理失败",
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
        .overlay {
            if isImporting {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView("正在导入音乐源...")
                        .tint(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private func runtimeLabSection(activeSource: ImportedMusicSource) -> some View {
        DisclosureGroup(
            isExpanded: $isRuntimeLabExpanded,
            content: {
                MusicSourceRuntimeLab(source: activeSource)
                    .padding(.top, 12)
            },
            label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("运行测试")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Text(isRuntimeLabExpanded ? "收起" : "展开")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.56))
                }
            }
        )
        .tint(.white)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("还没有导入任何音乐源")
                .font(.headline)
                .foregroundStyle(.white)

            Text("导入一个脚本后会显示在这里。")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.68))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var mediaCacheCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("媒体缓存")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(effectiveMediaCacheSummary.isEmpty
                     ? "暂无缓存"
                     : "\(effectiveMediaCacheSummary.fileCount) 个文件 · \(effectiveMediaCacheSummary.formattedSize)")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            MiniActionButton(
                title: "清理",
                symbol: "trash",
                role: .destructive,
                isDisabled: false
            ) {
                handleAction {
                    try sourceLibrary.clearMediaCache()
                    player.clearCachedTracks()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var supportedFileTypes: [UTType] {
        [
            .plainText,
            .sourceCode,
            UTType(filenameExtension: "js"),
            UTType(filenameExtension: "txt"),
        ].compactMap { $0 }
    }

    private func handleAction(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func handleAsyncAction(_ action: @escaping () async throws -> Void) {
        isImporting = true

        Task {
            do {
                try await action()
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                isImporting = false
            }
        }
    }

    private func sectionHeader(title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
        }
    }
}

private struct MusicSourceCard: View {
    let source: ImportedMusicSource
    let isActive: Bool
    let onActivate: () -> Void
    let onReparse: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(source.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)

                        if isActive {
                            Text("当前")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(red: 0.48, green: 0.92, blue: 0.72).opacity(0.18), in: Capsule())
                                .foregroundStyle(Color(red: 0.48, green: 0.92, blue: 0.72))
                        }

                        if source.parseErrorMessage != nil {
                            Text("异常")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.14), in: Capsule())
                                .foregroundStyle(Color.orange)
                        }
                    }

                    Text(detailLine)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.62))
                        .lineLimit(1)
                }

                Spacer(minLength: 12)
            }

            if let parseErrorMessage = source.parseErrorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("脚本解析失败")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 1.00, green: 0.66, blue: 0.38))

                    Text(parseErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            HStack(spacing: 10) {
                MiniActionButton(
                    title: isActive ? "已激活" : "设为当前",
                    symbol: isActive ? "checkmark.circle.fill" : "bolt.fill",
                    isDisabled: isActive,
                    action: onActivate
                )

                MiniActionButton(
                    title: "重新解析",
                    symbol: "arrow.clockwise",
                    action: onReparse
                )

                MiniActionButton(
                    title: "移除",
                    symbol: "trash",
                    role: .destructive,
                    action: onRemove
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var detailLine: String {
        var segments: [String] = []
        if !source.author.isEmpty {
            segments.append(source.author)
        }
        if !source.version.isEmpty {
            segments.append("v\(source.version)")
        }
        if let originalFileName = source.originalFileName {
            segments.append(originalFileName)
        }
        return segments.isEmpty ? "导入于 \(source.importedAt.formatted(date: .abbreviated, time: .shortened))" : segments.joined(separator: " • ")
    }
}

private struct MusicSourcePasteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var script = ""

    let onImport: (String) -> Void

    var body: some View {
        AppNavigationContainerView {
            VStack(spacing: 16) {
                TextEditor(text: $script)
                    .compatibleScrollContentBackgroundHidden()
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .foregroundStyle(.white)

                Text("支持直接粘贴脚本文本，也支持粘贴 `https://.../latest.js` 这样的远程音乐源链接。")
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.62))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    onImport(script)
                    dismiss()
                } label: {
                    Text("开始导入")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .disabled(script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
            }
            .padding(20)
            .background(AppBackgroundView())
            .navigationTitle("粘贴音乐源")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct MusicSourceRuntimeLab: View {
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    @EnvironmentObject private var musicSearch: MusicSearchViewModel
    @EnvironmentObject private var player: MusicPlayerViewModel

    let source: ImportedMusicSource

    @State private var selectedPlatformSource = "kw"
    @State private var selectedQuality = "128k"
    @State private var songInfoJSON = ""
    @State private var resolvedURL: URL?
    @State private var playbackDebugInfo: PlaybackDebugInfo?
    @State private var lyricResult: MusicSourceLyricResult?
    @State private var pictureURL: URL?
    @State private var isWorking = false
    @State private var runtimeError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("运行测试")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("LX 的自定义源只负责 `musicUrl / lyric / pic`。这里可以直接粘贴一份 `songInfo` JSON，测试当前源是否真的能跑通。默认模板里的关键字段是空的，像酷狗需要真实 `hash`，否则会直接报错。")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                PickerChip(
                    title: "平台",
                    value: selectedPlatformSource.uppercased(),
                    items: availableSources
                ) { selectedPlatformSource = $0 }

                PickerChip(
                    title: "音质",
                    value: selectedQuality,
                    items: qualityOptions
                ) { selectedQuality = $0 }
            }

            HStack(spacing: 10) {
                MiniActionButton(title: "填充模板", symbol: "doc.text") {
                    songInfoJSON = LxLegacySongInfo.template(for: selectedPlatformSource)
                }

                SearchSongFillMenu(
                    songs: searchFillCandidates,
                    query: musicSearch.query,
                    onSelect: fillFromSearchSong(_:)
                )

                MiniActionButton(title: "读取能力", symbol: "bolt.badge.checkmark") {
                    runAction {
                        _ = try await sourceLibrary.runtimeCapabilities(for: source)
                    }
                }
            }

            Text(searchHint)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $songInfoJSON)
                .compatibleScrollContentBackgroundHidden()
                .frame(minHeight: 210)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                ActionPillCompact(title: "解析地址", symbol: "link") {
                    runAction {
                        let url = try await sourceLibrary.resolveMusicURL(
                            with: source,
                            platformSource: selectedPlatformSource,
                            legacySongInfoJSON: songInfoJSON,
                            quality: selectedQuality
                        )
                        let debugInfo = try await sourceLibrary.preparePlayableURLWithDebug(from: url)
                        let playableURL = URL(string: debugInfo.preparedURL) ?? url
                        await MainActor.run {
                            resolvedURL = playableURL
                            playbackDebugInfo = debugInfo
                            lyricResult = nil
                            pictureURL = nil
                        }
                    }
                }

                ActionPillCompact(title: "歌词", symbol: "text.quote") {
                    runAction {
                        let lyric = try await sourceLibrary.resolveLyric(
                            with: source,
                            platformSource: selectedPlatformSource,
                            legacySongInfoJSON: songInfoJSON
                        )
                        await MainActor.run {
                            lyricResult = lyric
                        }
                    }
                }

                ActionPillCompact(title: "封面", symbol: "photo") {
                    runAction {
                        let url = try await sourceLibrary.resolvePicture(
                            with: source,
                            platformSource: selectedPlatformSource,
                            legacySongInfoJSON: songInfoJSON
                        )
                        await MainActor.run {
                            pictureURL = url
                        }
                    }
                }
            }

            if let resolvedURL {
                VStack(alignment: .leading, spacing: 10) {
                    Text("已解析地址")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))

                    Text(resolvedURL.absoluteString)
                        .font(.footnote)
                        .foregroundStyle(Color.white.opacity(0.72))
                        .textSelection(.enabled)

                    MiniActionButton(title: "用这个地址播放", symbol: "play.fill") {
                        playResolvedURL(resolvedURL)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }

            if let playbackDebugInfo {
                PlaybackDebugCard(info: playbackDebugInfo)
            }

            if let lyricResult {
                VStack(alignment: .leading, spacing: 8) {
                    Text("歌词结果")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))

                    Text(lyricResult.lyric)
                        .font(.footnote)
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(8)
                }
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }

            if let pictureURL {
                VStack(alignment: .leading, spacing: 10) {
                    Text("封面结果")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))

                    AsyncImage(url: pictureURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                            .tint(.white)
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Text(pictureURL.absoluteString)
                        .font(.footnote)
                        .foregroundStyle(Color.white.opacity(0.72))
                        .textSelection(.enabled)
                }
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }

            if let runtimeError {
                Text(runtimeError)
                    .font(.footnote)
                    .foregroundStyle(Color(red: 1.00, green: 0.66, blue: 0.38))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if isWorking {
                ProgressView()
                    .tint(.white)
                    .padding(14)
            }
        }
        .onAppear {
            if songInfoJSON.isEmpty {
                selectedPlatformSource = availableSources.first ?? "kw"
                selectedQuality = qualityOptions.first ?? "128k"
                songInfoJSON = LxLegacySongInfo.template(for: selectedPlatformSource)
            }
        }
        .appOnChange(of: selectedPlatformSource) {
            if !qualityOptions.contains(selectedQuality) {
                selectedQuality = qualityOptions.first ?? "128k"
            }
        }
    }

    private var availableSources: [String] {
        let sources = source.capabilities.map(\.source)
        return sources.isEmpty ? LxLegacySongInfo.fallbackSources : sources
    }

    private var searchFillCandidates: [SearchSong] {
        musicSearch.results.filter { availableSources.contains($0.source.rawValue) }
    }

    private var searchHint: String {
        let trimmedQuery = musicSearch.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchFillCandidates.isEmpty else {
            return trimmedQuery.isEmpty
                ? "先在搜索页搜到一首歌，这里就能直接带入真实 songInfo。"
                : "当前搜索“\(trimmedQuery)”里没有这个音源可用的平台结果。"
        }

        let sourceList = Array(Set(searchFillCandidates.map(\.source.title))).sorted().joined(separator: " / ")
        return "当前搜索“\(trimmedQuery)”已有 \(searchFillCandidates.count) 条可用结果，支持直接填充 \(sourceList) 的真实 songInfo。"
    }

    private var qualityOptions: [String] {
        qualityOptions(for: selectedPlatformSource)
    }

    private func qualityOptions(for sourceName: String) -> [String] {
        if let capability = source.capabilities.first(where: { $0.source == sourceName }),
           !capability.qualitys.isEmpty {
            return capability.qualitys
        }
        return ["128k", "320k", "flac", "flac24bit"]
    }

    private func runAction(_ action: @escaping () async throws -> Void) {
        isWorking = true
        runtimeError = nil
        playbackDebugInfo = nil

        Task {
            do {
                try await action()
            } catch {
                await MainActor.run {
                    runtimeError = error.localizedDescription
                }
            }

            await MainActor.run {
                isWorking = false
            }
        }
    }

    private func playResolvedURL(_ url: URL) {
        do {
            let legacyInfo = try LxLegacySongInfo.parseLegacyJSON(songInfoJSON, sourceName: selectedPlatformSource)
            let displayInfo = LxLegacySongInfo.displayInfo(from: legacyInfo)
            let track = Track.resolvedSourceTrack(
                url: url,
                title: displayInfo.title,
                artist: displayInfo.artist,
                album: displayInfo.album,
                sourceName: source.name
            )
            player.play(track, from: [track])
        } catch {
            runtimeError = error.localizedDescription
        }
    }

    private func fillFromSearchSong(_ song: SearchSong) {
        let sourceName = song.source.rawValue
        let supportedQualities = qualityOptions(for: sourceName)
        let preferredOrder = ["flac24bit", "flac", "320k", "128k"]

        selectedPlatformSource = sourceName
        selectedQuality = preferredOrder.first { supportedQualities.contains($0) && song.qualities.contains($0) }
            ?? supportedQualities.first
            ?? song.preferredQuality
        songInfoJSON = song.legacyInfoJSON
        resolvedURL = nil
        playbackDebugInfo = nil
        lyricResult = nil
        pictureURL = nil
        runtimeError = nil
    }
}

private struct SearchSongFillMenu: View {
    let songs: [SearchSong]
    let query: String
    let onSelect: (SearchSong) -> Void

    var body: some View {
        Menu {
            if songs.isEmpty {
                Text(emptyTitle)
            } else {
                ForEach(Array(songs.prefix(20))) { song in
                    Button(songLabel(for: song)) {
                        onSelect(song)
                    }
                }
            }
        } label: {
            Label("从搜索结果填充", systemImage: "text.badge.star")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08), in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(songs.isEmpty)
        .opacity(songs.isEmpty ? 0.55 : 1)
    }

    private var emptyTitle: String {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedQuery.isEmpty ? "先去搜索页搜一首歌" : "当前搜索没有可用结果"
    }

    private func songLabel(for song: SearchSong) -> String {
        "\(song.source.title) · \(song.title) - \(song.artist)"
    }
}

private struct ActionPill: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ActionPillCompact: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct PickerChip: View {
    let title: String
    let value: String
    let items: [String]
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(items, id: \.self) { item in
                Button(item.uppercased()) {
                    onSelect(item)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.52))

                HStack(spacing: 8) {
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MiniActionButton: View {
    let title: String
    let symbol: String
    var role: ButtonRole? = nil
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08), in: Capsule())
                .foregroundStyle(role == .destructive ? Color.red.opacity(0.9) : Color.white)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
    }
}
