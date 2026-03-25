//
//  MusicSearchModels.swift
//  XMusic
//
//  Created by Codex on 2026/3/20.
//

import Foundation

enum SearchPlatformSource: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all
    case kw
    case kg
    case tx
    case wy
    case mg

    var id: String { rawValue }

    static var builtIn: [SearchPlatformSource] {
        [.kw, .kg, .tx, .wy, .mg]
    }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .kw:
            return "酷我"
        case .kg:
            return "酷狗"
        case .tx:
            return "QQ"
        case .wy:
            return "网易"
        case .mg:
            return "咪咕"
        }
    }
}

struct SearchSong: Identifiable, Hashable, Sendable {
    let id: String
    let source: SearchPlatformSource
    let title: String
    let artist: String
    let album: String
    let durationText: String
    let artworkURL: URL?
    let qualities: [String]
    let legacyInfoJSON: String

    init(
        id: String,
        source: SearchPlatformSource,
        title: String,
        artist: String,
        album: String,
        durationText: String,
        artworkURL: URL?,
        qualities: [String],
        legacyInfoJSON: String
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.artist = artist
        self.album = album
        self.durationText = durationText
        self.artworkURL = artworkURL?.preferredArtworkURL
        self.qualities = qualities
        self.legacyInfoJSON = legacyInfoJSON
    }

    var preferredQuality: String {
        for quality in ["flac24bit", "flac", "320k", "128k"] {
            if qualities.contains(quality) {
                return quality
            }
        }
        return qualities.first ?? "128k"
    }
}

struct SearchPageResult: Sendable {
    let source: SearchPlatformSource
    let list: [SearchSong]
    let total: Int
    let limit: Int
    let maxPage: Int
}

enum SearchDebugStatus: String, Sendable {
    case success
    case empty
    case error
}

struct SearchDebugItem: Identifiable, Sendable {
    var id: String { source.rawValue }

    let source: SearchPlatformSource
    let status: SearchDebugStatus
    let resultCount: Int
    let total: Int
    let page: Int
    let maxPage: Int
    let message: String
    let pageResult: SearchPageResult?
}

struct SearchResponseBundle: Sendable {
    let result: SearchPageResult
    let debugItems: [SearchDebugItem]
}

enum MusicSearchError: LocalizedError {
    case badResponse(String)
    case unsupportedSource

    var errorDescription: String? {
        switch self {
        case let .badResponse(message):
            return "搜索接口返回异常：\(message)"
        case .unsupportedSource:
            return "当前来源暂不支持搜索"
        }
    }
}
