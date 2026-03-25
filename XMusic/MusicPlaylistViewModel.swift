//
//  MusicPlaylistViewModel.swift
//  XMusic
//
//  Created by Codex on 2026/3/23.
//

import Combine
import Foundation

@MainActor
final class MusicPlaylistViewModel: ObservableObject {
    @Published private(set) var supportedSources: [SearchPlatformSource] = []
    @Published var selectedSource: SearchPlatformSource?
    @Published var selectedSort: PlaylistSortOption = .recommended
    @Published private(set) var playlists: [Playlist] = []
    @Published var selectedPlaylistKey: String?
    @Published private(set) var isLoadingList = false
    @Published private(set) var isLoadingDetail = false
    @Published var errorMessage: String?

    private let service = MusicPlaylistService()
    private var listTask: Task<Void, Never>?
    private var detailTasks: [String: Task<Playlist, Error>] = [:]
    private var listToken = UUID()

    var availableSorts: [PlaylistSortOption] {
        guard let selectedSource else { return [] }
        return service.supportedSorts(for: selectedSource)
    }

    var selectedPlaylist: Playlist? {
        playlists.first(where: { $0.stableKey == selectedPlaylistKey }) ?? playlists.first
    }

    func configure(with activeSource: ImportedMusicSource?) {
        let nextSources = activeSource?.capabilities
            .compactMap { SearchPlatformSource(rawValue: $0.source) }
            .removingDuplicates() ?? []

        supportedSources = nextSources

        guard !nextSources.isEmpty else {
            selectedSource = nil
            playlists = []
            selectedPlaylistKey = nil
            errorMessage = nil
            isLoadingList = false
            isLoadingDetail = false
            listTask?.cancel()
            cancelDetailTasks()
            return
        }

        if !nextSources.contains(where: { $0 == selectedSource }) {
            selectedSource = nextSources.first
        }

        if !availableSorts.contains(selectedSort), let firstSort = availableSorts.first {
            selectedSort = firstSort
        }
    }

    func reload() {
        guard let selectedSource else {
            playlists = []
            selectedPlaylistKey = nil
            errorMessage = nil
            return
        }

        listTask?.cancel()
        cancelDetailTasks()
        isLoadingList = true
        isLoadingDetail = false
        errorMessage = nil

        let token = UUID()
        listToken = token

        listTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await service.fetchPlaylists(source: selectedSource, sort: selectedSort)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard token == self.listToken else { return }
                    let previousSelection = self.selectedPlaylistKey
                    self.playlists = result
                    if let previousSelection,
                       result.contains(where: { $0.stableKey == previousSelection }) {
                        self.selectedPlaylistKey = previousSelection
                    } else {
                        self.selectedPlaylistKey = result.first?.stableKey
                    }
                    self.isLoadingList = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard token == self.listToken else { return }
                    self.playlists = []
                    self.selectedPlaylistKey = nil
                    self.isLoadingList = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func selectPlaylist(with key: String) {
        selectedPlaylistKey = key
        Task {
            await ensureDetailLoaded(for: key)
        }
    }

    func ensureDetailLoaded(for key: String) async {
        guard let playlist = playlists.first(where: { $0.stableKey == key }) else { return }
        guard playlist.tracks.isEmpty else { return }

        if let existingTask = detailTasks[key] {
            do {
                let detail = try await existingTask.value
                applyLoadedDetail(detail, for: key)
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }
            return
        }

        isLoadingDetail = true
        errorMessage = nil

        let task = Task<Playlist, Error>(priority: .userInitiated) { [service] in
            try await service.fetchPlaylistDetail(for: playlist)
        }

        detailTasks[key] = task

        defer {
            detailTasks[key] = nil
            isLoadingDetail = !detailTasks.isEmpty
        }

        do {
            let detail = try await task.value
            applyLoadedDetail(detail, for: key)
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func applyLoadedDetail(_ detail: Playlist, for key: String) {
        if let index = playlists.firstIndex(where: { $0.stableKey == key }) {
            playlists[index] = detail
        }
    }

    private func cancelDetailTasks() {
        detailTasks.values.forEach { $0.cancel() }
        detailTasks.removeAll()
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
