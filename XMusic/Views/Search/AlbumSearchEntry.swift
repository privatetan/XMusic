//
//  AlbumSearchEntry.swift
//  XMusic
//
//  Created by Codex on 2026/4/20.
//

import Foundation

struct AlbumSearchEntry {
    private let musicSearchService = MusicSearchService()

    func search(
        query: String,
        page: Int,
        source: SearchPlatformSource,
        allowedSources: [SearchPlatformSource]
    ) async throws -> SearchResponseBundle {
        try await musicSearchService.search(
            query: query,
            page: page,
            kind: .album,
            source: source,
            allowedSources: allowedSources
        )
    }

    func albumSongs(for album: SearchAlbum) async throws -> [SearchSong] {
        try await musicSearchService.albumSongs(for: album)
    }
}
