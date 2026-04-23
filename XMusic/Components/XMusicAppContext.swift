//
//  XMusicAppContext.swift
//  XMusic
//
//  Created by Codex on 2026/4/19.
//

import Foundation

@MainActor
final class XMusicAppContext {
    static let shared = XMusicAppContext()

    let player: MusicPlayerViewModel
    let sourceLibrary: MusicSourceLibrary
    let musicSearch: MusicSearchViewModel
    let library: MusicLibraryViewModel
    let playlistModel: MusicPlaylistViewModel
    let scrollState: AppScrollState

    private init() {
        player = MusicPlayerViewModel()
        sourceLibrary = MusicSourceLibrary()
        musicSearch = MusicSearchViewModel()
        library = MusicLibraryViewModel()
        playlistModel = MusicPlaylistViewModel()
        scrollState = AppScrollState()

        installSearchPlaybackResolver()
        installCachedPlaybackResolver()
    }

    func installSearchPlaybackResolver() {
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
    }

    func installCachedPlaybackResolver() {
        player.setCachedPlaybackResolver { [sourceLibrary] track in
            sourceLibrary.preferredPlaybackTrack(for: track)
        }
    }
}
