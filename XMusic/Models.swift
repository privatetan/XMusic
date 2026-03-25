//
//  Models.swift
//  XMusic
//
//  Created by Codex on 2026/3/20.
//

import Foundation
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case listenNow
    case browse
    case radio
    case search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .listenNow:
            return "现在听"
        case .browse:
            return "浏览"
        case .radio:
            return "歌单"
        case .search:
            return "搜索"
        }
    }

    var symbol: String {
        switch self {
        case .listenNow:
            return "play.square.stack.fill"
        case .browse:
            return "square.grid.2x2.fill"
        case .radio:
            return "music.note.list"
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
}

struct Shelf: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let tracks: [Track]
}

struct Station: Identifiable {
    let id = UUID()
    let title: String
    let host: String
    let blurb: String
    let tint: [Color]
    let symbol: String
    let featuredTrack: Track
}

struct GenreCard: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let colors: [Color]
    let symbol: String
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

    private func compactCount(_ value: Int) -> String {
        guard value >= 10_000 else { return "\(value)" }

        let major = value / 10_000
        let minor = (value % 10_000) / 1_000
        return minor == 0 ? "\(major)万" : "\(major).\(minor)万"
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

enum DemoLibrary {
    private static func url(_ path: String) -> URL {
        URL(string: "https://www.soundhelix.com/examples/mp3/\(path)")!
    }

    static let allTracks: [Track] = [
        Track(
            title: "Midnight Echo",
            artist: "Aurora Lane",
            album: "Afterglow City",
            blurb: "深夜耳机里最柔和的电子脉冲。",
            genre: "Electronica",
            duration: 372,
            audioURL: url("SoundHelix-Song-1.mp3"),
            artwork: ArtworkPalette(
                colors: [Color(red: 0.99, green: 0.42, blue: 0.38), Color(red: 0.47, green: 0.11, blue: 0.37)],
                glow: Color(red: 1.00, green: 0.65, blue: 0.45),
                symbol: "moon.stars.fill",
                label: "Midnight"
            )
        ),
        Track(
            title: "Velvet Skyline",
            artist: "Neon Harbor",
            album: "Golden Hour Traffic",
            blurb: "带一点城市雾气的流行律动。",
            genre: "Alt Pop",
            duration: 401,
            audioURL: url("SoundHelix-Song-2.mp3"),
            artwork: ArtworkPalette(
                colors: [Color(red: 0.12, green: 0.24, blue: 0.46), Color(red: 0.76, green: 0.34, blue: 0.64)],
                glow: Color(red: 0.47, green: 0.82, blue: 1.00),
                symbol: "sparkles.tv.fill",
                label: "Skyline"
            )
        ),
        Track(
            title: "Sunset Lines",
            artist: "Mira Vale",
            album: "Palm Drive",
            blurb: "像黄昏开车穿过海岸线那样松弛。",
            genre: "Indie Pop",
            duration: 388,
            audioURL: url("SoundHelix-Song-3.mp3"),
            artwork: ArtworkPalette(
                colors: [Color(red: 0.98, green: 0.60, blue: 0.21), Color(red: 0.84, green: 0.17, blue: 0.33)],
                glow: Color(red: 1.00, green: 0.81, blue: 0.41),
                symbol: "sun.max.fill",
                label: "Sunset"
            )
        ),
        Track(
            title: "Static Bloom",
            artist: "Holo Youth",
            album: "Signal Garden",
            blurb: "颗粒感合成器和轻盈鼓点一起上升。",
            genre: "Synthwave",
            duration: 424,
            audioURL: url("SoundHelix-Song-4.mp3"),
            artwork: ArtworkPalette(
                colors: [Color(red: 0.30, green: 0.11, blue: 0.47), Color(red: 0.06, green: 0.63, blue: 0.73)],
                glow: Color(red: 0.62, green: 0.48, blue: 1.00),
                symbol: "waveform.path.ecg.rectangle.fill",
                label: "Signal"
            )
        ),
        Track(
            title: "Blue Hour",
            artist: "Cedar Bloom",
            album: "Quiet Weather",
            blurb: "适合雨后、适合散步，也适合放空。",
            genre: "Downtempo",
            duration: 356,
            audioURL: url("SoundHelix-Song-5.mp3"),
            artwork: ArtworkPalette(
                colors: [Color(red: 0.16, green: 0.31, blue: 0.60), Color(red: 0.07, green: 0.11, blue: 0.22)],
                glow: Color(red: 0.52, green: 0.76, blue: 0.96),
                symbol: "cloud.drizzle.fill",
                label: "Blue Hour"
            )
        ),
        Track(
            title: "Satellite Hearts",
            artist: "Ivory Coastline",
            album: "Orbit Season",
            blurb: "大开阔感和副歌一起冲进来。",
            genre: "Dream Pop",
            duration: 365,
            audioURL: url("SoundHelix-Song-6.mp3"),
            artwork: ArtworkPalette(
                colors: [Color(red: 0.10, green: 0.10, blue: 0.18), Color(red: 0.74, green: 0.29, blue: 0.26)],
                glow: Color(red: 0.96, green: 0.54, blue: 0.41),
                symbol: "globe.americas.fill",
                label: "Orbit"
            )
        )
    ]

    static let featuredTrack = allTracks[0]

    static let listenNowShelves: [Shelf] = [
        Shelf(
            title: "最近添加",
            subtitle: "轻快、流畅、带一点都市夜色",
            tracks: [allTracks[1], allTracks[2], allTracks[4]]
        ),
        Shelf(
            title: "空间感精选",
            subtitle: "适合大耳机和更安静的房间",
            tracks: [allTracks[3], allTracks[5], allTracks[0]]
        ),
        Shelf(
            title: "凌晨模式",
            subtitle: "把节奏放低，把情绪留住",
            tracks: [allTracks[4], allTracks[0], allTracks[1]]
        )
    ]

    static let stations: [Station] = [
        Station(
            title: "One Station",
            host: "XMusic Radio",
            blurb: "从丝滑 R&B 到更亮的合成器流行，一条顺着晚风滑下去的连续曲线。",
            tint: [Color(red: 0.93, green: 0.25, blue: 0.30), Color(red: 0.43, green: 0.05, blue: 0.17)],
            symbol: "dot.radiowaves.forward",
            featuredTrack: allTracks[0]
        ),
        Station(
            title: "Glow FM",
            host: "Mira Vale",
            blurb: "电光、霓虹、轻盈鼓机，还有一点恰到好处的浪漫。",
            tint: [Color(red: 0.15, green: 0.68, blue: 0.79), Color(red: 0.17, green: 0.17, blue: 0.42)],
            symbol: "sparkles.rectangle.stack.fill",
            featuredTrack: allTracks[3]
        ),
        Station(
            title: "After 11",
            host: "Aurora Lane",
            blurb: "给深夜不想被打扰的时候准备的连播频道。",
            tint: [Color(red: 0.48, green: 0.27, blue: 0.96), Color(red: 0.08, green: 0.08, blue: 0.18)],
            symbol: "moonphase.waning.crescent.inverse",
            featuredTrack: allTracks[4]
        )
    ]

    static let genres: [GenreCard] = [
        GenreCard(title: "流行新歌", subtitle: "明亮且上头", colors: [Color(red: 0.96, green: 0.31, blue: 0.35), Color(red: 0.98, green: 0.66, blue: 0.29)], symbol: "music.note.tv"),
        GenreCard(title: "氛围电子", subtitle: "空气感与层次", colors: [Color(red: 0.12, green: 0.29, blue: 0.62), Color(red: 0.22, green: 0.69, blue: 0.76)], symbol: "waveform.and.magnifyingglass"),
        GenreCard(title: "深夜 R&B", subtitle: "柔软又黏人", colors: [Color(red: 0.26, green: 0.13, blue: 0.41), Color(red: 0.67, green: 0.25, blue: 0.46)], symbol: "heart.text.square.fill"),
        GenreCard(title: "空间音频", subtitle: "更宽的声场", colors: [Color(red: 0.08, green: 0.14, blue: 0.21), Color(red: 0.52, green: 0.58, blue: 0.65)], symbol: "hifispeaker.and.homepod.fill")
    ]

    static let playlists: [Playlist] = [
        Playlist(
            title: "夜航霓虹",
            curator: "XMusic 编辑部",
            summary: "合成器、城市夜景和一点恰到好处的失真。",
            description: "从丝滑的夜间流行过渡到更有空间感的电子层次，适合通勤回家后把灯调暗、把节奏留在耳机里的那种晚上。",
            categories: ["推荐", "夜晚", "电子"],
            tracks: [allTracks[0], allTracks[3], allTracks[5], allTracks[4]],
            artwork: ArtworkPalette(
                colors: [Color(red: 0.95, green: 0.30, blue: 0.36), Color(red: 0.22, green: 0.09, blue: 0.30)],
                glow: Color(red: 1.00, green: 0.53, blue: 0.47),
                symbol: "sparkles",
                label: "Neon"
            ),
            playCount: 286_400,
            followerCount: 18_320,
            updatedLabel: "2 小时前更新",
            updatedOrder: 2
        ),
        Playlist(
            title: "海边晚风收集",
            curator: "Mira Vale",
            summary: "柔和鼓点、慢速流行和开窗就能吹进来的松弛感。",
            description: "偏暖色的独立流行和梦感旋律都在这里，适合傍晚散步、开车绕海岸线，或者让房间慢慢从工作模式退下来。",
            categories: ["推荐", "流行", "公路"],
            tracks: [allTracks[2], allTracks[1], allTracks[5], allTracks[4]],
            artwork: ArtworkPalette(
                colors: [Color(red: 0.98, green: 0.63, blue: 0.28), Color(red: 0.78, green: 0.20, blue: 0.31)],
                glow: Color(red: 1.00, green: 0.78, blue: 0.42),
                symbol: "sun.horizon.fill",
                label: "Breeze"
            ),
            playCount: 198_600,
            followerCount: 12_840,
            updatedLabel: "昨天更新",
            updatedOrder: 4
        ),
        Playlist(
            title: "晴窗写代码",
            curator: "Workstream",
            summary: "没有太多歌词抢戏，只把专注度慢慢拉上来。",
            description: "节拍轻、层次稳、不会突然打断思路的一组歌单，适合白天写代码、看文档和处理比较需要连续注意力的工作。",
            categories: ["学习", "电子", "推荐"],
            tracks: [allTracks[4], allTracks[3], allTracks[0], allTracks[1]],
            artwork: ArtworkPalette(
                colors: [Color(red: 0.24, green: 0.63, blue: 0.80), Color(red: 0.10, green: 0.18, blue: 0.32)],
                glow: Color(red: 0.55, green: 0.84, blue: 0.95),
                symbol: "laptopcomputer.and.arrow.down",
                label: "Focus"
            ),
            playCount: 124_200,
            followerCount: 9_460,
            updatedLabel: "30 分钟前更新",
            updatedOrder: 1
        ),
        Playlist(
            title: "卧室低光模式",
            curator: "凌晨俱乐部",
            summary: "更靠近耳边的低频和更慢一点的呼吸节奏。",
            description: "给夜深之后不想再被打扰的时候准备的歌单，副歌不会太亮，氛围会把人轻轻包起来，适合独处和反复循环。",
            categories: ["夜晚", "流行"],
            tracks: [allTracks[4], allTracks[0], allTracks[5], allTracks[1]],
            artwork: ArtworkPalette(
                colors: [Color(red: 0.38, green: 0.25, blue: 0.84), Color(red: 0.09, green: 0.09, blue: 0.19)],
                glow: Color(red: 0.67, green: 0.56, blue: 1.00),
                symbol: "bed.double.fill",
                label: "Low Light"
            ),
            playCount: 241_500,
            followerCount: 16_070,
            updatedLabel: "6 小时前更新",
            updatedOrder: 3
        ),
        Playlist(
            title: "快速出门前",
            curator: "City Route",
            summary: "节奏利落、推进感明确，适合给一天一个起步速度。",
            description: "从更亮的流行律动开始，慢慢接进合成器和干净鼓点，适合通勤路上、咖啡还没喝完之前的那段清醒时间。",
            categories: ["流行", "推荐"],
            tracks: [allTracks[1], allTracks[2], allTracks[3], allTracks[0]],
            artwork: ArtworkPalette(
                colors: [Color(red: 0.99, green: 0.43, blue: 0.36), Color(red: 0.13, green: 0.23, blue: 0.46)],
                glow: Color(red: 1.00, green: 0.67, blue: 0.51),
                symbol: "tram.fill",
                label: "Rush"
            ),
            playCount: 173_800,
            followerCount: 10_480,
            updatedLabel: "3 天前更新",
            updatedOrder: 6
        ),
        Playlist(
            title: "驶离市区",
            curator: "Drive Club",
            summary: "适合速度慢慢提起来，也适合窗外景色不断后退。",
            description: "一张更有画面感的公路歌单，保留了梦感和流行副歌的开阔度，适合长路、夜路和不想太快到达的目的地。",
            categories: ["公路", "夜晚", "流行"],
            tracks: [allTracks[5], allTracks[2], allTracks[1], allTracks[3]],
            artwork: ArtworkPalette(
                colors: [Color(red: 0.12, green: 0.20, blue: 0.30), Color(red: 0.81, green: 0.34, blue: 0.31)],
                glow: Color(red: 0.98, green: 0.56, blue: 0.41),
                symbol: "car.fill",
                label: "Drive"
            ),
            playCount: 312_700,
            followerCount: 21_140,
            updatedLabel: "今天更新",
            updatedOrder: 0
        )
    ]

    static let playlistCategories: [String] = [
        "全部",
        "推荐",
        "夜晚",
        "电子",
        "流行",
        "学习",
        "公路"
    ]

    static let searchSuggestions: [String] = [
        "Midnight",
        "Synthwave",
        "Dream Pop",
        "Aurora Lane",
        "Downtempo",
        "海边黄昏"
    ]
}
