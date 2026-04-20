//
//  MusicSearchViewModel.swift
//  XMusic
//
//  Created by Codex on 2026/3/20.
//

import Combine
import Foundation

@MainActor
final class MusicSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var selectedKind: SearchResultKind = .song
    @Published var selectedSource: SearchPlatformSource = .all
    @Published private(set) var searchHistory: [String] = []
    @Published private(set) var results: [SearchSong] = []
    @Published private(set) var albumResults: [SearchAlbum] = []
    @Published private(set) var debugItems: [SearchDebugItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?

    private let service = MusicSearchService()
    private let albumSearchEntry = AlbumSearchEntry()
    private let historyKey = "XMusic.SearchHistory"
    private let maxHistoryCount = 12
    private var currentPage = 0
    private var maxPage = 0
    private var cache: [String: SearchResponseBundle] = [:]
    private var latestSearchToken = UUID()
    private var searchTask: Task<Void, Never>?
    private var lastAllowedSources: [SearchPlatformSource] = []

    init() {
        loadSearchHistory()
    }

    var canLoadMore: Bool {
        ((!results.isEmpty) || (!albumResults.isEmpty)) && currentPage < maxPage && !isLoading && !isLoadingMore
    }

    func submitSearch() {
        reload(allowedSources: lastAllowedSources)
    }

    func scheduleSearch(allowedSources: [SearchPlatformSource]) {
        lastAllowedSources = allowedSources
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            reset()
            return
        }

        let token = UUID()
        latestSearchToken = token

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await search(isReset: true, recordHistory: false, allowedSources: allowedSources, token: token)
        }
    }

    func reload(allowedSources: [SearchPlatformSource]) {
        lastAllowedSources = allowedSources
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            reset()
            return
        }

        let token = UUID()
        latestSearchToken = token
        Task {
            await search(isReset: true, recordHistory: true, allowedSources: allowedSources, token: token)
        }
    }

    func loadMore(allowedSources: [SearchPlatformSource]) {
        guard canLoadMore else { return }
        let token = latestSearchToken
        Task {
            await search(isReset: false, recordHistory: false, allowedSources: allowedSources, token: token)
        }
    }

    func startSearch(
        query: String,
        source: SearchPlatformSource? = nil,
        allowedSources: [SearchPlatformSource]
    ) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.query = trimmed
        if let source {
            selectedSource = source
        }
        reload(allowedSources: allowedSources)
    }

    func clearSearchHistory() {
        searchHistory = []
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    func removeSearchHistory(_ keyword: String) {
        let next = searchHistory.filter { $0 != keyword }
        searchHistory = next
        UserDefaults.standard.set(next, forKey: historyKey)
    }

    func reset() {
        results = []
        albumResults = []
        debugItems = []
        currentPage = 0
        maxPage = 0
        errorMessage = nil
        isLoading = false
        isLoadingMore = false
    }

    private func search(isReset: Bool, recordHistory: Bool, allowedSources: [SearchPlatformSource], token: UUID) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            reset()
            return
        }

        if isReset && recordHistory {
            recordSearchHistory(trimmed)
        }

        errorMessage = nil
        if isReset {
            isLoading = true
            currentPage = 0
            maxPage = 0
        } else {
            isLoadingMore = true
        }

        let page = isReset ? 1 : currentPage + 1
        let availableSources = allowedSources.isEmpty ? SearchPlatformSource.builtIn : allowedSources
        let cacheKey = makeCacheKey(
            query: trimmed,
            page: page,
            kind: selectedKind,
            source: selectedSource,
            allowedSources: availableSources
        )

        defer {
            isLoading = false
            isLoadingMore = false
        }

        do {
            let responseBundle: SearchResponseBundle
            if let cached = cache[cacheKey] {
                responseBundle = cached
            } else {
                switch selectedKind {
                case .song:
                    responseBundle = try await service.search(
                        query: trimmed,
                        page: page,
                        kind: .song,
                        source: selectedSource,
                        allowedSources: availableSources
                    )
                case .album:
                    responseBundle = try await albumSearchEntry.search(
                        query: trimmed,
                        page: page,
                        source: selectedSource,
                        allowedSources: availableSources
                    )
                }
                cache[cacheKey] = responseBundle
            }

            guard token == latestSearchToken else { return }

            currentPage = page
            maxPage = responseBundle.payload.maxPage
            switch responseBundle.payload {
            case let .songs(result):
                results = isReset ? result.list : results + result.list
                if isReset {
                    albumResults = []
                }
            case let .albums(result):
                albumResults = isReset ? result.list : albumResults + result.list
                if isReset {
                    results = []
                }
            }
            debugItems = responseBundle.debugItems
        } catch {
            guard token == latestSearchToken else { return }
            errorMessage = error.localizedDescription
            if isReset {
                results = []
                albumResults = []
            }
            debugItems = []
        }
    }

    private func makeCacheKey(
        query: String,
        page: Int,
        kind: SearchResultKind = .song,
        source: SearchPlatformSource,
        allowedSources: [SearchPlatformSource]
    ) -> String {
        let sourceList = allowedSources.map(\.rawValue).sorted().joined(separator: ",")
        return "\(kind.rawValue)__\(source.rawValue)__\(page)__\(query)__\(sourceList)"
    }

    private func loadSearchHistory() {
        let items = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
        searchHistory = items
    }

    private func recordSearchHistory(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var nextHistory = searchHistory.filter { $0.localizedCaseInsensitiveCompare(trimmed) != .orderedSame }
        nextHistory.insert(trimmed, at: 0)
        if nextHistory.count > maxHistoryCount {
            nextHistory = Array(nextHistory.prefix(maxHistoryCount))
        }

        searchHistory = nextHistory
        UserDefaults.standard.set(nextHistory, forKey: historyKey)
    }
}
