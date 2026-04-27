//
//  MenuBarItem.swift
//  XMusic
//
//  Created by Galio on 2026/4/23.
//

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
