//
//  MusicSourceLibrary.swift
//  XMusic
//
//  Created by Codex on 2026/3/20.
//

import Combine
import CryptoKit
import Foundation

private struct CachedMusicURLResolution {
    let url: URL
    let createdAt: Date
}

private struct MediaCacheEntry: Codable {
    let originalURL: String
    let fileName: String
    let createdAt: Date
    var lastAccessedAt: Date
    var fileSize: Int64
}

@MainActor
final class MusicSourceLibrary: ObservableObject {
    @Published private(set) var sources: [ImportedMusicSource] = []
    @Published var activeSourceID: String?
    @Published private(set) var latestPlaybackDebugInfo: PlaybackDebugInfo?
    @Published var enableAutomaticSourceFallback = false
    @Published private(set) var mediaCacheSummary: MediaCacheSummary = .empty

    private let storageURL: URL
    private let mediaCacheDirectoryURL: URL
    private let mediaCacheIndexURL: URL
    private let runtime = MusicSourceRuntimeService()
    private let searchService = MusicSearchService()
    private let musicURLCacheTTL: TimeInterval = 20 * 60
    private var resolvedMusicURLCache: [String: CachedMusicURLResolution] = [:]
    private var lyricCache: [String: MusicSourceLyricResult] = [:]
    private var pictureCache: [String: URL] = [:]
    private var mediaCacheIndex: [String: MediaCacheEntry] = [:]

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())

        storageURL = baseURL
            .appendingPathComponent("XMusic", isDirectory: true)
            .appendingPathComponent("music_sources.json", isDirectory: false)
        mediaCacheDirectoryURL = baseURL
            .appendingPathComponent("XMusic", isDirectory: true)
            .appendingPathComponent("media-cache", isDirectory: true)
        mediaCacheIndexURL = baseURL
            .appendingPathComponent("XMusic", isDirectory: true)
            .appendingPathComponent("media_cache_index.json", isDirectory: false)

        load()
        loadMediaCacheIndex()
    }

    var activeSource: ImportedMusicSource? {
        guard let activeSourceID else { return nil }
        return sources.first { $0.id == activeSourceID }
    }

    func importText(_ script: String, fileName: String? = nil) throws {
        let source = try MusicSourceParser.importSource(script: script, fileName: fileName)
        sources.insert(source, at: 0)
        invalidateCaches(for: source.id)

        if activeSourceID == nil {
            activeSourceID = source.id
        }

        try persist()
    }

    func importFile(from url: URL) throws {
        let script = try MusicSourceParser.readScript(from: url)
        try importText(script, fileName: url.lastPathComponent)
    }

    func importInput(_ input: String) async throws {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MusicSourceParseError.invalidSourceFile
        }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme) {
            try await importRemoteSource(from: url)
            return
        }

        try importText(input)
    }

    func importRemoteSource(from url: URL) async throws {
        var lastError: Error?

        for candidate in candidateRemoteURLs(for: url) {
            do {
                let (data, response) = try await fetchRemoteData(from: candidate)
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    throw URLError(.badServerResponse)
                }

                let script = try MusicSourceParser.readScript(from: data)
                try importText(script, fileName: candidate.lastPathComponent)
                return
            } catch {
                lastError = error
            }
        }

        throw lastError ?? URLError(.badServerResponse)
    }

    private func candidateRemoteURLs(for url: URL) -> [URL] {
        var urls: [URL] = [url]

        guard let host = url.host?.lowercased() else { return urls }

        if host == "raw.githubusercontent.com" {
            let components = url.pathComponents.filter { $0 != "/" }
            if components.count >= 4 {
                let owner = components[0]
                let repo = components[1]
                let ref = components[2]
                let path = components.dropFirst(3).joined(separator: "/")
                urls.append(contentsOf: jsDelivrMirrors(owner: owner, repo: repo, ref: ref, path: path))
            }
        } else if host == "github.com" {
            let components = url.pathComponents.filter { $0 != "/" }
            if components.count >= 5, components[2] == "blob" {
                let owner = components[0]
                let repo = components[1]
                let ref = components[3]
                let path = components.dropFirst(4).joined(separator: "/")

                if let rawURL = URL(string: "https://raw.githubusercontent.com/\(owner)/\(repo)/\(ref)/\(path)") {
                    urls.append(rawURL)
                }
                urls.append(contentsOf: jsDelivrMirrors(owner: owner, repo: repo, ref: ref, path: path))
            }
        }

        return Array(NSOrderedSet(array: urls)) as? [URL] ?? urls
    }

    private func jsDelivrMirrors(owner: String, repo: String, ref: String, path: String) -> [URL] {
        [
            "https://cdn.jsdelivr.net/gh/\(owner)/\(repo)@\(ref)/\(path)",
            "https://fastly.jsdelivr.net/gh/\(owner)/\(repo)@\(ref)/\(path)",
            "https://gcore.jsdelivr.net/gh/\(owner)/\(repo)@\(ref)/\(path)",
        ]
        .compactMap(URL.init(string:))
    }

    private func fetchRemoteData(from url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/javascript,text/plain,*/*", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
            forHTTPHeaderField: "User-Agent"
        )

        return try await URLSession.shared.data(for: request)
    }

    func reparse(_ source: ImportedMusicSource) throws {
        guard let index = sources.firstIndex(where: { $0.id == source.id }) else { return }

        let updated = try MusicSourceParser.importSource(
            script: source.script,
            fileName: source.originalFileName,
            existingID: source.id,
            importedAt: source.importedAt
        )
        sources[index] = updated
        invalidateCaches(for: source.id)
        try persist()
    }

    func remove(_ source: ImportedMusicSource) throws {
        sources.removeAll { $0.id == source.id }
        invalidateCaches(for: source.id)

        if activeSourceID == source.id {
            activeSourceID = sources.first?.id
        }

        try persist()
    }

    func activate(_ source: ImportedMusicSource) throws {
        activeSourceID = source.id
        try persist()
    }

    func runtimeCapabilities(for source: ImportedMusicSource) async throws -> [MusicSourceCapability] {
        try await runtime.runtimeCapabilities(for: source)
    }

    func inspectPlaybackPayload(for song: SearchSong, with source: ImportedMusicSource) -> PlaybackDebugInfo {
        let sourceName = song.source.rawValue
        let requestedQuality = preferredQuality(
            requested: song.preferredQuality,
            available: song.qualities,
            source: source,
            platformSource: sourceName
        )
        let legacyObject = try? normalizedLegacyObject(
            with: source,
            platformSource: sourceName,
            legacySongInfoJSON: song.legacyInfoJSON,
            quality: requestedQuality
        )

        let debugInfo = PlaybackDebugInfo(
            originalURL: "",
            preparedURL: "",
            usedLocalCache: false,
            localPath: nil,
            fileExists: false,
            requestedSource: sourceName,
            resolvedSource: sourceName,
            requestedQuality: requestedQuality,
            resolvedQuality: requestedQuality,
            resolutionStrategy: "请求前检查",
            resolutionNote: "下面这份 JSON 就是 XMusic 准备传给音源脚本的 songInfo。",
            usedResolverCache: false,
            attemptedSources: [sourceName],
            legacyInfoJSON: legacyObject.map(LxLegacySongInfo.prettyPrintedJSON(from:)) ?? song.legacyInfoJSON,
            fieldChecks: legacyObject.map { LxLegacySongInfo.fieldChecks(for: sourceName, legacyObject: $0) } ?? [],
            requestTrace: []
        )
        latestPlaybackDebugInfo = debugInfo
        return debugInfo
    }

    func resolvePlayback(
        for song: SearchSong,
        with source: ImportedMusicSource
    ) async throws -> PlaybackResolutionResult {
        let supportedPlatforms = supportedSearchPlatforms(for: source)
        let requestedSource = song.source.rawValue
        print(
            """
            [XMusic][SourceLibrary] resolvePlayback
            activeSource=\(source.name)
            requestedSource=\(requestedSource)
            supportedPlatforms=\(supportedPlatforms.map(\.rawValue).joined(separator: ","))
            title=\(song.title)
            """
        )
        let requestedQuality = preferredQuality(
            requested: song.preferredQuality,
            available: song.qualities,
            source: source,
            platformSource: requestedSource
        )
        var attemptedSources: [String] = []
        var directResolveError: Error?
        var lastFallbackError: Error?

        if supportedPlatforms.contains(song.source) {
            attemptedSources.append(requestedSource)
            let directQualityCandidates = qualityCandidates(
                requested: requestedQuality,
                available: song.qualities,
                source: source,
                platformSource: requestedSource
            )
            for quality in directQualityCandidates {
                let directLegacyObject = try? normalizedLegacyObject(
                    with: source,
                    platformSource: requestedSource,
                    legacySongInfoJSON: song.legacyInfoJSON,
                    quality: quality
                )
                await runtime.resetRequestTrace()
                latestPlaybackDebugInfo = PlaybackDebugInfo(
                    originalURL: "",
                    preparedURL: "",
                    usedLocalCache: false,
                    localPath: nil,
                    fileExists: false,
                    requestedSource: requestedSource,
                    resolvedSource: requestedSource,
                    requestedQuality: requestedQuality,
                    resolvedQuality: quality,
                    resolutionStrategy: quality == requestedQuality ? "直接解析" : "同平台降级解析",
                    resolutionNote: quality == requestedQuality ? "正在尝试当前平台解析。" : "正在尝试同平台降级到 \(quality)。",
                    usedResolverCache: false,
                    attemptedSources: attemptedSources,
                    legacyInfoJSON: directLegacyObject.map(LxLegacySongInfo.prettyPrintedJSON(from:)),
                    fieldChecks: directLegacyObject.map { LxLegacySongInfo.fieldChecks(for: requestedSource, legacyObject: $0) } ?? [],
                    requestTrace: []
                )
                do {
                    let resolved = try await resolveMusicURLWithCache(
                        with: source,
                        platformSource: requestedSource,
                        legacySongInfoJSON: song.legacyInfoJSON,
                        quality: quality
                    )
                    let strategy = quality == requestedQuality ? "直接解析" : "同平台降级解析"
                    let note = quality == requestedQuality ? nil : "原请求音质 \(requestedQuality) 失败，已自动降级到 \(quality)。"
                    let debugInfo = try await preparePlayableURLWithDebug(
                        from: resolved.url,
                        requestedSource: requestedSource,
                        resolvedSource: requestedSource,
                        requestedQuality: requestedQuality,
                        resolvedQuality: quality,
                        resolutionStrategy: strategy,
                        resolutionNote: note,
                        usedResolverCache: resolved.fromCache,
                        attemptedSources: attemptedSources,
                        legacyInfoJSON: directLegacyObject.map(LxLegacySongInfo.prettyPrintedJSON(from:)),
                        fieldChecks: directLegacyObject.map { LxLegacySongInfo.fieldChecks(for: requestedSource, legacyObject: $0) } ?? [],
                        requestTrace: await runtime.latestRequestTrace()
                    )
                    return PlaybackResolutionResult(
                        playableURL: URL(string: debugInfo.preparedURL) ?? resolved.url,
                        debugInfo: debugInfo
                    )
                } catch {
                    directResolveError = error
                    if let current = latestPlaybackDebugInfo {
                        latestPlaybackDebugInfo = PlaybackDebugInfo(
                            originalURL: current.originalURL,
                            preparedURL: current.preparedURL,
                            usedLocalCache: current.usedLocalCache,
                            localPath: current.localPath,
                            fileExists: current.fileExists,
                            requestedSource: current.requestedSource,
                            resolvedSource: current.resolvedSource,
                            requestedQuality: current.requestedQuality,
                            resolvedQuality: current.resolvedQuality,
                            resolutionStrategy: current.resolutionStrategy,
                            resolutionNote: "本次尝试失败：\(error.localizedDescription)",
                            usedResolverCache: current.usedResolverCache,
                            attemptedSources: current.attemptedSources,
                            legacyInfoJSON: current.legacyInfoJSON,
                            fieldChecks: current.fieldChecks,
                            requestTrace: await runtime.latestRequestTrace()
                        )
                    }
                }
            }
        } else {
            directResolveError = NSError(
                domain: "XMusic.PlaybackResolution",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "当前音源不支持 \(song.source.title) 的直连解析。"]
            )
        }

        let fallbackPlatforms = supportedPlatforms.filter { $0 != song.source }
        guard enableAutomaticSourceFallback else {
            throw directResolveError ?? NSError(
                domain: "XMusic.PlaybackResolution",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "当前已禁用自动换源，原平台解析失败后不再继续尝试其他平台。"]
            )
        }
        guard !fallbackPlatforms.isEmpty else {
            throw directResolveError ?? NSError(
                domain: "XMusic.PlaybackResolution",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "当前音源没有可用的回退平台。"]
            )
        }

        let fallbackCandidates = try await searchService.findFallbackCandidates(
            for: song,
            allowedSources: fallbackPlatforms
        )
        guard !fallbackCandidates.isEmpty else {
            throw NSError(
                domain: "XMusic.PlaybackResolution",
                code: 3,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        """
                        直连解析失败：\(directResolveError?.localizedDescription ?? "未知错误")
                        没找到可自动换源的候选歌曲。
                        """
                ]
            )
        }

        for candidate in fallbackCandidates {
            let resolvedSource = candidate.source.rawValue
            attemptedSources.append(resolvedSource)
            let fallbackQualities = qualityCandidates(
                requested: requestedQuality,
                available: candidate.qualities,
                source: source,
                platformSource: resolvedSource
            )

            for quality in fallbackQualities {
                let fallbackLegacyObject = try? normalizedLegacyObject(
                    with: source,
                    platformSource: resolvedSource,
                    legacySongInfoJSON: candidate.legacyInfoJSON,
                    quality: quality
                )
                await runtime.resetRequestTrace()
                latestPlaybackDebugInfo = PlaybackDebugInfo(
                    originalURL: "",
                    preparedURL: "",
                    usedLocalCache: false,
                    localPath: nil,
                    fileExists: false,
                    requestedSource: requestedSource,
                    resolvedSource: resolvedSource,
                    requestedQuality: requestedQuality,
                    resolvedQuality: quality,
                    resolutionStrategy: "自动换源",
                    resolutionNote: fallbackNote(
                        originalSong: song,
                        fallbackSong: candidate,
                        requestedQuality: requestedQuality,
                        resolvedQuality: quality
                    ),
                    usedResolverCache: false,
                    attemptedSources: attemptedSources,
                    legacyInfoJSON: fallbackLegacyObject.map(LxLegacySongInfo.prettyPrintedJSON(from:)),
                    fieldChecks: fallbackLegacyObject.map { LxLegacySongInfo.fieldChecks(for: resolvedSource, legacyObject: $0) } ?? [],
                    requestTrace: []
                )
                do {
                    let resolved = try await resolveMusicURLWithCache(
                        with: source,
                        platformSource: resolvedSource,
                        legacySongInfoJSON: candidate.legacyInfoJSON,
                        quality: quality
                    )
                    let note = fallbackNote(
                        originalSong: song,
                        fallbackSong: candidate,
                        requestedQuality: requestedQuality,
                        resolvedQuality: quality
                    )
                    let debugInfo = try await preparePlayableURLWithDebug(
                        from: resolved.url,
                        requestedSource: requestedSource,
                        resolvedSource: resolvedSource,
                        requestedQuality: requestedQuality,
                        resolvedQuality: quality,
                        resolutionStrategy: "自动换源",
                        resolutionNote: note,
                        usedResolverCache: resolved.fromCache,
                        attemptedSources: attemptedSources,
                        legacyInfoJSON: fallbackLegacyObject.map(LxLegacySongInfo.prettyPrintedJSON(from:)),
                        fieldChecks: fallbackLegacyObject.map { LxLegacySongInfo.fieldChecks(for: resolvedSource, legacyObject: $0) } ?? [],
                        requestTrace: await runtime.latestRequestTrace()
                    )
                    return PlaybackResolutionResult(
                        playableURL: URL(string: debugInfo.preparedURL) ?? resolved.url,
                        debugInfo: debugInfo
                    )
                } catch {
                    lastFallbackError = error
                    if let current = latestPlaybackDebugInfo {
                        latestPlaybackDebugInfo = PlaybackDebugInfo(
                            originalURL: current.originalURL,
                            preparedURL: current.preparedURL,
                            usedLocalCache: current.usedLocalCache,
                            localPath: current.localPath,
                            fileExists: current.fileExists,
                            requestedSource: current.requestedSource,
                            resolvedSource: current.resolvedSource,
                            requestedQuality: current.requestedQuality,
                            resolvedQuality: current.resolvedQuality,
                            resolutionStrategy: current.resolutionStrategy,
                            resolutionNote: "本次尝试失败：\(error.localizedDescription)",
                            usedResolverCache: current.usedResolverCache,
                            attemptedSources: current.attemptedSources,
                            legacyInfoJSON: current.legacyInfoJSON,
                            fieldChecks: current.fieldChecks,
                            requestTrace: await runtime.latestRequestTrace()
                        )
                    }
                }
            }
        }

        throw NSError(
            domain: "XMusic.PlaybackResolution",
            code: 4,
            userInfo: [
                NSLocalizedDescriptionKey:
                    """
                    直连解析失败：\(directResolveError?.localizedDescription ?? "未知错误")
                    已尝试自动换源：\(attemptedSources.joined(separator: " -> "))
                    最后一次换源失败：\(lastFallbackError?.localizedDescription ?? "未知错误")
                    但仍未拿到可播放地址。
                    """
            ]
        )
    }

    func resolveMusicURL(
        with source: ImportedMusicSource,
        platformSource: String,
        legacySongInfoJSON: String,
        quality: String
    ) async throws -> URL {
        try await resolveMusicURLWithCache(
            with: source,
            platformSource: platformSource,
            legacySongInfoJSON: legacySongInfoJSON,
            quality: quality
        ).url
    }

    func preparePlayableURL(from remoteURL: URL) async throws -> URL {
        guard !remoteURL.isFileURL else { return remoteURL }
        guard let scheme = remoteURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else { return remoteURL }

        try FileManager.default.createDirectory(
            at: mediaCacheDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let fileExtension = remoteURL.pathExtension.isEmpty ? "audio" : remoteURL.pathExtension
        let fileName = "\(sha1(remoteURL.absoluteString)).\(fileExtension)"
        let destinationURL = mediaCacheDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            touchMediaCacheEntry(for: remoteURL, localURL: destinationURL)
            return destinationURL
        }

        var lastError: Error?
        for candidateURL in playableURLCandidates(for: remoteURL) {
            do {
                try await downloadPlayableMedia(from: candidateURL, to: destinationURL)
                touchMediaCacheEntry(for: remoteURL, localURL: destinationURL)
                return destinationURL
            } catch {
                lastError = error
            }
        }

        throw lastError ?? URLError(.badServerResponse)
    }

    func preparePlayableURLWithDebug(from remoteURL: URL) async throws -> PlaybackDebugInfo {
        try await preparePlayableURLWithDebug(
            from: remoteURL,
            requestedSource: nil,
            resolvedSource: nil,
            requestedQuality: nil,
            resolvedQuality: nil,
            resolutionStrategy: nil,
            resolutionNote: nil,
            usedResolverCache: false,
            attemptedSources: [],
            legacyInfoJSON: nil,
            fieldChecks: [],
            requestTrace: []
        )
    }

    func preparePlayableURLWithDebug(
        from remoteURL: URL,
        requestedSource: String?,
        resolvedSource: String?,
        requestedQuality: String?,
        resolvedQuality: String?,
        resolutionStrategy: String?,
        resolutionNote: String?,
        usedResolverCache: Bool,
        attemptedSources: [String],
        legacyInfoJSON: String?,
        fieldChecks: [PlaybackFieldCheck],
        requestTrace: [String]
    ) async throws -> PlaybackDebugInfo {
        let preparedURL = try await preparePlayableURL(from: remoteURL)
        let isLocal = preparedURL.isFileURL
        let localPath = isLocal ? preparedURL.path : nil
        let fileExists = localPath.map(FileManager.default.fileExists(atPath:)) ?? false

        return PlaybackDebugInfo(
            originalURL: remoteURL.absoluteString,
            preparedURL: preparedURL.absoluteString,
            usedLocalCache: isLocal,
            localPath: localPath,
            fileExists: fileExists,
            requestedSource: requestedSource,
            resolvedSource: resolvedSource,
            requestedQuality: requestedQuality,
            resolvedQuality: resolvedQuality,
            resolutionStrategy: resolutionStrategy,
            resolutionNote: resolutionNote,
            usedResolverCache: usedResolverCache,
            attemptedSources: attemptedSources,
            legacyInfoJSON: legacyInfoJSON,
            fieldChecks: fieldChecks,
            requestTrace: requestTrace
        )
    }

    func resolveLyric(
        with source: ImportedMusicSource,
        platformSource: String,
        legacySongInfoJSON: String
    ) async throws -> MusicSourceLyricResult {
        let cacheKey = makeResolutionCacheKey(
            sourceID: source.id,
            action: "lyric",
            platformSource: platformSource,
            quality: nil,
            payload: legacySongInfoJSON
        )
        if let cached = lyricCache[cacheKey] {
            return cached
        }

        let songInfo = try LxLegacySongInfo.parseLegacyJSON(legacySongInfoJSON, sourceName: platformSource)
        let result = try await runtime.resolveLyric(
            with: source,
            platformSource: platformSource,
            legacySongInfo: songInfo
        )
        lyricCache[cacheKey] = result
        return result
    }

    func resolvePicture(
        with source: ImportedMusicSource,
        platformSource: String,
        legacySongInfoJSON: String
    ) async throws -> URL {
        let cacheKey = makeResolutionCacheKey(
            sourceID: source.id,
            action: "pic",
            platformSource: platformSource,
            quality: nil,
            payload: legacySongInfoJSON
        )
        if let cached = pictureCache[cacheKey] {
            return cached
        }

        let songInfo = try LxLegacySongInfo.parseLegacyJSON(legacySongInfoJSON, sourceName: platformSource)
        let result = try await runtime.resolvePicture(
            with: source,
            platformSource: platformSource,
            legacySongInfo: songInfo
        )
        pictureCache[cacheKey] = result
        return result
    }

    private func resolveMusicURLWithCache(
        with source: ImportedMusicSource,
        platformSource: String,
        legacySongInfoJSON: String,
        quality: String
    ) async throws -> (url: URL, fromCache: Bool) {
        let legacyObject = try normalizedLegacyObject(
            with: source,
            platformSource: platformSource,
            legacySongInfoJSON: legacySongInfoJSON,
            quality: quality
        )
        let normalizedPayload = LxLegacySongInfo.prettyPrintedJSON(from: legacyObject)
        let cacheKey = makeResolutionCacheKey(
            sourceID: source.id,
            action: "musicUrl",
            platformSource: platformSource,
            quality: quality,
            payload: normalizedPayload
        )

        if let cached = resolvedMusicURLCache[cacheKey] {
            if Date().timeIntervalSince(cached.createdAt) < musicURLCacheTTL {
                return (cached.url, true)
            }
            resolvedMusicURLCache.removeValue(forKey: cacheKey)
        }

        let url = try await runtime.resolveMusicURL(
            with: source,
            platformSource: platformSource,
            legacySongInfo: legacyObject,
            quality: quality
        )
        resolvedMusicURLCache[cacheKey] = CachedMusicURLResolution(url: url, createdAt: .now)
        return (url, false)
    }

    private func normalizedLegacyObject(
        with source: ImportedMusicSource,
        platformSource: String,
        legacySongInfoJSON: String,
        quality: String
    ) throws -> [String: Any] {
        var legacyObject = try LxLegacySongInfo.parseLegacyJSON(legacySongInfoJSON, sourceName: platformSource)
        rewriteKugouHashIfNeeded(source: source, legacyObject: &legacyObject, quality: quality)
        return legacyObject
    }

    private func supportedSearchPlatforms(for source: ImportedMusicSource) -> [SearchPlatformSource] {
        let sourceNames = Set(source.capabilities.map(\.source))
        return SearchPlatformSource.builtIn.filter { sourceNames.contains($0.rawValue) }
    }

    private func preferredQuality(
        requested: String,
        available: [String],
        source: ImportedMusicSource,
        platformSource: String
    ) -> String {
        if shouldForceKugou128k(source: source, platformSource: platformSource),
           available.contains("128k") {
            return "128k"
        }
        let priority = ["flac24bit", "flac", "320k", "128k"]
        let normalizedRequested = priority.contains(requested) ? requested : "128k"
        guard !available.isEmpty else { return normalizedRequested }
        if available.contains(normalizedRequested) { return normalizedRequested }

        let startIndex = priority.firstIndex(of: normalizedRequested) ?? (priority.count - 1)
        for quality in priority[startIndex...] where available.contains(quality) {
            return quality
        }
        for quality in priority where available.contains(quality) {
            return quality
        }
        return available.first ?? normalizedRequested
    }

    private func qualityCandidates(
        requested: String,
        available: [String],
        source: ImportedMusicSource,
        platformSource: String
    ) -> [String] {
        if shouldForceKugou128k(source: source, platformSource: platformSource) {
            if available.contains("128k") {
                return ["128k"]
            }
            let fallback = preferredQuality(
                requested: requested,
                available: available,
                source: source,
                platformSource: platformSource
            )
            return [fallback]
        }
        let normalizedRequested = preferredQuality(
            requested: requested,
            available: available,
            source: source,
            platformSource: platformSource
        )
        let fallbackOrder = ["128k", "320k", "flac", "flac24bit"]
        var candidates: [String] = [normalizedRequested]
        if normalizedRequested != "128k" {
            candidates.append("128k")
        }
        candidates.append(contentsOf: fallbackOrder)

        var unique: [String] = []
        for quality in candidates where available.contains(quality) {
            if !unique.contains(quality) {
                unique.append(quality)
            }
        }
        return unique
    }

    private func shouldForceKugou128k(source: ImportedMusicSource, platformSource: String) -> Bool {
        _ = source
        return platformSource == "kg"
    }

    private func rewriteKugouHashIfNeeded(
        source: ImportedMusicSource,
        legacyObject: inout [String: Any],
        quality: String
    ) {
        guard legacyObject["source"] as? String == "kg" else { return }
        _ = source
        guard let qualityMap = legacyObject["_types"] as? [String: [String: Any]],
              let hash = qualityMap[quality]?["hash"] as? String,
              !hash.isEmpty else { return }
        legacyObject["hash"] = hash
    }

    private func fallbackNote(
        originalSong: SearchSong,
        fallbackSong: SearchSong,
        requestedQuality: String,
        resolvedQuality: String
    ) -> String {
        let qualityNote = requestedQuality == resolvedQuality ? "" : " 请求音质 \(requestedQuality) 已自动降级为 \(resolvedQuality)。"
        if originalSong.title == fallbackSong.title, originalSong.artist == fallbackSong.artist {
            return "原平台地址解析失败，已自动切到 \(fallbackSong.source.title) 的同名结果。\(qualityNote)"
        }
        return "原平台地址解析失败，已自动切到 \(fallbackSong.source.title) 候选：\(fallbackSong.title) - \(fallbackSong.artist)。\(qualityNote)"
    }

    private func makeResolutionCacheKey(
        sourceID: String,
        action: String,
        platformSource: String,
        quality: String?,
        payload: String
    ) -> String {
        let payloadHash = sha1(payload)
        return [sourceID, action, platformSource, quality ?? "-", payloadHash].joined(separator: "__")
    }

    private func invalidateCaches(for sourceID: String? = nil) {
        guard let sourceID else {
            resolvedMusicURLCache.removeAll()
            lyricCache.removeAll()
            pictureCache.removeAll()
            return
        }

        let prefix = sourceID + "__"
        resolvedMusicURLCache = Dictionary(uniqueKeysWithValues: resolvedMusicURLCache.filter { !$0.key.hasPrefix(prefix) })
        lyricCache = Dictionary(uniqueKeysWithValues: lyricCache.filter { !$0.key.hasPrefix(prefix) })
        pictureCache = Dictionary(uniqueKeysWithValues: pictureCache.filter { !$0.key.hasPrefix(prefix) })
    }

    private func load() {
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(MusicSourceSnapshot.self, from: data)
            sources = snapshot.sources.sorted { $0.importedAt > $1.importedAt }
            activeSourceID = snapshot.activeSourceID
        } catch {
            sources = []
            activeSourceID = nil
        }
    }

    func clearMediaCache() throws {
        if FileManager.default.fileExists(atPath: mediaCacheDirectoryURL.path) {
            try FileManager.default.removeItem(at: mediaCacheDirectoryURL)
        }
        if FileManager.default.fileExists(atPath: mediaCacheIndexURL.path) {
            try FileManager.default.removeItem(at: mediaCacheIndexURL)
        }
        mediaCacheIndex.removeAll()
        mediaCacheSummary = .empty
    }

    private func persist() throws {
        let directory = storageURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let snapshot = MusicSourceSnapshot(activeSourceID: activeSourceID, sources: sources)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: storageURL, options: .atomic)
    }

    private func loadMediaCacheIndex() {
        do {
            let data = try Data(contentsOf: mediaCacheIndexURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            mediaCacheIndex = try decoder.decode([String: MediaCacheEntry].self, from: data)
        } catch {
            mediaCacheIndex = [:]
        }
        refreshMediaCacheSummaryFromIndex()
    }

    private func persistMediaCacheIndex() throws {
        let directory = mediaCacheIndexURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(mediaCacheIndex)
        try data.write(to: mediaCacheIndexURL, options: .atomic)
    }

    private func touchMediaCacheEntry(for remoteURL: URL, localURL: URL) {
        let fileName = localURL.lastPathComponent
        let size = mediaFileSize(at: localURL)
        let key = remoteURL.absoluteString
        let existingCreatedAt = mediaCacheIndex[key]?.createdAt ?? .now
        mediaCacheIndex[key] = MediaCacheEntry(
            originalURL: key,
            fileName: fileName,
            createdAt: existingCreatedAt,
            lastAccessedAt: .now,
            fileSize: size
        )

        do {
            try persistMediaCacheIndex()
        } catch {
            #if DEBUG
            print("[cache] Failed to persist media cache index: \(error)")
            #endif
        }
        refreshMediaCacheSummaryFromIndex()
    }

    private func pruneMissingMediaCacheEntries() {
        mediaCacheIndex = mediaCacheIndex.reduce(into: [:]) { partialResult, item in
            let localURL = mediaCacheDirectoryURL.appendingPathComponent(item.value.fileName, isDirectory: false)
            guard FileManager.default.fileExists(atPath: localURL.path) else { return }

            var entry = item.value
            entry.fileSize = mediaFileSize(at: localURL)
            partialResult[item.key] = entry
        }

        do {
            try persistMediaCacheIndex()
        } catch {
            #if DEBUG
            print("[cache] Failed to reconcile media cache index: \(error)")
            #endif
        }
    }

    private func refreshMediaCacheSummary() {
        guard FileManager.default.fileExists(atPath: mediaCacheDirectoryURL.path) else {
            mediaCacheSummary = .empty
            return
        }

        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: mediaCacheDirectoryURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            mediaCacheSummary = .empty
            return
        }

        var fileCount = 0
        var totalBytes: Int64 = 0

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { continue }
            fileCount += 1
            totalBytes += Int64(values.fileSize ?? 0)
        }

        mediaCacheSummary = MediaCacheSummary(fileCount: fileCount, totalBytes: totalBytes)
    }

    private func refreshMediaCacheSummaryFromIndex() {
        let totalBytes = mediaCacheIndex.values.reduce(into: Int64(0)) { partialResult, entry in
            partialResult += max(entry.fileSize, 0)
        }
        mediaCacheSummary = MediaCacheSummary(fileCount: mediaCacheIndex.count, totalBytes: totalBytes)
    }

    private func mediaFileSize(at localURL: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: localURL.path)
        let size = attributes?[.size] as? NSNumber
        return size?.int64Value ?? 0
    }

    private func sha1(_ text: String) -> String {
        Insecure.SHA1.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func playableURLCandidates(for remoteURL: URL) -> [URL] {
        guard remoteURL.scheme?.lowercased() == "http",
              let host = remoteURL.host?.lowercased() else {
            return [remoteURL]
        }

        var candidates: [URL] = []
        if (host == "126.net" || host.hasSuffix(".126.net")),
           var components = URLComponents(url: remoteURL, resolvingAgainstBaseURL: false) {
            components.scheme = "https"
            if let httpsURL = components.url {
                candidates.append(httpsURL)
            }
        }
        candidates.append(remoteURL)
        return Array(NSOrderedSet(array: candidates)) as? [URL] ?? candidates
    }

    private func downloadPlayableMedia(from remoteURL: URL, to destinationURL: URL) async throws {
        #if os(macOS)
        do {
            try downloadViaCurl(from: remoteURL, to: destinationURL)
            return
        } catch {
            if remoteURL.scheme?.lowercased() == "http" {
                throw error
            }
            // Fall back to URLSession below when curl is unavailable for secure URLs.
        }
        #endif

        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 40
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)",
            forHTTPHeaderField: "User-Agent"
        )

        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
    }

    #if os(macOS)
    private func downloadViaCurl(from remoteURL: URL, to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = [
            "-L",
            "--fail",
            "--silent",
            "--show-error",
            "--compressed",
            "--connect-timeout",
            "15",
            "--max-time",
            "40",
            "--user-agent",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)",
            "--output",
            destinationURL.path,
            remoteURL.absoluteString,
        ]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            try? FileManager.default.removeItem(at: destinationURL)
            throw NSError(
                domain: "XMusic.CurlDownload",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: message ?? "curl download failed"]
            )
        }
    }
    #endif
}
