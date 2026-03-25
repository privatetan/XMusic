import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    @EnvironmentObject private var musicSearch: MusicSearchViewModel
    @State private var resolvingSongID: String?
    @State private var playbackError: String?
    @State private var isDebugPanelExpanded = true
    @State private var playbackDebugInfo: PlaybackDebugInfo?
    private let isPlaybackDebugCardVisible = false
    private let isSearchDebugPanelVisible = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "搜索", subtitle: "内置多平台搜歌，播放时走当前激活音源解析地址")

                SearchField(text: $musicSearch.query)
                    .onChange(of: musicSearch.query) { _ in
                        musicSearch.scheduleSearch(allowedSources: searchableSources)
                    }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(searchableSourceTabs, id: \.rawValue) { source in
                            SearchSourcePill(
                                title: source.title,
                                isSelected: musicSearch.selectedSource == source
                            ) {
                                musicSearch.selectedSource = source
                                musicSearch.reload(allowedSources: searchableSources)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }

                if isSearchDebugPanelVisible,
                   !musicSearch.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    SearchDebugPanel(
                        entries: musicSearch.debugItems,
                        isExpanded: $isDebugPanelExpanded,
                        isSearching: musicSearch.isLoading || musicSearch.isLoadingMore
                    )
                }

                if musicSearch.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeading(
                            title: "搜索记录",
                            subtitle: musicSearch.searchHistory.isEmpty ? "你搜过的关键词会出现在这里" : "点一下就能重新搜索"
                        )

                        if musicSearch.searchHistory.isEmpty {
                            Text("还没有搜索记录。输入关键词后，搜索记录会自动保存在这里。")
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.62))
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        } else {
                            FlexibleTags(items: musicSearch.searchHistory) { keyword in
                                musicSearch.query = keyword
                                musicSearch.reload(allowedSources: searchableSources)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeading(title: "播放说明", subtitle: "搜索来自内置平台，播放依赖当前激活音源")

                        SearchStatusCard(
                            activeSourceName: sourceLibrary.activeSource?.name,
                            supportedSources: searchableSources.filter { $0 != .all }.map(\.title),
                            fallbackEnabled: sourceLibrary.enableAutomaticSourceFallback
                        )
                    }
                } else if musicSearch.isLoading && musicSearch.results.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)

                        Text("正在搜索 \(musicSearch.selectedSource.title)…")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.68))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeading(
                            title: "搜索结果",
                            subtitle: "\(musicSearch.selectedSource.title) · \(musicSearch.results.count) 首"
                        )

                        if let playbackError {
                            Text(playbackError)
                                .font(.footnote)
                                .foregroundStyle(Color(red: 1.00, green: 0.66, blue: 0.38))
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }

                        if let playbackDebugInfo, isPlaybackDebugCardVisible {
                            PlaybackDebugCard(info: playbackDebugInfo)
                        }

                        if let errorMessage = musicSearch.errorMessage, musicSearch.results.isEmpty {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(Color.white.opacity(0.72))
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }

                        ForEach(musicSearch.results) { song in
                            OnlineSearchResultRow(
                                song: song,
                                isResolving: resolvingSongID == song.id
                            ) {
                                play(song)
                            }
                        }

                        if musicSearch.canLoadMore {
                            Button {
                                musicSearch.loadMore(allowedSources: searchableSources)
                            } label: {
                                Text(musicSearch.isLoadingMore ? "正在加载…" : "加载更多")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
        .onAppear {
            if !musicSearch.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               musicSearch.results.isEmpty {
                musicSearch.reload(allowedSources: searchableSources)
            }
        }
        .onChange(of: sourceLibrary.activeSourceID) { _ in
            if !searchableSourceTabs.contains(musicSearch.selectedSource) {
                musicSearch.selectedSource = .all
            }
            if !musicSearch.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                musicSearch.reload(allowedSources: searchableSources)
            }
        }
    }

    private var searchableSources: [SearchPlatformSource] {
        let sourceNames = sourceLibrary.activeSource?.capabilities.compactMap { SearchPlatformSource(rawValue: $0.source) } ?? []
        return sourceNames.isEmpty ? SearchPlatformSource.builtIn : sourceNames
    }

    private var searchableSourceTabs: [SearchPlatformSource] {
        [.all] + searchableSources.sorted { lhs, rhs in
            searchSourcePriority(lhs) < searchSourcePriority(rhs)
        }
    }

    private func searchSourcePriority(_ source: SearchPlatformSource) -> Int {
        switch source {
        case .tx:
            return 0
        case .kw:
            return 1
        case .kg:
            return 2
        case .wy:
            return 3
        case .mg:
            return 4
        case .all:
            return -1
        }
    }

    private func play(_ song: SearchSong) {
        playbackError = nil
        playbackDebugInfo = nil
        resolvingSongID = song.id

        Task {
            defer {
                Task { @MainActor in
                    resolvingSongID = nil
                }
            }

            guard let activeSource = sourceLibrary.activeSource else {
                await MainActor.run {
                    playbackError = "请先导入并激活一个音乐源，再播放搜索结果。"
                }
                return
            }

            await MainActor.run {
                playbackDebugInfo = sourceLibrary.inspectPlaybackPayload(for: song, with: activeSource)
            }

            do {
                player.setSearchPlaybackResolver { [sourceLibrary] nextSong in
                    guard let currentSource = sourceLibrary.activeSource else {
                        throw NSError(
                            domain: "XMusic.SearchPlayback",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "当前没有激活音乐源。"]
                        )
                    }
                    return try await sourceLibrary.resolvePlayback(for: nextSong, with: currentSource)
                }

                let resolution = try await sourceLibrary.resolvePlayback(
                    for: song,
                    with: activeSource
                )

                await MainActor.run {
                    playbackDebugInfo = resolution.debugInfo
                    player.playResolvedSearchSong(
                        song,
                        from: musicSearch.results,
                        resolution: resolution,
                        sourceName: activeSource.name
                    )
                }
            } catch {
                await MainActor.run {
                    if let latestDebugInfo = sourceLibrary.latestPlaybackDebugInfo {
                        playbackDebugInfo = latestDebugInfo
                    }
                    playbackError = error.localizedDescription
                }
            }
        }
    }
}

struct PlaybackDebugCard: View {
    let info: PlaybackDebugInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("播放调试")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            if let strategy = info.resolutionStrategy {
                debugLine("解析策略", strategy)
            }
            if let requestedSource = info.requestedSource {
                debugLine("请求平台", displaySource(requestedSource))
            }
            if let resolvedSource = info.resolvedSource {
                debugLine("实际解析平台", displaySource(resolvedSource))
            }
            if let requestedQuality = info.requestedQuality {
                debugLine("请求音质", requestedQuality)
            }
            if let resolvedQuality = info.resolvedQuality {
                debugLine("实际音质", resolvedQuality)
            }
            if !info.attemptedSources.isEmpty {
                debugLine("尝试顺序", info.attemptedSources.map(displaySource).joined(separator: " -> "))
            }
            debugLine("命中解析缓存", info.usedResolverCache ? "是" : "否")
            if !info.originalURL.isEmpty {
                debugLine("原始地址", info.originalURL)
            }
            if !info.preparedURL.isEmpty {
                debugLine("准备后地址", info.preparedURL)
            }
            if !info.originalURL.isEmpty || !info.preparedURL.isEmpty {
                debugLine("走本地媒体缓存", info.usedLocalCache ? "是" : "否")
            }
            if let localPath = info.localPath {
                debugLine("本地路径", localPath)
                debugLine("文件存在", info.fileExists ? "是" : "否")
            }
            if let note = info.resolutionNote {
                debugLine("说明", note)
            }
            if !info.requestTrace.isEmpty {
                debugLine("请求轨迹", info.requestTrace.joined(separator: "\n"))
            }
            if !info.fieldChecks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("字段检查")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.5))
                    ForEach(info.fieldChecks) { check in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(check.isPresent ? "OK" : "MISS") · \(check.field): \(check.actualValue)")
                                .font(.footnote.monospaced())
                                .foregroundStyle(check.isPresent ? Color(red: 0.55, green: 0.90, blue: 0.72) : Color(red: 1.00, green: 0.63, blue: 0.45))
                            if let note = check.note {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(Color.white.opacity(0.52))
                            }
                        }
                    }
                }
            }
            if let legacyInfoJSON = info.legacyInfoJSON, !legacyInfoJSON.isEmpty {
                debugLine("实际传出的 legacyInfoJSON", legacyInfoJSON)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func debugLine(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.5))
            Text(value)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.76))
                .textSelection(.enabled)
        }
    }

    private func displaySource(_ sourceName: String) -> String {
        SearchPlatformSource(rawValue: sourceName)?.title ?? sourceName.uppercased()
    }
}

private struct SearchSourcePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(isSelected ? 0 : 0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct SearchStatusCard: View {
    let activeSourceName: String?
    let supportedSources: [String]
    let fallbackEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(activeSourceName == nil ? "当前还没有激活音源" : "当前音源：\(activeSourceName!)")
                .font(.headline)
                .foregroundStyle(.white)

            Text(activeSourceName == nil
                 ? "你可以先直接搜索看看结果，真正点播放前再去“音乐源管理”激活一个源。"
                 : "当前激活音源可用于这些平台：\(supportedSources.joined(separator: " / "))")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            Text(fallbackEnabled ? "自动换源：已启用" : "自动换源：已禁用，仅测试原平台")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(fallbackEnabled ? Color(red: 0.57, green: 0.86, blue: 0.73) : Color(red: 1.00, green: 0.72, blue: 0.47))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct OnlineSearchResultRow: View {
    let song: SearchSong
    let isResolving: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                AsyncImage(url: song.artworkURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    TrackArtworkFallbackView(
                        platformTitle: song.source.title,
                        trackTitle: song.title,
                        cornerRadius: 18,
                        tintColors: [Color(red: 0.20, green: 0.32, blue: 0.54), Color(red: 0.08, green: 0.11, blue: 0.20)]
                    )
                }
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(song.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(song.source.title)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08), in: Capsule())
                            .foregroundStyle(Color.white.opacity(0.72))
                    }

                    Text("\(song.artist) • \(song.album)")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.64))
                        .lineLimit(1)

                    Text("\(song.durationText) · \(song.preferredQuality)")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.48))
                }

                Spacer(minLength: 12)

                if isResolving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SearchDebugPanel: View {
    let entries: [SearchDebugItem]
    @Binding var isExpanded: Bool
    let isSearching: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("搜索调试面板", systemImage: "wrench.and.screwdriver.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    if isSearching {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.52))
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                if entries.isEmpty {
                    Text("当前还没有调试结果。输入关键词后会显示每个平台是成功、无结果，还是直接报错。")
                        .font(.footnote)
                        .foregroundStyle(Color.white.opacity(0.64))
                } else {
                    VStack(spacing: 10) {
                        ForEach(entries) { entry in
                            SearchDebugRow(entry: entry)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct SearchDebugRow: View {
    let entry: SearchDebugItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.source.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(statusText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(statusColor)
                }

                Text("\(entry.message) · 本页 \(entry.resultCount) 首 · 总数 \(entry.total) · 页 \(entry.page)/\(max(entry.maxPage, 1))")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var statusColor: Color {
        switch entry.status {
        case .success:
            return Color(red: 0.48, green: 0.92, blue: 0.72)
        case .empty:
            return Color(red: 0.99, green: 0.78, blue: 0.39)
        case .error:
            return Color(red: 1.00, green: 0.50, blue: 0.42)
        }
    }

    private var statusText: String {
        switch entry.status {
        case .success:
            return "成功"
        case .empty:
            return "无结果"
        case .error:
            return "失败"
        }
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.white.opacity(0.55))

            TextField("搜索歌名、艺人、专辑", text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.white.opacity(0.36))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct FlexibleTags: View {
    let items: [String]
    let action: (String) -> Void
    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                Button(item) {
                    action(item)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .foregroundStyle(.white)
            }
        }
    }
}
