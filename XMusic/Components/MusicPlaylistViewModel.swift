//
//  MusicPlaylistViewModel.swift
//  XMusic
//
//  Created by Codex on 2026/3/23.
//

import Combine
import Foundation
import SwiftUI

struct CustomPlaylistDraft {
    var playlistID: String?
    var title = ""
    var coverImageData: Data?
    var summary = ""
    var description = ""
    var tagsText = ""
    var selectedTrackKeys: Set<String> = []
    var availableTracks: [Track] = []

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct StoredLibraryTrack: Codable, Identifiable {
    let id: String
    let track: StoredTrackRecord
    let addedAt: Date
}

private struct MusicLibraryStore {
    private let storageKey = "XMusic.SavedLibraryTracks"

    func load() -> [StoredLibraryTrack] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([StoredLibraryTrack].self, from: data) else {
            return []
        }
        return records.sorted { $0.addedAt > $1.addedAt }
    }

    func save(_ tracks: [StoredLibraryTrack]) {
        guard let data = try? JSONEncoder().encode(tracks) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

@MainActor
final class MusicLibraryViewModel: ObservableObject {
    @Published private(set) var savedTracks: [Track] = []

    private let store = MusicLibraryStore()
    private var storedTracks: [StoredLibraryTrack] = []

    init() {
        load()
    }

    func contains(_ track: Track) -> Bool {
        storedTracks.contains { $0.id == track.storageKey }
    }

    func contains(searchSong: SearchSong) -> Bool {
        contains(Track.searchResultTrack(from: searchSong))
    }

    func add(_ track: Track) {
        let record = StoredLibraryTrack(
            id: track.storageKey,
            track: StoredTrackRecord(track: track),
            addedAt: Date()
        )
        storedTracks.removeAll { $0.id == record.id }
        storedTracks.insert(record, at: 0)
        persist()
    }

    func add(searchSong: SearchSong) {
        add(Track.searchResultTrack(from: searchSong))
    }

    func remove(_ track: Track) {
        storedTracks.removeAll { $0.id == track.storageKey }
        persist()
    }

    private func load() {
        storedTracks = store.load().filter { $0.track.track.searchSong != nil }
        store.save(storedTracks)
        syncSavedTracks()
    }

    private func persist() {
        storedTracks = storedTracks.filter { $0.track.track.searchSong != nil }
        storedTracks.sort { $0.addedAt > $1.addedAt }
        store.save(storedTracks)
        syncSavedTracks()
    }

    private func syncSavedTracks() {
        savedTracks = storedTracks
            .map(\.track.track)
            .filter { $0.searchSong != nil }
    }
}

private struct StoredCustomPlaylist: Codable, Identifiable {
    let id: String
    let title: String
    let coverImageData: Data?
    let summary: String
    let description: String
    let categories: [String]
    let trackKeys: [String]
    let tracks: [StoredTrackRecord]?
    let createdAt: Date
    let updatedAt: Date
}

private struct CustomPlaylistStore {
    private let storageKey = "XMusic.CustomPlaylists"

    func load() -> [StoredCustomPlaylist] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([StoredCustomPlaylist].self, from: data) else {
            return []
        }
        return records.sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ playlists: [StoredCustomPlaylist]) {
        guard let data = try? JSONEncoder().encode(playlists) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

@MainActor
final class MusicPlaylistViewModel: ObservableObject {
    @Published private(set) var supportedSources: [SearchPlatformSource] = []
    @Published private(set) var customPlaylists: [Playlist] = []
    @Published private(set) var remotePlaylists: [Playlist] = []
    @Published private(set) var playlists: [Playlist] = []
    @Published var selectedSource: SearchPlatformSource?
    @Published var selectedSort: PlaylistSortOption = .recommended
    @Published var selectedPlaylistKey: String?
    @Published private(set) var isLoadingList = false
    @Published private(set) var isLoadingDetail = false
    @Published var errorMessage: String?

    private let service = MusicPlaylistService()
    private let customPlaylistStore = CustomPlaylistStore()
    private var storedCustomPlaylists: [StoredCustomPlaylist] = []
    private var listTask: Task<Void, Never>?
    private var detailTasks: [String: Task<Playlist, Error>] = [:]
    private var listToken = UUID()

    init() {
        loadCustomPlaylists()
    }

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
            remotePlaylists = []
            errorMessage = nil
            isLoadingList = false
            isLoadingDetail = false
            listTask?.cancel()
            cancelDetailTasks()
            rebuildPlaylistCollection()
            normalizeSelection()
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
            remotePlaylists = []
            errorMessage = nil
            isLoadingList = false
            rebuildPlaylistCollection()
            normalizeSelection()
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
                    self.remotePlaylists = result
                    self.rebuildPlaylistCollection()
                    self.restoreSelection(preferredKey: previousSelection)
                    self.isLoadingList = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard token == self.listToken else { return }
                    self.remotePlaylists = []
                    self.rebuildPlaylistCollection()
                    self.normalizeSelection()
                    self.isLoadingList = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func selectPlaylist(with key: String) {
        selectedPlaylistKey = key

        guard let playlist = playlists.first(where: { $0.stableKey == key }),
              !playlist.isCustomPlaylist else {
            return
        }

        Task {
            await ensureDetailLoaded(for: key)
        }
    }

    func ensureDetailLoaded(for key: String) async {
        guard let playlist = playlists.first(where: { $0.stableKey == key }) else { return }
        guard !playlist.isCustomPlaylist else { return }
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

    func draftForCustomPlaylist(_ playlist: Playlist?, libraryTracks: [Track] = []) -> CustomPlaylistDraft {
        guard let playlist,
              let customPlaylistID = playlist.customPlaylistID,
              let storedPlaylist = storedCustomPlaylists.first(where: { $0.id == customPlaylistID }) else {
            return CustomPlaylistDraft()
        }

        let editableTags = storedPlaylist.categories
            .filter { $0 != "自定义" }
            .joined(separator: "、")

        return CustomPlaylistDraft(
            playlistID: storedPlaylist.id,
            title: storedPlaylist.title,
            coverImageData: storedPlaylist.coverImageData,
            summary: storedPlaylist.summary,
            description: storedPlaylist.description,
            tagsText: editableTags,
            selectedTrackKeys: Set(playlist.tracks.map(\.storageKey)),
            availableTracks: trackSelectionPool(including: playlist.tracks, libraryTracks: libraryTracks)
        )
    }

    func draftForNewCustomPlaylist(
        prefilledTracks: [Track] = [],
        libraryTracks: [Track] = []
    ) -> CustomPlaylistDraft {
        let availableTracks = trackSelectionPool(including: prefilledTracks, libraryTracks: libraryTracks)
        return CustomPlaylistDraft(
            coverImageData: nil,
            selectedTrackKeys: Set(prefilledTracks.map(\.storageKey)),
            availableTracks: availableTracks
        )
    }

    func saveCustomPlaylist(_ draft: CustomPlaylistDraft) {
        let title = draft.trimmedTitle
        guard !title.isEmpty else { return }

        let trackCatalog = Dictionary(uniqueKeysWithValues: draft.availableTracks.map { ($0.storageKey, $0) })
        let selectedTracks = draft.availableTracks
            .filter { draft.selectedTrackKeys.contains($0.storageKey) }
        let resolvedTracks = selectedTracks.isEmpty
            ? draft.selectedTrackKeys.compactMap { trackCatalog[$0] }
            : selectedTracks
        let uniqueTracks = resolvedTracks.removingDuplicateTracks()
        let trackKeys = uniqueTracks.map(\.storageKey)
        let summary = resolvedSummary(
            manualSummary: draft.summary,
            description: draft.description,
            trackCount: uniqueTracks.count
        )
        let description = draft.description.nilIfBlank ?? summary
        let categories = parsedCategories(from: draft.tagsText)
        let now = Date()
        let playlistID = draft.playlistID ?? UUID().uuidString
        let createdAt = storedCustomPlaylists.first(where: { $0.id == playlistID })?.createdAt ?? now
        let record = StoredCustomPlaylist(
            id: playlistID,
            title: title,
            coverImageData: draft.coverImageData,
            summary: summary,
            description: description,
            categories: categories,
            trackKeys: trackKeys,
            tracks: uniqueTracks.map(StoredTrackRecord.init),
            createdAt: createdAt,
            updatedAt: now
        )

        if let index = storedCustomPlaylists.firstIndex(where: { $0.id == playlistID }) {
            storedCustomPlaylists[index] = record
        } else {
            storedCustomPlaylists.append(record)
        }

        persistCustomPlaylists()
        syncCustomPlaylists()
        selectedPlaylistKey = Playlist.customStableKey(for: playlistID)
    }

    func addTrack(_ track: Track, to playlist: Playlist) {
        guard let customPlaylistID = playlist.customPlaylistID,
              let index = storedCustomPlaylists.firstIndex(where: { $0.id == customPlaylistID }) else {
            return
        }

        var storedPlaylist = storedCustomPlaylists[index]
        var tracks = resolvedTracks(for: storedPlaylist)
        guard !tracks.contains(where: { $0.storageKey == track.storageKey }) else { return }

        tracks.append(track)
        let updatedSummary = resolvedSummary(
            manualSummary: storedPlaylist.summary,
            description: storedPlaylist.description,
            trackCount: tracks.count
        )
        storedPlaylist = StoredCustomPlaylist(
            id: storedPlaylist.id,
            title: storedPlaylist.title,
            coverImageData: storedPlaylist.coverImageData,
            summary: updatedSummary,
            description: storedPlaylist.description,
            categories: storedPlaylist.categories,
            trackKeys: tracks.map(\.storageKey),
            tracks: tracks.map(StoredTrackRecord.init),
            createdAt: storedPlaylist.createdAt,
            updatedAt: Date()
        )

        storedCustomPlaylists[index] = storedPlaylist
        persistCustomPlaylists()
        syncCustomPlaylists()
        selectedPlaylistKey = Playlist.customStableKey(for: customPlaylistID)
    }

    func removeTrack(_ track: Track, from playlist: Playlist) {
        guard let customPlaylistID = playlist.customPlaylistID,
              let index = storedCustomPlaylists.firstIndex(where: { $0.id == customPlaylistID }) else {
            return
        }

        var storedPlaylist = storedCustomPlaylists[index]
        let tracks = resolvedTracks(for: storedPlaylist)
            .filter { $0.storageKey != track.storageKey }
        guard tracks.count != resolvedTracks(for: storedPlaylist).count else { return }

        let updatedSummary = resolvedSummary(
            manualSummary: storedPlaylist.summary,
            description: storedPlaylist.description,
            trackCount: tracks.count
        )
        storedPlaylist = StoredCustomPlaylist(
            id: storedPlaylist.id,
            title: storedPlaylist.title,
            coverImageData: storedPlaylist.coverImageData,
            summary: updatedSummary,
            description: storedPlaylist.description,
            categories: storedPlaylist.categories,
            trackKeys: tracks.map(\.storageKey),
            tracks: tracks.map(StoredTrackRecord.init),
            createdAt: storedPlaylist.createdAt,
            updatedAt: Date()
        )

        storedCustomPlaylists[index] = storedPlaylist
        persistCustomPlaylists()
        syncCustomPlaylists()
        selectedPlaylistKey = Playlist.customStableKey(for: customPlaylistID)
    }

    func contains(_ track: Track, in playlist: Playlist) -> Bool {
        playlist.tracks.contains { $0.storageKey == track.storageKey }
    }

    func deleteCustomPlaylist(_ playlist: Playlist) {
        guard let customPlaylistID = playlist.customPlaylistID else { return }

        storedCustomPlaylists.removeAll { $0.id == customPlaylistID }
        persistCustomPlaylists()
        syncCustomPlaylists()

        if selectedPlaylistKey == playlist.stableKey {
            selectedPlaylistKey = playlists.first?.stableKey
        } else {
            normalizeSelection()
        }
    }

    private func applyLoadedDetail(_ detail: Playlist, for key: String) {
        if let index = remotePlaylists.firstIndex(where: { $0.stableKey == key }) {
            remotePlaylists[index] = detail
            rebuildPlaylistCollection()
        }
    }

    private func cancelDetailTasks() {
        detailTasks.values.forEach { $0.cancel() }
        detailTasks.removeAll()
    }

    private func loadCustomPlaylists() {
        storedCustomPlaylists = customPlaylistStore.load().map(sanitizedCustomPlaylist)
        customPlaylistStore.save(storedCustomPlaylists)
        syncCustomPlaylists()
        normalizeSelection()
    }

    private func syncCustomPlaylists() {
        storedCustomPlaylists.sort { $0.updatedAt > $1.updatedAt }
        customPlaylists = storedCustomPlaylists.map(makeCustomPlaylist)
        rebuildPlaylistCollection()
    }

    private func persistCustomPlaylists() {
        storedCustomPlaylists = storedCustomPlaylists.map(sanitizedCustomPlaylist)
        storedCustomPlaylists.sort { $0.updatedAt > $1.updatedAt }
        customPlaylistStore.save(storedCustomPlaylists)
    }

    private func rebuildPlaylistCollection() {
        playlists = customPlaylists + remotePlaylists
    }

    private func normalizeSelection() {
        if let selectedPlaylistKey,
           playlists.contains(where: { $0.stableKey == selectedPlaylistKey }) {
            return
        }
        selectedPlaylistKey = playlists.first?.stableKey
    }

    private func restoreSelection(preferredKey: String?) {
        if let preferredKey,
           playlists.contains(where: { $0.stableKey == preferredKey }) {
            selectedPlaylistKey = preferredKey
            return
        }
        normalizeSelection()
    }

    private func makeCustomPlaylist(from record: StoredCustomPlaylist) -> Playlist {
        let tracks = resolvedTracks(for: record)
        let artwork = customArtworkPalette(for: record, tracks: tracks)
        let summary = record.summary.nilIfBlank ?? resolvedSummary(
            manualSummary: nil,
            description: record.description,
            trackCount: tracks.count
        )

        return Playlist(
            source: nil,
            sourceIdentifier: Playlist.customStableKey(for: record.id),
            title: record.title,
            curator: "我的歌单",
            summary: summary,
            description: record.description.nilIfBlank ?? summary,
            categories: record.categories.isEmpty ? ["自定义"] : record.categories,
            tracks: tracks,
            artwork: artwork,
            customArtworkData: record.coverImageData,
            playCount: 0,
            followerCount: 0,
            updatedLabel: updatedLabel(for: record.updatedAt),
            updatedOrder: Int(record.updatedAt.timeIntervalSince1970)
        )
    }

    private func resolvedTracks(for record: StoredCustomPlaylist) -> [Track] {
        if let storedTracks = record.tracks, !storedTracks.isEmpty {
            return storedTracks
                .map(\.track)
                .filter { $0.searchSong != nil }
        }
        return []
    }

    private func trackSelectionPool(
        including extraTracks: [Track] = [],
        libraryTracks: [Track] = []
    ) -> [Track] {
        let customTracks = storedCustomPlaylists.flatMap(resolvedTracks(for:))
        return (extraTracks + libraryTracks + customTracks).removingDuplicateTracks()
    }

    private func sanitizedCustomPlaylist(_ record: StoredCustomPlaylist) -> StoredCustomPlaylist {
        let tracks = (record.tracks ?? [])
            .filter { $0.track.searchSong != nil }
        return StoredCustomPlaylist(
            id: record.id,
            title: record.title,
            coverImageData: record.coverImageData,
            summary: record.summary,
            description: record.description,
            categories: record.categories,
            trackKeys: tracks.map(\.id),
            tracks: tracks.isEmpty ? nil : tracks,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    private func customArtworkPalette(for record: StoredCustomPlaylist, tracks: [Track]) -> ArtworkPalette {
        if let firstTrack = tracks.first {
            return ArtworkPalette(
                colors: firstTrack.artwork.colors,
                glow: firstTrack.artwork.glow,
                symbol: tracks.count > 1 ? "music.note.list" : firstTrack.artwork.symbol,
                label: "Custom"
            )
        }

        let palettes: [ArtworkPalette] = [
            ArtworkPalette(
                colors: [Color(red: 0.96, green: 0.36, blue: 0.38), Color(red: 0.24, green: 0.12, blue: 0.30)],
                glow: Color(red: 1.00, green: 0.58, blue: 0.50),
                symbol: "music.note.list",
                label: "Custom"
            ),
            ArtworkPalette(
                colors: [Color(red: 0.16, green: 0.54, blue: 0.74), Color(red: 0.08, green: 0.13, blue: 0.25)],
                glow: Color(red: 0.56, green: 0.86, blue: 0.95),
                symbol: "music.quarternote.3",
                label: "Mix"
            ),
            ArtworkPalette(
                colors: [Color(red: 0.96, green: 0.64, blue: 0.28), Color(red: 0.55, green: 0.16, blue: 0.30)],
                glow: Color(red: 1.00, green: 0.78, blue: 0.45),
                symbol: "sparkles",
                label: "Mood"
            )
        ]
        let paletteSeed = record.id.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult + Int(scalar.value)
        }
        let paletteIndex = paletteSeed % palettes.count
        return palettes[paletteIndex]
    }

    private func updatedLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let minutes = max(Int(now.timeIntervalSince(date) / 60), 0)

        if minutes < 3 {
            return "刚刚更新"
        }
        if minutes < 60 {
            return "\(minutes) 分钟前更新"
        }
        if minutes < 60 * 8 {
            return "\(minutes / 60) 小时前更新"
        }
        if calendar.isDateInToday(date) {
            return "今天更新"
        }
        if calendar.isDateInYesterday(date) {
            return "昨天更新"
        }

        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days < 7 {
            return "\(days) 天前更新"
        }

        return date.formatted(.dateTime.month().day())
    }

    private func parsedCategories(from text: String) -> [String] {
        let tags = text
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "、", with: ",")
            .split(separator: ",")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .removingDuplicates()

        return tags.isEmpty ? ["自定义"] : ["自定义"] + tags
    }

    private func resolvedSummary(
        manualSummary: String?,
        description: String?,
        trackCount: Int
    ) -> String {
        if let manualSummary = manualSummary?.nilIfBlank {
            return manualSummary
        }
        if let description = description?.nilIfBlank {
            return description
        }
        if trackCount > 0 {
            return "共 \(trackCount) 首，按自己的节奏慢慢收着。"
        }
        return "先建一个名字，之后再把想听的歌慢慢放进来。"
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private extension Array where Element == Track {
    func removingDuplicateTracks() -> [Track] {
        var seen = Set<String>()
        return filter { track in
            seen.insert(track.storageKey).inserted
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
