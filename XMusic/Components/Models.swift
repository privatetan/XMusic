//
//  Models.swift
//  XMusic
//
//  Created by Codex on 2026/3/20.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum AppTab: String, CaseIterable, Identifiable {
    case browse
    case radio
    case settings
    case search

    var id: String { rawValue }

    static var mainNavigationTabs: [AppTab] {
        [.browse, .radio, .settings]
    }

    var title: String {
        switch self {
        case .browse:
            return "资料库"
        case .radio:
            return "歌单"
        case .settings:
            return "设置"
        case .search:
            return "搜索"
        }
    }

    var symbol: String {
        switch self {
        case .browse:
            return "house.fill"
        case .radio:
            return "music.note.list"
        case .settings:
            return "gearshape.fill"
        case .search:
            return "magnifyingglass"
        }
    }
}

struct ArtworkPalette {
    let colors: [Color]
    let glow: Color
    let symbol: String
    let label: String
}

struct Track: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let artist: String
    let album: String
    let blurb: String
    let genre: String
    let duration: TimeInterval
    var audioURL: URL?
    let artwork: ArtworkPalette
    var searchSong: SearchSong? = nil
    var sourceName: String? = nil

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }

    var catalogKey: String {
        [title, artist, album]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: "|")
    }

    var storageKey: String {
        if let searchSong {
            return "search:\(searchSong.id)"
        }
        if let sourceName = sourceName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sourceName.isEmpty {
            return "source:\(sourceName.lowercased())|\(catalogKey)"
        }
        return "catalog:\(catalogKey)"
    }

    static func searchResultTrack(
        from song: SearchSong,
        sourceName: String? = nil,
        resolvedURL: URL? = nil
    ) -> Track {
        Track(
            title: song.title,
            artist: song.artist,
            album: song.album,
            blurb: "搜索来源 \(song.source.title)，播放时按当前音源重新解析。",
            genre: song.source.title,
            duration: searchTrackDuration(from: song.durationText),
            audioURL: resolvedURL,
            artwork: song.source.searchArtworkPalette,
            searchSong: song,
            sourceName: sourceName
        )
    }

    private static func searchTrackDuration(from text: String) -> TimeInterval {
        let parts = text.split(separator: ":").compactMap { Double($0) }
        guard !parts.isEmpty else { return 240 }
        return parts.reversed().enumerated().reduce(into: 0) { partialResult, item in
            partialResult += item.element * pow(60, Double(item.offset))
        }
    }
}

enum PlaylistSortOption: String, CaseIterable, Identifiable {
    case recommended
    case hottest
    case latest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommended:
            return "推荐"
        case .hottest:
            return "最热"
        case .latest:
            return "最新"
        }
    }
}

struct Playlist: Identifiable {
    let id = UUID()
    let source: SearchPlatformSource?
    let sourceIdentifier: String?
    let title: String
    let curator: String
    let summary: String
    let description: String
    let categories: [String]
    let tracks: [Track]
    let artwork: ArtworkPalette
    let customArtworkData: Data?
    let remoteArtworkURL: URL?
    let playCount: Int
    let followerCount: Int
    let playCountDisplay: String?
    let followerCountDisplay: String?
    let declaredTrackCount: Int?
    let updatedLabel: String
    let updatedOrder: Int

    init(
        source: SearchPlatformSource? = nil,
        sourceIdentifier: String? = nil,
        title: String,
        curator: String,
        summary: String,
        description: String,
        categories: [String],
        tracks: [Track],
        artwork: ArtworkPalette,
        customArtworkData: Data? = nil,
        remoteArtworkURL: URL? = nil,
        playCount: Int,
        followerCount: Int,
        playCountDisplay: String? = nil,
        followerCountDisplay: String? = nil,
        declaredTrackCount: Int? = nil,
        updatedLabel: String,
        updatedOrder: Int
    ) {
        self.source = source
        self.sourceIdentifier = sourceIdentifier
        self.title = title
        self.curator = curator
        self.summary = summary
        self.description = description
        self.categories = categories
        self.tracks = tracks
        self.artwork = artwork
        self.customArtworkData = customArtworkData
        self.remoteArtworkURL = remoteArtworkURL?.preferredArtworkURL
        self.playCount = playCount
        self.followerCount = followerCount
        self.playCountDisplay = playCountDisplay
        self.followerCountDisplay = followerCountDisplay
        self.declaredTrackCount = declaredTrackCount
        self.updatedLabel = updatedLabel
        self.updatedOrder = updatedOrder
    }

    var primaryCategory: String {
        categories.first ?? "推荐"
    }

    var trackCount: Int {
        declaredTrackCount ?? tracks.count
    }

    var playCountText: String {
        if let playCountDisplay, !playCountDisplay.isEmpty {
            return playCountDisplay
        }
        return compactCount(playCount)
    }

    var followerCountText: String {
        if let followerCountDisplay, !followerCountDisplay.isEmpty {
            return followerCountDisplay
        }
        return compactCount(followerCount)
    }

    var hasPlayCount: Bool {
        (playCountDisplay?.isEmpty == false) || playCount > 0
    }

    var hasFollowerCount: Bool {
        (followerCountDisplay?.isEmpty == false) || followerCount > 0
    }

    var stableKey: String {
        sourceIdentifier ?? id.uuidString
    }

    var isCustomPlaylist: Bool {
        stableKey.hasPrefix(Self.customStableKeyPrefix)
    }

    var customPlaylistID: String? {
        guard isCustomPlaylist else { return nil }
        return String(stableKey.dropFirst(Self.customStableKeyPrefix.count))
    }

    private func compactCount(_ value: Int) -> String {
        guard value >= 10_000 else { return "\(value)" }

        let major = value / 10_000
        let minor = (value % 10_000) / 1_000
        return minor == 0 ? "\(major)万" : "\(major).\(minor)万"
    }

    static let customStableKeyPrefix = "custom:"

    static func customStableKey(for id: String) -> String {
        "\(customStableKeyPrefix)\(id)"
    }
}

extension URL {
    var preferredArtworkURL: URL {
        guard scheme?.lowercased() == "http",
              var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }

        components.scheme = "https"
        return components.url ?? self
    }
}

extension SearchPlatformSource {
    var searchArtworkPalette: ArtworkPalette {
        switch self {
        case .all:
            return ArtworkPalette(
                colors: [Color(red: 0.46, green: 0.50, blue: 0.58), Color(red: 0.10, green: 0.12, blue: 0.18)],
                glow: Color(red: 0.72, green: 0.76, blue: 0.84),
                symbol: "magnifyingglass.circle.fill",
                label: "All"
            )
        case .kw:
            return ArtworkPalette(
                colors: [Color(red: 0.93, green: 0.55, blue: 0.24), Color(red: 0.27, green: 0.12, blue: 0.10)],
                glow: Color(red: 1.00, green: 0.75, blue: 0.42),
                symbol: "music.note",
                label: title
            )
        case .kg:
            return ArtworkPalette(
                colors: [Color(red: 0.10, green: 0.65, blue: 0.76), Color(red: 0.05, green: 0.14, blue: 0.24)],
                glow: Color(red: 0.52, green: 0.89, blue: 0.97),
                symbol: "waveform",
                label: title
            )
        case .tx:
            return ArtworkPalette(
                colors: [Color(red: 0.33, green: 0.86, blue: 0.49), Color(red: 0.08, green: 0.18, blue: 0.13)],
                glow: Color(red: 0.67, green: 0.97, blue: 0.75),
                symbol: "message.and.waveform.fill",
                label: title
            )
        case .wy:
            return ArtworkPalette(
                colors: [Color(red: 0.92, green: 0.27, blue: 0.30), Color(red: 0.23, green: 0.07, blue: 0.12)],
                glow: Color(red: 1.00, green: 0.58, blue: 0.61),
                symbol: "dot.radiowaves.left.and.right",
                label: title
            )
        case .mg:
            return ArtworkPalette(
                colors: [Color(red: 0.93, green: 0.76, blue: 0.24), Color(red: 0.31, green: 0.15, blue: 0.08)],
                glow: Color(red: 1.00, green: 0.86, blue: 0.47),
                symbol: "music.mic",
                label: title
            )
        }
    }
}

struct StoredSearchSongRecord: Codable {
    let id: String
    let source: String
    let title: String
    let artist: String
    let album: String
    let durationText: String
    let artworkURL: String?
    let qualities: [String]
    let legacyInfoJSON: String

    init(song: SearchSong) {
        id = song.id
        source = song.source.rawValue
        title = song.title
        artist = song.artist
        album = song.album
        durationText = song.durationText
        artworkURL = song.artworkURL?.absoluteString
        qualities = song.qualities
        legacyInfoJSON = song.legacyInfoJSON
    }

    var searchSong: SearchSong? {
        guard let source = SearchPlatformSource(rawValue: source) else { return nil }
        return SearchSong(
            id: id,
            source: source,
            title: title,
            artist: artist,
            album: album,
            durationText: durationText,
            artworkURL: artworkURL.flatMap(URL.init(string:)),
            qualities: qualities,
            legacyInfoJSON: legacyInfoJSON
        )
    }
}

struct StoredColorRecord: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    @MainActor
    init(color: Color) {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var resolvedRed: CGFloat = 1
        var resolvedGreen: CGFloat = 1
        var resolvedBlue: CGFloat = 1
        var resolvedAlpha: CGFloat = 1
        uiColor.getRed(&resolvedRed, green: &resolvedGreen, blue: &resolvedBlue, alpha: &resolvedAlpha)
        red = Double(resolvedRed)
        green = Double(resolvedGreen)
        blue = Double(resolvedBlue)
        alpha = Double(resolvedAlpha)
        #elseif canImport(AppKit)
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
        red = Double(nsColor.redComponent)
        green = Double(nsColor.greenComponent)
        blue = Double(nsColor.blueComponent)
        alpha = Double(nsColor.alphaComponent)
        #else
        red = 1
        green = 1
        blue = 1
        alpha = 1
        #endif
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct StoredArtworkPaletteRecord: Codable {
    let colors: [StoredColorRecord]
    let glow: StoredColorRecord
    let symbol: String
    let label: String

    @MainActor
    init(artwork: ArtworkPalette) {
        colors = artwork.colors.map(StoredColorRecord.init)
        glow = StoredColorRecord(color: artwork.glow)
        symbol = artwork.symbol
        label = artwork.label
    }

    var artworkPalette: ArtworkPalette {
        ArtworkPalette(
            colors: colors.map(\.swiftUIColor),
            glow: glow.swiftUIColor,
            symbol: symbol,
            label: label
        )
    }
}

struct StoredTrackRecord: Codable, Identifiable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let blurb: String
    let genre: String
    let duration: TimeInterval
    let audioURL: String?
    let artwork: StoredArtworkPaletteRecord
    let searchSong: StoredSearchSongRecord?
    let sourceName: String?

    @MainActor
    init(track: Track) {
        id = track.storageKey
        title = track.title
        artist = track.artist
        album = track.album
        blurb = track.blurb
        genre = track.genre
        duration = track.duration
        audioURL = track.audioURL?.absoluteString
        artwork = StoredArtworkPaletteRecord(artwork: track.artwork)
        searchSong = track.searchSong.map(StoredSearchSongRecord.init)
        sourceName = track.sourceName
    }

    var track: Track {
        Track(
            title: title,
            artist: artist,
            album: album,
            blurb: blurb,
            genre: genre,
            duration: duration,
            audioURL: audioURL.flatMap(URL.init(string:)),
            artwork: artwork.artworkPalette,
            searchSong: searchSong?.searchSong,
            sourceName: sourceName
        )
    }
}
