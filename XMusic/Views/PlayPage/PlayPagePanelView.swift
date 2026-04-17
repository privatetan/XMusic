import Foundation
import SwiftUI

#if os(iOS)
import AVKit
import MediaPlayer
#endif

#if canImport(UIKit)
import UIKit
#endif

struct PlayPagePanelView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    @EnvironmentObject private var musicSearch: MusicSearchViewModel
    @ObservedObject var timeline: PlaybackTimeline
    @State private var isScrubbing = false
    @State private var draftTime: Double = 0
    @State private var dragOffset: CGFloat = 0
    @State private var showContent = true
    @State private var lyricsPresentationMode: LyricsPresentationMode = .hidden
    @State private var isLoadingLyrics = false
    @State private var lyricsStateTrackID: UUID?
    @State private var loadedLyricsTrackID: UUID?
    @State private var lyricResult: MusicSourceLyricResult?
    @State private var lyricsErrorMessage: String?
    @State private var isExternalAudioRouteActive = false
    @State private var isRouteSheetPresented = false
    @State private var routePickerTrigger = 0
    @State private var isLyricsAtTop = true
    let animation: Namespace.ID
    /// 从父视图传入的稳定尺寸，避免 GeometryReader 在转场动画期间
    /// 拿到 .zero / 不正确的值导致布局卡死。
    var containerSize: CGSize = .zero
    let close: () -> Void

    var body: some View {
        if let track = player.currentTrack {
            GeometryReader { geometry in
                let geometry = StableGeometry(
                    proposed: geometry,
                    fallbackSize: containerSize
                )
                let layout = PlayPagePanelLayout(
                    size: geometry.size,
                    safeAreaInsets: geometry.safeAreaInsets
                )
                let lyricLines = parsedLyricLines(for: track)
                let activeLineID = currentLyricLineID(for: track, lines: lyricLines)
                let topSectionHeight = lyricsPresentationMode == .full ? layout.availableHeight : layout.topSectionHeight

                ZStack {
                    RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.67, green: 0.64, blue: 0.64),
                                    Color(red: 0.58, green: 0.55, blue: 0.55),
                                    Color(red: 0.53, green: 0.50, blue: 0.50)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .matchedGeometryEffect(id: "PlayerBackground", in: animation)
                        .ignoresSafeArea()
                        .scaleEffect(x: currentScaleX, y: currentScaleY)
                        .opacity(backgroundOpacity)

                    VStack(spacing: 0) {
                        PlayPageArtworkSectionView(
                            track: track,
                            animation: animation,
                            layout: layout,
                            squeezeProgress: squeezeProgress,
                            lines: lyricLines,
                            activeLineID: activeLineID,
                            isLoadingLyrics: isLoadingLyrics,
                            lyricsErrorMessage: lyricsErrorMessage,
                            lyricsPresentationMode: lyricsPresentationMode,
                            showContent: showContent,
                            onArtistTap: { openArtistSearch(for: track) },
                            onRetryLyrics: { loadLyrics(for: track, force: true) },
                            onLyricsTopStateChange: { isLyricsAtTop = $0 },
                            onLyricsHeaderTap: { toggleLyricsExpansion(for: track) }
                        )
                        .frame(height: topSectionHeight, alignment: .top)
                        .contentShape(Rectangle())
                        .simultaneousGesture(lyricsModeDragGesture)

                        if lyricsPresentationMode != .full {
                            PlayPageControlsSectionView(
                                timeline: timeline,
                                layout: layout,
                                showContent: showContent,
                                squeezeProgress: squeezeProgress,
                                isExternalAudioRouteActive: isExternalAudioRouteActive,
                                isScrubbing: $isScrubbing,
                                draftTime: $draftTime,
                                isLyricsPresented: Binding(
                                    get: { lyricsPresentationMode.isPresented },
                                    set: { lyricsPresentationMode = $0 ? .half : .hidden }
                                ),
                                isRouteSheetPresented: $isRouteSheetPresented,
                                routePickerTrigger: $routePickerTrigger,
                                onPrevious: { player.playPrevious() },
                                onTogglePlayback: { player.togglePlayback() },
                                onNext: { player.playNext() },
                                onLyricsTap: { handleLyricsButtonTap(for: track) }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(width: layout.contentWidth, height: layout.availableHeight, alignment: .top)
                    .padding(.top, layout.safeTop)
                    .padding(.horizontal, layout.horizontalPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    Circle()
                        .fill(track.artwork.glow.opacity(0.10))
                        .frame(width: 560, height: 560)
                        .blur(radius: 130)
                        .offset(y: -240 + dragOffset * 0.18)
                        .opacity(showContent ? 1 : 0)
                        .allowsHitTesting(false)

                    if isRouteSheetPresented {
                        routeSheetOverlay(
                            track: track,
                            safeBottom: layout.safeBottom,
                            horizontalPadding: layout.horizontalPadding,
                            compactHeight: layout.compactHeight
                        )
                        .zIndex(121)
                    }
                }
                #if canImport(UIKit)
                .background(
                    DismissPanCaptureView(
                        onChanged: { dragOffset = $0 },
                        onEnded: { ty, vy in
                            let shouldDismiss = ty > 120 || (ty > 44 && vy > 900)
                            if shouldDismiss {
                                dismissPanel()
                            } else {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                    dragOffset = 0
                                }
                            }
                        },
                        shouldBegin: { shouldAllowPanelDismissGesture }
                    )
                )
                #endif
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .offset(y: dragOffset)
                .task(id: track.id) {
                    handleTrackChange(track)
                }
                .onDisappear {
                    resetLyricsState()
                }
            }
            .ignoresSafeArea()
            .onAppear {
                resetTransientPresentationState()
            }
            .onAppear(perform: refreshAudioRouteState)
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { _ in
                refreshAudioRouteState()
            }
        }
    }

    private var backgroundOpacity: Double {
        let progress = min(max(dragOffset / 360, 0), 1)
        return 1 - Double(progress) * 0.22
    }

    private var squeezeProgress: CGFloat {
        let threshold: CGFloat = 420
        return min(max(dragOffset / threshold, 0), 1)
    }

    private var currentScaleX: CGFloat {
        let baseScale: CGFloat = showContent ? 1.0 : 0.82
        return baseScale - (squeezeProgress * 0.18)
    }

    private var currentScaleY: CGFloat {
        let baseScale: CGFloat = showContent ? 1.0 : 0.96
        return baseScale - (squeezeProgress * 0.04)
    }

    private var currentCornerRadius: CGFloat {
        let baseRadius: CGFloat = showContent ? 48 : 28
        return baseRadius - (squeezeProgress * 20)
    }

    private func resetTransientPresentationState() {
        isScrubbing = false
        draftTime = timeline.currentTime
        dragOffset = 0
        lyricsPresentationMode = .hidden
        isLyricsAtTop = true

        showContent = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.45).delay(0.1)) {
                showContent = true
            }
        }
    }

    private func dismissPanel() {
        close()
    }

    private var shouldAllowPanelDismissGesture: Bool {
        guard lyricsPresentationMode.isPresented else { return true }
        return isLyricsAtTop
    }

    private var lyricsModeDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onEnded { value in
                guard lyricsPresentationMode.isPresented else { return }

                let verticalTranslation = value.translation.height
                let predictedVerticalTranslation = value.predictedEndTranslation.height
                let isExpanding = lyricsPresentationMode == .half &&
                    (verticalTranslation < -18 || predictedVerticalTranslation < -44)
                let isCollapsing = lyricsPresentationMode == .full &&
                    (verticalTranslation > 14 || predictedVerticalTranslation > 52)

                if isExpanding {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        lyricsPresentationMode = .full
                    }
                } else if isCollapsing {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                        lyricsPresentationMode = .half
                    }
                }
            }
    }

    private var searchableSources: [SearchPlatformSource] {
        let sourceNames = sourceLibrary.activeSource?.capabilities.compactMap { SearchPlatformSource(rawValue: $0.source) } ?? []
        return sourceNames.isEmpty ? SearchPlatformSource.builtIn : sourceNames
    }

    private func openArtistSearch(for track: Track) {
        let artist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !artist.isEmpty else { return }

        musicSearch.startSearch(query: artist, allowedSources: searchableSources)
        player.selectedTab = .search
        dismissPanel()
    }

    @ViewBuilder
    private func routeSheetOverlay(
        track: Track,
        safeBottom: CGFloat,
        horizontalPadding: CGFloat,
        compactHeight: Bool
    ) -> some View {
        let deviceName = UIDevice.current.name
        let currentRouteName = AVAudioSession.sharedInstance().currentRoute.outputs.first?.portName ?? deviceName
        let panelWidth = min(UIScreen.main.bounds.width - horizontalPadding * 2, compactHeight ? 320 : 352)
        let bottomInset = max(safeBottom + 96, 104)
        let panelBackground = Color(red: 0.28, green: 0.23, blue: 0.31).opacity(0.97)
        let panelStroke = Color.white.opacity(0.07)

        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.03),
                    Color.black.opacity(0.16),
                    Color.black.opacity(0.28)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .transition(.opacity)
            .onTapGesture {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    isRouteSheetPresented = false
                }
            }

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Image(systemName: "airplayaudio")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.82))

                        Text("AirPlay")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 14)

                    VStack(alignment: .leading, spacing: 0) {
                        routeRow(
                            systemName: "iphone",
                            title: "iPhone"
                        )
                        routeDivider()
                        routeRow(
                            systemName: "airpodspro",
                            title: "AirPods Pro",
                            subtitle: "未连接"
                        )
                        routeDivider()
                        routeRow(
                            systemName: "homepodmini.fill",
                            title: "Living Room",
                            subtitle: "HomePod mini"
                        )
                    }
                    .padding(.bottom, 12)
                }
                .frame(width: panelWidth)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(panelBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(panelStroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 28, x: 0, y: 14)

                Text("正在播放到 \(currentRouteName)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.58))
                    .padding(.top, 16)
                    .padding(.bottom, bottomInset)
            }
            .padding(.horizontal, horizontalPadding)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func routeRow(
        systemName: String,
        title: String,
        subtitle: String? = nil
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.52))
                }
            }

            Spacer(minLength: 12)

            if title == "iPhone" {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func routeDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 60)
    }

    private func handleLyricsButtonTap(for track: Track) {
        lyricsPresentationMode = lyricsPresentationMode.isPresented ? .hidden : .half
        guard lyricsPresentationMode.isPresented else { return }
        loadLyrics(for: track, force: false)
    }

    private func toggleLyricsExpansion(for track: Track) {
        guard lyricsPresentationMode.isPresented else {
            handleLyricsButtonTap(for: track)
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            lyricsPresentationMode = lyricsPresentationMode == .full ? .half : .full
        }

        loadLyrics(for: track, force: false)
    }

    private func handleTrackChange(_ track: Track) {
        guard lyricsPresentationMode.isPresented else {
            resetLyricsState(keepPresentation: true)
            return
        }

        loadLyrics(for: track, force: true)
    }

    private func resetLyricsState(keepPresentation: Bool = false) {
        isLoadingLyrics = false
        lyricsStateTrackID = nil
        loadedLyricsTrackID = nil
        lyricResult = nil
        lyricsErrorMessage = nil
        if !keepPresentation {
            lyricsPresentationMode = .hidden
            isLyricsAtTop = true
        }
    }

    private func loadLyrics(for track: Track, force: Bool) {
        lyricsStateTrackID = track.id

        if !force, loadedLyricsTrackID == track.id, lyricResult != nil {
            lyricsErrorMessage = nil
            return
        }

        lyricResult = nil
        lyricsErrorMessage = nil
        isLoadingLyrics = true

        Task {
            let currentTrackID = track.id

            do {
                guard let searchSong = track.searchSong else {
                    throw NSError(
                        domain: "XMusic.Lyrics",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "这首歌当前没有可用于解析歌词的歌曲信息。"]
                    )
                }

                let platformSource = searchSong.source.rawValue
                let resolvedLyrics: MusicSourceLyricResult

                do {
                    resolvedLyrics = try await BuiltInLyricService.shared.resolveLyric(for: searchSong)
                } catch {
                    let source = preferredLyricsSource(for: track, platformSource: platformSource)
                    guard let source else {
                        let builtInMessage = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                        let message = builtInMessage.isEmpty
                            ? "当前没有可用的内置歌词，也没有任何已导入音源支持 \(searchSong.source.title) 的歌词解析。"
                            : "\(builtInMessage)。当前也没有任何已导入音源支持 \(searchSong.source.title) 的歌词解析。"
                        throw NSError(
                            domain: "XMusic.Lyrics",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: message]
                        )
                    }

                    resolvedLyrics = try await sourceLibrary.resolveLyric(
                        with: source,
                        platformSource: platformSource,
                        legacySongInfoJSON: searchSong.legacyInfoJSON
                    )
                }

                guard player.currentTrack?.id == currentTrackID, lyricsStateTrackID == currentTrackID else { return }
                isLoadingLyrics = false
                loadedLyricsTrackID = currentTrackID
                lyricResult = resolvedLyrics
            } catch {
                guard player.currentTrack?.id == currentTrackID, lyricsStateTrackID == currentTrackID else { return }
                isLoadingLyrics = false
                loadedLyricsTrackID = nil
                lyricsErrorMessage = error.localizedDescription
            }
        }
    }

    private func preferredLyricsSource(for track: Track, platformSource: String) -> ImportedMusicSource? {
        if let sourceName = track.sourceName,
           let matchedSource = sourceLibrary.sources.first(where: { $0.name == sourceName }),
           matchedSource.supports(source: platformSource, action: .lyric) {
            return matchedSource
        }

        if let activeSource = sourceLibrary.activeSource,
           activeSource.supports(source: platformSource, action: .lyric) {
            return activeSource
        }

        return sourceLibrary.sources.first { $0.supports(source: platformSource, action: .lyric) }
    }

    private func parsedLyricLines(for track: Track) -> [ParsedLyricLine] {
        guard loadedLyricsTrackID == track.id, let lyricResult else { return [] }
        let primaryLyric = preferredPrimaryLyric(from: lyricResult)
        let parsedPrimary = parseTimedLyricEntries(from: primaryLyric)

        guard !parsedPrimary.isEmpty else { return [] }

        var mergedLines: [ParsedLyricLine] = []
        var lineIndexByTime: [Int: Int] = [:]

        for entry in parsedPrimary {
            if let existingIndex = lineIndexByTime[entry.time] {
                if mergedLines[existingIndex].text != entry.text,
                   !mergedLines[existingIndex].extendedLyrics.contains(entry.text) {
                    mergedLines[existingIndex].extendedLyrics.append(entry.text)
                }
                continue
            }

            let newIndex = mergedLines.count
            mergedLines.append(
                ParsedLyricLine(
                    id: "\(entry.time)-\(newIndex)",
                    time: entry.time,
                    text: entry.text,
                    extendedLyrics: []
                )
            )
            lineIndexByTime[entry.time] = newIndex
        }

        for extraLyric in [lyricResult.tlyric, lyricResult.rlyric].compactMap({ $0 }) {
            for entry in parseTimedLyricEntries(from: extraLyric) {
                guard let index = lineIndexByTime[entry.time] else { continue }
                guard entry.text != mergedLines[index].text else { continue }
                guard !mergedLines[index].extendedLyrics.contains(entry.text) else { continue }
                mergedLines[index].extendedLyrics.append(entry.text)
            }
        }

        return mergedLines
    }

    private func currentLyricLineID(for track: Track, lines: [ParsedLyricLine]) -> String? {
        guard loadedLyricsTrackID == track.id, !lines.isEmpty else { return nil }

        let currentTime = Int((isScrubbing ? draftTime : timeline.currentTime) * 1000)
        guard currentTime >= 0 else { return nil }

        var low = 0
        var high = lines.count - 1
        var candidateIndex: Int?

        while low <= high {
            let middle = (low + high) / 2
            if lines[middle].time <= currentTime {
                candidateIndex = middle
                low = middle + 1
            } else {
                high = middle - 1
            }
        }

        return candidateIndex.map { lines[$0].id }
    }

    private func preferredPrimaryLyric(from result: MusicSourceLyricResult) -> String {
        let primary = result.lyric.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty {
            return primary
        }

        return result.lxlyric?
            .replacingOccurrences(
                of: #"<\d+,\d+>"#,
                with: "",
                options: .regularExpression
            ) ?? ""
    }

    private func parseTimedLyricEntries(from text: String) -> [(time: Int, text: String)] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let linePattern = #"\[(\d{1,3}(?::\d{1,3}){0,2}(?:\.\d{1,3})?)\]"#
        guard let regex = try? NSRegularExpression(pattern: linePattern) else { return [] }

        var entries: [(time: Int, text: String)] = []

        for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.range(of: #"^\[(ti|ar|al|by|offset):.*\]$"#, options: .regularExpression) != nil {
                continue
            }

            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            guard !matches.isEmpty else { continue }

            var content = line
            for match in matches.reversed() {
                content = (content as NSString).replacingCharacters(in: match.range, with: "")
            }

            let cleanedContent = content
                .replacingOccurrences(of: #"<\d+,\d+>"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleanedContent.isEmpty else { continue }

            for match in matches {
                let timeLabel = nsLine.substring(with: match.range(at: 1))
                guard let milliseconds = lyricTimeMilliseconds(from: timeLabel) else { continue }
                entries.append((time: milliseconds, text: cleanedContent))
            }
        }

        return entries.sorted { lhs, rhs in
            if lhs.time == rhs.time {
                return lhs.text < rhs.text
            }
            return lhs.time < rhs.time
        }
    }

    private func lyricTimeMilliseconds(from label: String) -> Int? {
        let mainParts = label.split(separator: ":")
        guard !mainParts.isEmpty, mainParts.count <= 3 else { return nil }

        var timeParts = mainParts.map(String.init)
        while timeParts.count < 3 {
            timeParts.insert("0", at: 0)
        }

        let hour = Int(timeParts[0]) ?? 0
        let minute = Int(timeParts[1]) ?? 0

        let secondPart = timeParts[2].split(separator: ".", omittingEmptySubsequences: false)
        guard let second = Int(secondPart[0]) else { return nil }

        let millisecond: Int
        if secondPart.count > 1 {
            var decimal = String(secondPart[1].prefix(3))
            while decimal.count < 3 {
                decimal.append("0")
            }
            millisecond = Int(decimal) ?? 0
        } else {
            millisecond = 0
        }

        return hour * 3_600_000 + minute * 60_000 + second * 1_000 + millisecond
    }

    private func refreshAudioRouteState() {
        #if os(iOS)
        let route = AVAudioSession.sharedInstance().currentRoute
        let outputs = route.outputs

        isExternalAudioRouteActive = outputs.contains { output in
            switch output.portType {
            case .builtInSpeaker, .builtInReceiver:
                return false
            default:
                return true
            }
        }
        #endif
    }
}
