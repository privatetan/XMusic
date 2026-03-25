//
//  MusicPlaylistService.swift
//  XMusic
//
//  Created by Codex on 2026/3/23.
//

import CryptoKit
import Foundation
import SwiftUI

enum MusicPlaylistError: LocalizedError {
    case unsupportedSource
    case missingPlaylistIdentifier
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSource:
            return "当前平台暂不支持加载歌单"
        case .missingPlaylistIdentifier:
            return "歌单标识缺失，无法继续加载详情"
        case let .badResponse(message):
            return "歌单接口返回异常：\(message)"
        }
    }
}

struct MusicPlaylistService {
    func supportedSorts(for source: SearchPlatformSource) -> [PlaylistSortOption] {
        switch source {
        case .kw:
            return [.hottest, .latest]
        case .kg:
            return [.recommended, .hottest, .latest]
        case .tx:
            return [.hottest, .latest]
        case .wy:
            return [.hottest]
        case .mg:
            return [.recommended]
        case .all:
            return []
        }
    }

    func fetchPlaylists(
        source: SearchPlatformSource,
        sort: PlaylistSortOption,
        page: Int = 1
    ) async throws -> [Playlist] {
        switch source {
        case .kw:
            return try await fetchKuwoPlaylists(sort: sort, page: page)
        case .kg:
            return try await fetchKugouPlaylists(sort: sort, page: page)
        case .tx:
            return try await fetchQQPlaylists(sort: sort, page: page)
        case .wy:
            return try await fetchNeteasePlaylists(sort: sort, page: page)
        case .mg:
            return try await fetchMiguPlaylists(sort: sort, page: page)
        case .all:
            throw MusicPlaylistError.unsupportedSource
        }
    }

    func fetchPlaylistDetail(for playlist: Playlist) async throws -> Playlist {
        guard let source = playlist.source else {
            throw MusicPlaylistError.unsupportedSource
        }
        guard let identifier = playlist.sourceIdentifier, !identifier.isEmpty else {
            throw MusicPlaylistError.missingPlaylistIdentifier
        }

        switch source {
        case .kw:
            return try await fetchKuwoPlaylistDetail(summary: playlist, identifier: identifier)
        case .kg:
            return try await fetchKugouPlaylistDetail(summary: playlist, identifier: identifier)
        case .tx:
            return try await fetchQQPlaylistDetail(summary: playlist, identifier: identifier)
        case .wy:
            return try await fetchNeteasePlaylistDetail(summary: playlist, identifier: identifier)
        case .mg:
            return try await fetchMiguPlaylistDetail(summary: playlist, identifier: identifier)
        case .all:
            throw MusicPlaylistError.unsupportedSource
        }
    }

    private func fetchKuwoPlaylists(sort: PlaylistSortOption, page: Int) async throws -> [Playlist] {
        let order = sort == .latest ? "new" : "hot"
        let urlString = "http://wapi.kuwo.cn/api/pc/classify/playlist/getRcmPlayList?loginUid=0&loginSid=0&appUid=76039576&pn=\(page)&rn=36&order=\(order)"
        let object = try await getJSON(urlString)
        guard (object["code"] as? Int) == 200,
              let data = object["data"] as? [String: Any],
              let rawList = data["data"] as? [[String: Any]] else {
            throw MusicPlaylistError.badResponse("酷我歌单")
        }

        return rawList.compactMap { raw in
            let playlistID = "\(stringValue(raw["digest"]).nilIfEmpty.map { "digest-\($0)__" } ?? "")\(stringValue(raw["id"]))"
            return makePlaylistSummary(
                source: .kw,
                playlistID: playlistID,
                title: stringValue(raw["name"]),
                curator: stringValue(raw["uname"]).nilIfEmpty ?? "酷我歌单",
                description: stringValue(raw["desc"]),
                categories: [SearchPlatformSource.kw.title],
                artworkURL: URL(string: stringValue(raw["img"])),
                playCountText: formatCount(raw["listencnt"]),
                trackCount: intValue(raw["total"]),
                updatedLabel: ""
            )
        }
    }

    private func fetchQQPlaylists(sort: PlaylistSortOption, page: Int) async throws -> [Playlist] {
        let order: Int
        switch sort {
        case .latest:
            order = 2
        default:
            order = 5
        }

        let payload: [String: Any] = [
            "comm": ["cv": 1602, "ct": 20],
            "playlist": [
                "method": "get_playlist_by_tag",
                "param": [
                    "id": 10000000,
                    "sin": 36 * (page - 1),
                    "size": 36,
                    "order": order,
                    "cur_page": page,
                ],
                "module": "playlist.PlayListPlazaServer",
            ],
        ]
        let data = try encodeJSONObject(payload)
        let urlString = "https://u.y.qq.com/cgi-bin/musicu.fcg?loginUin=0&hostUin=0&format=json&inCharset=utf-8&outCharset=utf-8&notice=0&platform=wk_v15.json&needNewCode=0&data=\(data.urlEscaped)"
        let object = try await getJSON(urlString)
        guard (object["code"] as? Int) == 0,
              let playlist = object["playlist"] as? [String: Any],
              let body = playlist["data"] as? [String: Any],
              let rawList = body["v_playlist"] as? [[String: Any]] else {
            throw MusicPlaylistError.badResponse("QQ 歌单")
        }

        return rawList.compactMap { raw in
            makePlaylistSummary(
                source: .tx,
                playlistID: stringValue(raw["tid"]),
                title: decodeEntity(stringValue(raw["title"])),
                curator: stringValue((raw["creator_info"] as? [String: Any])?["nick"]).nilIfEmpty ?? "QQ 歌单",
                description: decodeHTMLBreaks(stringValue(raw["desc"])),
                categories: [SearchPlatformSource.tx.title],
                artworkURL: URL(string: stringValue(raw["cover_url_medium"])),
                playCountText: formatCount(raw["access_num"]),
                trackCount: (raw["song_ids"] as? [Any])?.count,
                updatedLabel: dateLabel(fromUnixSeconds: intValue(raw["modify_time"]))
            )
        }
    }

    private func fetchNeteasePlaylists(sort: PlaylistSortOption, page: Int) async throws -> [Playlist] {
        let order = sort == .latest ? "new" : "hot"
        let offset = 30 * (page - 1)
        let urlString = "https://music.163.com/api/playlist/list?cat=%E5%85%A8%E9%83%A8&order=\(order)&limit=30&offset=\(offset)"
        let object = try await getJSON(urlString)
        guard let rawList = object["playlists"] as? [[String: Any]] else {
            throw MusicPlaylistError.badResponse("网易歌单")
        }

        return rawList.compactMap { raw in
            makePlaylistSummary(
                source: .wy,
                playlistID: stringValue(raw["id"]),
                title: stringValue(raw["name"]),
                curator: stringValue((raw["creator"] as? [String: Any])?["nickname"]).nilIfEmpty ?? "网易歌单",
                description: stringValue(raw["description"]),
                categories: (raw["tags"] as? [String]).flatMap { $0.isEmpty ? nil : $0 } ?? [SearchPlatformSource.wy.title],
                artworkURL: URL(string: stringValue(raw["coverImgUrl"])),
                playCountText: formatCount(raw["playCount"]),
                trackCount: intValue(raw["trackCount"]),
                updatedLabel: dateLabel(fromMilliseconds: intValue(raw["updateTime"]))
            )
        }
    }

    private func fetchMiguPlaylists(sort: PlaylistSortOption, page: Int) async throws -> [Playlist] {
        let _ = sort
        let object = try await getJSON(
            "https://app.c.nf.migu.cn/pc/bmw/page-data/playlist-square-recommend/v1.0?templateVersion=2&pageNo=\(page)",
            headers: miguHeaders
        )
        guard (object["code"] as? String) == "000000",
              let data = object["data"] as? [String: Any] else {
            throw MusicPlaylistError.badResponse("咪咕歌单")
        }

        let playlists: [Playlist]
        if let contents = data["contents"] as? [[String: Any]] {
            playlists = flattenMiguPlaylists(contents)
        } else if let groups = data["contentItemList"] as? [[String: Any]],
                  groups.count > 1,
                  let items = groups[1]["itemList"] as? [[String: Any]] {
            playlists = items.compactMap(makeMiguPlaylistFromItemList)
        } else {
            playlists = []
        }

        return playlists
    }

    private func fetchKugouPlaylists(sort: PlaylistSortOption, page: Int) async throws -> [Playlist] {
        let sortID: String
        switch sort {
        case .recommended:
            sortID = "5"
        case .hottest:
            sortID = "6"
        case .latest:
            sortID = "7"
        }

        let urlString = "http://www2.kugou.kugou.com/yueku/v9/special/getSpecial?is_ajax=1&cdn=cdn&t=\(sortID)&c=&p=\(page)"
        let object = try await getJSON(urlString)
        guard (object["status"] as? Int) == 1,
              let rawList = object["special_db"] as? [[String: Any]] else {
            throw MusicPlaylistError.badResponse("酷狗歌单")
        }

        return rawList.compactMap { raw -> Playlist? in
            let specialID = stringValue(raw["specialid"])
            guard !specialID.isEmpty else { return nil }

            return makePlaylistSummary(
                source: .kg,
                playlistID: "id_\(specialID)",
                title: decodeEntity(stringValue(raw["specialname"])),
                curator: stringValue(raw["nickname"]).nilIfEmpty ?? "酷狗歌单",
                description: stringValue(raw["intro"]),
                categories: [SearchPlatformSource.kg.title],
                artworkURL: URL(string: stringValue(raw["img"])),
                playCountText: formatCount(raw["total_play_count"] ?? raw["play_count"]),
                trackCount: intValue(raw["songcount"]),
                updatedLabel: dateLabel(fromMilliseconds: intValue(raw["publish_time"] ?? raw["publishtime"]))
            )
        }
    }

    private func fetchKuwoPlaylistDetail(summary: Playlist, identifier: String) async throws -> Playlist {
        let playlistID: String
        if identifier.hasPrefix("digest-"), let rawID = identifier.components(separatedBy: "__").last {
            let digest = identifier.replacingOccurrences(of: rawID, with: "").replacingOccurrences(of: "__", with: "").replacingOccurrences(of: "digest-", with: "")
            if digest == "5" {
                let object = try await getJSON("http://qukudata.kuwo.cn/q.k?op=query&cont=ninfo&node=\(rawID)&pn=0&rn=1&fmt=json&src=mbox&level=2")
                if let child = (object["child"] as? [[String: Any]])?.first,
                   let sourceID = stringValue(child["sourceid"]).nilIfEmpty {
                    playlistID = sourceID
                } else {
                    playlistID = rawID
                }
            } else {
                playlistID = rawID
            }
        } else {
            playlistID = identifier
        }

        let object = try await getJSON("http://nplserver.kuwo.cn/pl.svc?op=getlistinfo&pid=\(playlistID)&pn=0&rn=1000&encode=utf8&keyset=pl2012&identity=kuwo&pcmp4=1&vipver=MUSIC_9.0.5.0_W1&newver=1")
        guard stringValue(object["result"]) == "ok",
              let rawSongs = object["musiclist"] as? [[String: Any]] else {
            throw MusicPlaylistError.badResponse("酷我歌单详情")
        }

        let title = decodeEntity(stringValue(object["title"])).nilIfEmpty ?? summary.title
        let description = stringValue(object["info"]).nilIfEmpty ?? summary.description
        let curator = stringValue(object["uname"]).nilIfEmpty ?? summary.curator
        let coverURL = URL(string: stringValue(object["pic"]))
        let playCount = formatCount(object["playnum"]) ?? summary.playCountText
        let tracks = makeTracks(
            from: rawSongs.compactMap(makeKuwoSongFromPlaylist),
            playlistTitle: title,
            playlistCategory: summary.primaryCategory
        )

        return makeDetailedPlaylist(
            from: summary,
            title: title,
            curator: curator,
            description: description,
            artworkURL: coverURL,
            playCountText: playCount,
            declaredTrackCount: intValue(object["total"]) > 0 ? intValue(object["total"]) : rawSongs.count,
            tracks: tracks
        )
    }

    private func fetchQQPlaylistDetail(summary: Playlist, identifier: String) async throws -> Playlist {
        let urlString = "https://c.y.qq.com/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg?type=1&json=1&utf8=1&onlysong=0&new_format=1&disstid=\(identifier)&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8&notice=0&platform=yqq.json&needNewCode=0"
        let object = try await getJSON(
            urlString,
            headers: [
                "Origin": "https://y.qq.com",
                "Referer": "https://y.qq.com/n/yqq/playsquare/\(identifier).html",
            ]
        )
        guard (object["code"] as? Int) == 0,
              let cdlist = (object["cdlist"] as? [[String: Any]])?.first,
              let rawSongs = cdlist["songlist"] as? [[String: Any]] else {
            throw MusicPlaylistError.badResponse("QQ 歌单详情")
        }

        let title = decodeEntity(stringValue(cdlist["dissname"])).nilIfEmpty ?? summary.title
        let description = decodeHTMLBreaks(stringValue(cdlist["desc"])).nilIfEmpty ?? summary.description
        let curator = stringValue(cdlist["nickname"]).nilIfEmpty ?? summary.curator
        let coverURL = URL(string: stringValue(cdlist["logo"]))
        let tracks = makeTracks(
            from: rawSongs.compactMap(makeQQSongFromPlaylist),
            playlistTitle: title,
            playlistCategory: summary.primaryCategory
        )

        return makeDetailedPlaylist(
            from: summary,
            title: title,
            curator: curator,
            description: description,
            artworkURL: coverURL,
            playCountText: formatCount(cdlist["visitnum"]) ?? summary.playCountText,
            declaredTrackCount: rawSongs.count,
            tracks: tracks
        )
    }

    private func fetchNeteasePlaylistDetail(summary: Playlist, identifier: String) async throws -> Playlist {
        let object = try await getJSON(
            "https://music.163.com/api/v3/playlist/detail?id=\(identifier)&n=1000&s=8",
            headers: ["origin": "https://music.163.com"]
        )
        guard (object["code"] as? Int) == 200,
              let playlist = object["playlist"] as? [String: Any],
              let privileges = object["privileges"] as? [[String: Any]] else {
            throw MusicPlaylistError.badResponse("网易歌单详情")
        }

        let rawTracks = playlist["tracks"] as? [[String: Any]] ?? []
        let songs = makeNeteaseSongsFromPlaylist(rawTracks: rawTracks, privileges: privileges)
        let title = stringValue(playlist["name"]).nilIfEmpty ?? summary.title
        let description = stringValue(playlist["description"]).nilIfEmpty ?? summary.description
        let curator = stringValue((playlist["creator"] as? [String: Any])?["nickname"]).nilIfEmpty ?? summary.curator
        let coverURL = URL(string: stringValue(playlist["coverImgUrl"]))
        let categories = (playlist["tags"] as? [String]).flatMap { $0.isEmpty ? nil : $0 } ?? summary.categories

        let detail = makeDetailedPlaylist(
            from: summary,
            title: title,
            curator: curator,
            description: description,
            artworkURL: coverURL,
            playCountText: formatCount(playlist["playCount"]) ?? summary.playCountText,
            declaredTrackCount: intValue(playlist["trackCount"]),
            tracks: makeTracks(from: songs, playlistTitle: title, playlistCategory: categories.first ?? summary.primaryCategory)
        )

        return Playlist(
            source: detail.source,
            sourceIdentifier: detail.sourceIdentifier,
            title: detail.title,
            curator: detail.curator,
            summary: detail.summary,
            description: detail.description,
            categories: categories,
            tracks: detail.tracks,
            artwork: detail.artwork,
            remoteArtworkURL: detail.remoteArtworkURL,
            playCount: detail.playCount,
            followerCount: detail.followerCount,
            playCountDisplay: detail.playCountDisplay,
            followerCountDisplay: detail.followerCountDisplay,
            declaredTrackCount: detail.declaredTrackCount,
            updatedLabel: detail.updatedLabel,
            updatedOrder: detail.updatedOrder
        )
    }

    private func fetchMiguPlaylistDetail(summary: Playlist, identifier: String) async throws -> Playlist {
        async let infoTask = getJSON(
            "https://c.musicapp.migu.cn/MIGUM3.0/resource/playlist/v2.0?playlistId=\(identifier)",
            headers: miguHeaders
        )
        async let songsTask = getJSON(
            "https://app.c.nf.migu.cn/MIGUM3.0/resource/playlist/song/v2.0?pageNo=1&pageSize=200&playlistId=\(identifier)",
            headers: miguHeaders
        )

        let (infoObject, songsObject) = try await (infoTask, songsTask)
        guard (infoObject["code"] as? String) == "000000",
              (songsObject["code"] as? String) == "000000",
              let infoData = infoObject["data"] as? [String: Any],
              let songsData = songsObject["data"] as? [String: Any],
              let rawSongs = songsData["songList"] as? [[String: Any]] else {
            throw MusicPlaylistError.badResponse("咪咕歌单详情")
        }

        let title = stringValue(infoData["title"]).nilIfEmpty ?? summary.title
        let description = stringValue(infoData["summary"]).nilIfEmpty ?? summary.description
        let curator = stringValue(infoData["ownerName"]).nilIfEmpty ?? summary.curator
        let coverURL = URL(string: stringValue((infoData["imgItem"] as? [String: Any])?["img"]))
        let playCount = formatCount((infoData["opNumItem"] as? [String: Any])?["playNum"]) ?? summary.playCountText
        let songs = rawSongs.compactMap(makeMiguSongFromPlaylist)

        return makeDetailedPlaylist(
            from: summary,
            title: title,
            curator: curator,
            description: description,
            artworkURL: coverURL,
            playCountText: playCount,
            declaredTrackCount: intValue(songsData["totalCount"]),
            tracks: makeTracks(from: songs, playlistTitle: title, playlistCategory: summary.primaryCategory)
        )
    }

    private func fetchKugouPlaylistDetail(summary: Playlist, identifier: String) async throws -> Playlist {
        if identifier.hasPrefix("gid_") {
            let collectionID = identifier.replacingOccurrences(of: "gid_", with: "")
            let info = try await fetchKugouCollectionInfo(collectionID: collectionID)
            let rawSongs = try await fetchKugouCollectionSongs(collectionID: collectionID)
            let tracks = makeTracks(
                from: rawSongs.compactMap(makeKugouSongFromCollectionPlaylist),
                playlistTitle: info.name,
                playlistCategory: summary.primaryCategory
            )

            return makeDetailedPlaylist(
                from: summary,
                title: info.name,
                curator: info.userName.nilIfEmpty ?? summary.curator,
                description: info.desc.nilIfEmpty ?? summary.description,
                artworkURL: URL(string: info.imageUrl.replacingOccurrences(of: "{size}", with: "480")),
                playCountText: formatCount(info.playCount) ?? summary.playCountText,
                declaredTrackCount: info.total,
                tracks: tracks
            )
        }

        let specialID = identifier.replacingOccurrences(of: "id_", with: "")
        let html = try await getText("http://www2.kugou.kugou.com/yueku/v9/special/single/\(specialID)-5-9999.html")
        let rawSongs = try parseKugouHTMLSongList(html)
        let info = parseKugouHTMLInfo(html)
        let tracks = makeTracks(
            from: rawSongs.compactMap(makeKugouSongFromHTMLPlaylist),
            playlistTitle: info.name ?? summary.title,
            playlistCategory: summary.primaryCategory
        )

        return makeDetailedPlaylist(
            from: summary,
            title: info.name ?? summary.title,
            curator: summary.curator,
            description: info.desc ?? summary.description,
            artworkURL: info.pic.flatMap(URL.init(string:)),
            playCountText: summary.playCountText,
            declaredTrackCount: rawSongs.count,
            tracks: tracks
        )
    }

    private func fetchKugouCollectionID(from specialID: String) async throws -> String {
        let object = try await getJSON(
            "http://mobilecdnbj.kugou.com/api/v5/special/info?specialid=\(specialID)",
            headers: [
                "User-Agent": "Mozilla/5.0 (Linux; Android 10; HLK-AL00) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.5112.102 Mobile Safari/537.36 EdgA/104.0.1293.70",
            ]
        )
        if let data = object["data"] as? [String: Any],
           let collectionID = stringValue(data["global_specialid"]).nilIfEmpty {
            return collectionID
        }
        throw MusicPlaylistError.badResponse("酷狗歌单标识")
    }

    private func fetchKugouCollectionInfo(collectionID: String) async throws -> KugouCollectionInfo {
        let baseParams = "appid=1058&specialid=0&global_specialid=\(collectionID)&format=jsonp&srcappid=2919&clientver=20000&clienttime=1586163242519&mid=1586163242519&uuid=1586163242519&dfid=-"
        let signature = kugouSignature(params: baseParams, platform: "web")
        let object = try await getJSON(
            "https://mobiles.kugou.com/api/v5/special/info_v2?\(baseParams)&signature=\(signature)",
            headers: [
                "mid": "1586163242519",
                "Referer": "https://m3ws.kugou.com/share/index.php",
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1",
                "dfid": "-",
                "clienttime": "1586163242519",
            ]
        )
        return KugouCollectionInfo(
            userName: stringValue(object["nickname"]),
            imageUrl: stringValue(object["imgurl"]),
            desc: stringValue(object["intro"]),
            name: stringValue(object["specialname"]).nilIfEmpty ?? "酷狗歌单",
            total: intValue(object["songcount"]),
            playCount: object["playcount"]
        )
    }

    private func fetchKugouCollectionSongs(collectionID: String) async throws -> [[String: Any]] {
        let params = "need_sort=1&module=CloudMusic&clientver=11589&pagesize=300&global_collection_id=\(collectionID)&userid=0&page=1&type=0&area_code=1&appid=1005"
        let signature = kugouSignature(params: params, platform: "android")
        let object = try await getJSON(
            "http://pubsongs.kugou.com/v2/get_other_list_file?\(params)&signature=\(signature)",
            headers: [
                "User-Agent": "Android10-AndroidPhone-11589-201-0-playlist-wifi",
            ]
        )
        guard let info = object["info"] as? [[String: Any]] else {
            throw MusicPlaylistError.badResponse("酷狗歌单详情")
        }
        return info
    }

    private func makePlaylistSummary(
        source: SearchPlatformSource,
        playlistID: String,
        title: String,
        curator: String,
        description: String,
        categories: [String],
        artworkURL: URL?,
        playCountText: String?,
        trackCount: Int?,
        updatedLabel: String
    ) -> Playlist? {
        let cleanTitle = title.nilIfEmpty ?? "未命名歌单"
        let cleanDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = cleanDescription.isEmpty ? "\(source.title) 推荐歌单" : excerpt(cleanDescription, limit: 38)

        return Playlist(
            source: source,
            sourceIdentifier: playlistID,
            title: cleanTitle,
            curator: curator,
            summary: summary,
            description: cleanDescription.isEmpty ? summary : cleanDescription,
            categories: categories.isEmpty ? [source.title] : categories,
            tracks: [],
            artwork: playlistPalette(for: source, seed: playlistID),
            remoteArtworkURL: artworkURL,
            playCount: 0,
            followerCount: 0,
            playCountDisplay: playCountText,
            followerCountDisplay: nil,
            declaredTrackCount: trackCount,
            updatedLabel: updatedLabel,
            updatedOrder: 0
        )
    }

    private func makeDetailedPlaylist(
        from summary: Playlist,
        title: String,
        curator: String,
        description: String,
        artworkURL: URL?,
        playCountText: String?,
        declaredTrackCount: Int?,
        tracks: [Track]
    ) -> Playlist {
        let cleanDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return Playlist(
            source: summary.source,
            sourceIdentifier: summary.sourceIdentifier,
            title: title,
            curator: curator,
            summary: cleanDescription.isEmpty ? summary.summary : excerpt(cleanDescription, limit: 38),
            description: cleanDescription.isEmpty ? summary.description : cleanDescription,
            categories: summary.categories,
            tracks: tracks,
            artwork: summary.artwork,
            remoteArtworkURL: artworkURL ?? summary.remoteArtworkURL,
            playCount: summary.playCount,
            followerCount: summary.followerCount,
            playCountDisplay: playCountText ?? summary.playCountDisplay,
            followerCountDisplay: summary.followerCountDisplay,
            declaredTrackCount: declaredTrackCount ?? summary.declaredTrackCount,
            updatedLabel: summary.updatedLabel,
            updatedOrder: summary.updatedOrder
        )
    }

    private func makeTracks(from songs: [SearchSong], playlistTitle: String, playlistCategory: String) -> [Track] {
        songs.enumerated().map { index, song in
            Track(
                title: song.title,
                artist: song.artist,
                album: song.album,
                blurb: "\(playlistTitle) · 第 \(index + 1) 首",
                genre: playlistCategory,
                duration: parseDuration(song.durationText),
                audioURL: nil,
                artwork: playlistPalette(for: song.source, seed: song.id),
                searchSong: song,
                sourceName: song.source.title
            )
        }
    }

    private func makeKuwoSongFromPlaylist(raw: [String: Any]) -> SearchSong? {
        let qualityPairs = parseKuwoQualityInfo(stringValue(raw["N_MINFO"]))
        let types = qualityPairs.map { ["type": $0.0, "size": $0.1] }
        let _types = Dictionary(uniqueKeysWithValues: qualityPairs.map { ($0.0, ["size": $0.1]) })
        let legacy: [String: Any] = [
            "name": decodeEntity(stringValue(raw["name"])),
            "singer": formatSinger(decodeEntity(stringValue(raw["artist"]))),
            "source": SearchPlatformSource.kw.rawValue,
            "songmid": stringValue(raw["id"]),
            "albumId": stringValue(raw["albumid"]),
            "interval": formatDuration(seconds: intValue(raw["duration"])),
            "albumName": decodeEntity(stringValue(raw["album"])),
            "img": "",
            "types": types,
            "_types": _types,
            "typeUrl": [:],
        ]

        return makeSearchSong(
            id: "kw_\(stringValue(raw["id"]))",
            source: .kw,
            title: stringValue(legacy["name"]),
            artist: stringValue(legacy["singer"]),
            album: stringValue(legacy["albumName"]),
            durationText: stringValue(legacy["interval"]),
            artworkURL: nil,
            qualities: qualityPairs.map(\.0),
            legacy: legacy
        )
    }

    private func makeQQSongFromPlaylist(raw: [String: Any]) -> SearchSong? {
        guard let file = raw["file"] as? [String: Any],
              let mediaMid = stringValue(file["media_mid"]).nilIfEmpty,
              let songMid = stringValue(raw["mid"]).nilIfEmpty else {
            return nil
        }

        var qualities: [(String, String?)] = []
        if let size = positiveSizeString(file["size_128mp3"]) { qualities.append(("128k", size)) }
        if let size = positiveSizeString(file["size_320mp3"]) { qualities.append(("320k", size)) }
        if let size = positiveSizeString(file["size_flac"]) { qualities.append(("flac", size)) }
        if let size = positiveSizeString(file["size_hires"]) { qualities.append(("flac24bit", size)) }

        let album = raw["album"] as? [String: Any] ?? [:]
        let albumMid = stringValue(album["mid"])
        let artworkURL: URL? = {
            if let firstSinger = (raw["singer"] as? [[String: Any]])?.first,
               albumMid.isEmpty,
               let singerMid = stringValue(firstSinger["mid"]).nilIfEmpty {
                return URL(string: "https://y.gtimg.cn/music/photo_new/T001R500x500M000\(singerMid).jpg")
            }
            guard !albumMid.isEmpty else { return nil }
            return URL(string: "https://y.gtimg.cn/music/photo_new/T002R500x500M000\(albumMid).jpg")
        }()

        let types = qualities.map { ["type": $0.0, "size": $0.1] }
        let _types = Dictionary(uniqueKeysWithValues: qualities.map { ($0.0, ["size": $0.1]) })
        let legacy: [String: Any] = [
            "singer": joinNames(raw["singer"]),
            "name": stringValue(raw["title"]),
            "albumName": stringValue(album["name"]),
            "albumId": albumMid,
            "source": SearchPlatformSource.tx.rawValue,
            "interval": formatDuration(seconds: intValue(raw["interval"])),
            "songId": stringValue(raw["id"]),
            "albumMid": albumMid,
            "strMediaMid": mediaMid,
            "songmid": songMid,
            "img": artworkURL?.absoluteString ?? "",
            "types": types,
            "_types": _types,
            "typeUrl": [:],
        ]

        return makeSearchSong(
            id: "tx_\(songMid)",
            source: .tx,
            title: stringValue(legacy["name"]),
            artist: stringValue(legacy["singer"]),
            album: stringValue(legacy["albumName"]),
            durationText: stringValue(legacy["interval"]),
            artworkURL: artworkURL,
            qualities: qualities.map(\.0),
            legacy: legacy
        )
    }

    private func makeNeteaseSongsFromPlaylist(rawTracks: [[String: Any]], privileges: [[String: Any]]) -> [SearchSong] {
        rawTracks.compactMap { raw in
            guard let songID = stringValue(raw["id"]).nilIfEmpty else { return nil }

            let privilege = privileges.first { stringValue($0["id"]) == songID } ?? [:]
            let maxBrLevel = stringValue(privilege["maxBrLevel"])
            let maxBr = intValue(privilege["maxbr"])
            var qualities: [(String, String?)] = []

            if maxBrLevel == "hires",
               let hr = raw["hr"] as? [String: Any],
               let size = positiveSizeString(hr["size"]) {
                qualities.append(("flac24bit", size))
            }
            if maxBr >= 999_000,
               let sq = raw["sq"] as? [String: Any],
               let size = positiveSizeString(sq["size"]) {
                qualities.append(("flac", size))
            }
            if maxBr >= 320_000,
               let h = raw["h"] as? [String: Any],
               let size = positiveSizeString(h["size"]) {
                qualities.append(("320k", size))
            }
            if maxBr >= 128_000,
               let l = raw["l"] as? [String: Any],
               let size = positiveSizeString(l["size"]) {
                qualities.append(("128k", size))
            }

            let album = raw["al"] as? [String: Any] ?? [:]
            let artworkURL = URL(string: stringValue(album["picUrl"]))
            let types = qualities.reversed().map { ["type": $0.0, "size": $0.1] }
            let _types = Dictionary(uniqueKeysWithValues: qualities.map { ($0.0, ["size": $0.1]) })
            let legacy: [String: Any] = [
                "singer": joinNames(raw["ar"]),
                "name": stringValue(raw["name"]),
                "albumName": stringValue(album["name"]),
                "albumId": stringValue(album["id"]),
                "source": SearchPlatformSource.wy.rawValue,
                "interval": formatDuration(milliseconds: intValue(raw["dt"])),
                "songmid": songID,
                "img": artworkURL?.absoluteString ?? "",
                "lrc": NSNull(),
                "types": types,
                "_types": _types,
                "typeUrl": [:],
            ]

            return makeSearchSong(
                id: "wy_\(songID)",
                source: .wy,
                title: stringValue(legacy["name"]),
                artist: stringValue(legacy["singer"]),
                album: stringValue(legacy["albumName"]),
                durationText: stringValue(legacy["interval"]),
                artworkURL: artworkURL,
                qualities: qualities.map(\.0),
                legacy: legacy
            )
        }
    }

    private func makeMiguSongFromPlaylist(raw: [String: Any]) -> SearchSong? {
        guard let songID = stringValue(raw["songId"]).nilIfEmpty,
              let copyrightID = stringValue(raw["copyrightId"]).nilIfEmpty else {
            return nil
        }

        var qualities: [(String, String?)] = []
        if let audioFormats = raw["audioFormats"] as? [[String: Any]] {
            for format in audioFormats {
                let type = stringValue(format["formatType"])
                let size = positiveSizeString(format["size"] ?? format["androidSize"])
                switch type {
                case "PQ":
                    qualities.append(("128k", size))
                case "HQ":
                    qualities.append(("320k", size))
                case "SQ":
                    qualities.append(("flac", size))
                case "ZQ", "ZQ24":
                    qualities.append(("flac24bit", size))
                default:
                    break
                }
            }
        }

        let artworkCandidate = [
            stringValue(raw["img3"]),
            stringValue(raw["img2"]),
            stringValue(raw["img1"]),
        ]
        .first(where: { !$0.isEmpty })
        let artworkURL = artworkCandidate.flatMap { URL(string: $0.hasPrefix("http") ? $0 : "http://d.musicapp.migu.cn\($0)") }
        let types = qualities.map { ["type": $0.0, "size": $0.1] }
        let _types = Dictionary(uniqueKeysWithValues: qualities.map { ($0.0, ["size": $0.1]) })
        let legacy: [String: Any] = [
            "singer": joinNames(raw["singerList"]),
            "name": stringValue(raw["songName"]),
            "albumName": stringValue(raw["album"]),
            "albumId": stringValue(raw["albumId"]),
            "songmid": songID,
            "copyrightId": copyrightID,
            "source": SearchPlatformSource.mg.rawValue,
            "interval": formatMiguDuration(raw["duration"]),
            "img": artworkURL?.absoluteString ?? "",
            "lrcUrl": stringValue(raw["lrcUrl"]),
            "mrcUrl": stringValue(raw["mrcUrl"]),
            "trcUrl": stringValue(raw["trcUrl"]),
            "types": types,
            "_types": _types,
            "typeUrl": [:],
        ]

        return makeSearchSong(
            id: "mg_\(copyrightID)",
            source: .mg,
            title: stringValue(legacy["name"]),
            artist: stringValue(legacy["singer"]),
            album: stringValue(legacy["albumName"]),
            durationText: stringValue(legacy["interval"]),
            artworkURL: artworkURL,
            qualities: qualities.map(\.0),
            legacy: legacy
        )
    }

    private func makeKugouSongFromCollectionPlaylist(raw: [String: Any]) -> SearchSong? {
        let goods = raw["relate_goods"] as? [[String: Any]] ?? []
        var qualities: [(String, String?, String)] = []
        for item in goods {
            let level = intValue(item["level"])
            let size = positiveSizeString(item["size"])
            let hash = stringValue(item["hash"])
            switch level {
            case 2:
                qualities.append(("128k", size, hash))
            case 4:
                qualities.append(("320k", size, hash))
            case 5:
                qualities.append(("flac", size, hash))
            case 6:
                qualities.append(("flac24bit", size, hash))
            default:
                break
            }
        }

        let types = qualities.map { ["type": $0.0, "size": $0.1, "hash": $0.2] }
        let _types = Dictionary(uniqueKeysWithValues: qualities.map { ($0.0, ["size": $0.1, "hash": $0.2]) })
        let legacy: [String: Any] = [
            "singer": joinNames(raw["singerinfo"]),
            "name": stringValue(raw["name"]).components(separatedBy: " - ").dropFirst().joined(separator: " - ").nilIfEmpty ?? decodeEntity(stringValue(raw["name"])),
            "albumName": stringValue((raw["albuminfo"] as? [String: Any])?["name"]),
            "albumId": stringValue((raw["albuminfo"] as? [String: Any])?["id"]),
            "songmid": stringValue(raw["audio_id"]),
            "source": SearchPlatformSource.kg.rawValue,
            "interval": formatDuration(milliseconds: intValue(raw["timelen"])),
            "img": "",
            "lrc": NSNull(),
            "hash": stringValue(raw["hash"]),
            "types": types,
            "_types": _types,
            "typeUrl": [:],
        ]

        let artist = stringValue(legacy["singer"]).nilIfEmpty
            ?? decodeEntity(stringValue(raw["name"])).components(separatedBy: " - ").first
            ?? ""
        let title = stringValue(legacy["name"])

        return makeSearchSong(
            id: "kg_\(stringValue(raw["audio_id"]))_\(stringValue(raw["hash"]))",
            source: .kg,
            title: title,
            artist: artist,
            album: stringValue(legacy["albumName"]),
            durationText: stringValue(legacy["interval"]),
            artworkURL: nil,
            qualities: qualities.map(\.0),
            legacy: legacy
        )
    }

    private func makeKugouSongFromHTMLPlaylist(raw: [String: Any]) -> SearchSong? {
        let audioID = stringValue(raw["audio_id"])
        let fileHash = stringValue(raw["hash"])
        guard !audioID.isEmpty, !fileHash.isEmpty else { return nil }

        var qualities: [(String, String?, String)] = []
        if let size = positiveSizeString(raw["filesize"]) {
            qualities.append(("128k", size, fileHash))
        }
        if let size = positiveSizeString(raw["filesize_320"]),
           let hash = stringValue(raw["hash_320"]).nilIfEmpty {
            qualities.append(("320k", size, hash))
        }
        if let size = positiveSizeString(raw["filesize_flac"]),
           let hash = stringValue(raw["hash_flac"]).nilIfEmpty {
            qualities.append(("flac", size, hash))
        }

        if let goods = raw["relate_goods"] as? [[String: Any]] {
            for item in goods {
                let level = intValue(item["level"])
                if level == 6,
                   let hash = stringValue(item["hash"]).nilIfEmpty,
                   !qualities.contains(where: { $0.0 == "flac24bit" }) {
                    qualities.append(("flac24bit", nil, hash))
                }
            }
        }

        let types = qualities.map { ["type": $0.0, "size": $0.1, "hash": $0.2] }
        let _types = Dictionary(uniqueKeysWithValues: qualities.map { ($0.0, ["size": $0.1 as Any, "hash": $0.2]) })
        let title = decodeEntity(stringValue(raw["songname"]))
        let artist = joinKugouAuthors(raw["authors"]).nilIfEmpty
            ?? decodeEntity(stringValue(raw["singername"]).replacingOccurrences(of: "、", with: "、"))
            ?? ""
        let albumName = decodeEntity(stringValue(raw["album_name"]))
        let artworkURL = (
            stringValue((raw["trans_param"] as? [String: Any])?["union_cover"]).nilIfEmpty
        )?.replacingOccurrences(of: "{size}", with: "480")

        let legacy: [String: Any] = [
            "singer": artist,
            "name": title,
            "albumName": albumName,
            "albumId": stringValue(raw["album_id"]),
            "songmid": audioID,
            "source": SearchPlatformSource.kg.rawValue,
            "interval": formatDuration(milliseconds: intValue(raw["duration"])),
            "img": artworkURL ?? "",
            "lrc": NSNull(),
            "hash": fileHash,
            "types": types,
            "_types": _types,
            "typeUrl": [:],
        ]

        return makeSearchSong(
            id: "kg_\(audioID)_\(fileHash)",
            source: .kg,
            title: title,
            artist: artist,
            album: albumName,
            durationText: stringValue(legacy["interval"]),
            artworkURL: artworkURL.flatMap(URL.init(string:)),
            qualities: qualities.map(\.0),
            legacy: legacy
        )
    }

    private func makeSearchSong(
        id: String,
        source: SearchPlatformSource,
        title: String,
        artist: String,
        album: String,
        durationText: String,
        artworkURL: URL?,
        qualities: [String],
        legacy: [String: Any]
    ) -> SearchSong? {
        guard let data = try? JSONSerialization.data(withJSONObject: legacy, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }

        return SearchSong(
            id: id,
            source: source,
            title: title,
            artist: artist,
            album: album,
            durationText: durationText,
            artworkURL: artworkURL,
            qualities: qualities,
            legacyInfoJSON: json
        )
    }

    private func flattenMiguPlaylists(_ contents: [[String: Any]], list: [Playlist] = [], ids: Set<String> = []) -> [Playlist] {
        var result = list
        var seen = ids

        for item in contents {
            if let nested = item["contents"] as? [[String: Any]] {
                result = flattenMiguPlaylists(nested, list: result, ids: seen)
                seen = Set(result.compactMap(\.sourceIdentifier))
                continue
            }

            guard stringValue(item["resType"]) == "2021" else { continue }
            let playlistID = stringValue(item["resId"])
            guard !playlistID.isEmpty, !seen.contains(playlistID) else { continue }
            seen.insert(playlistID)

            let description = stringValue(item["txt2"])
            if let playlist = makePlaylistSummary(
                source: .mg,
                playlistID: playlistID,
                title: stringValue(item["txt"]),
                curator: "咪咕歌单",
                description: description,
                categories: [SearchPlatformSource.mg.title],
                artworkURL: URL(string: stringValue(item["img"])),
                playCountText: nil,
                trackCount: nil,
                updatedLabel: ""
            ) {
                result.append(playlist)
            }
        }

        return result
    }

    private func makeMiguPlaylistFromItemList(raw: [String: Any]) -> Playlist? {
        let logEvent = raw["logEvent"] as? [String: Any] ?? [:]
        let barList = raw["barList"] as? [[String: Any]] ?? []
        return makePlaylistSummary(
            source: .mg,
            playlistID: stringValue(logEvent["contentId"]),
            title: stringValue(raw["title"]),
            curator: "咪咕歌单",
            description: "",
            categories: [SearchPlatformSource.mg.title],
            artworkURL: URL(string: stringValue(raw["imageUrl"])),
            playCountText: stringValue(barList.first?["title"]).nilIfEmpty,
            trackCount: nil,
            updatedLabel: ""
        )
    }

    private func playlistPalette(for source: SearchPlatformSource, seed: String) -> ArtworkPalette {
        let paletteOptions: [ArtworkPalette]
        switch source {
        case .kw:
            paletteOptions = [
                ArtworkPalette(colors: [Color(red: 0.92, green: 0.48, blue: 0.25), Color(red: 0.58, green: 0.21, blue: 0.12)], glow: Color(red: 1.00, green: 0.72, blue: 0.42), symbol: "music.quarternote.3", label: "Kuwo"),
                ArtworkPalette(colors: [Color(red: 0.18, green: 0.52, blue: 0.90), Color(red: 0.08, green: 0.16, blue: 0.38)], glow: Color(red: 0.50, green: 0.84, blue: 1.00), symbol: "headphones", label: "KW")
            ]
        case .kg:
            paletteOptions = [
                ArtworkPalette(colors: [Color(red: 0.19, green: 0.69, blue: 0.87), Color(red: 0.09, green: 0.18, blue: 0.34)], glow: Color(red: 0.58, green: 0.88, blue: 1.00), symbol: "waveform", label: "Kugou"),
                ArtworkPalette(colors: [Color(red: 0.98, green: 0.52, blue: 0.33), Color(red: 0.67, green: 0.22, blue: 0.15)], glow: Color(red: 1.00, green: 0.75, blue: 0.51), symbol: "music.note.list", label: "KG")
            ]
        case .tx:
            paletteOptions = [
                ArtworkPalette(colors: [Color(red: 0.12, green: 0.78, blue: 0.47), Color(red: 0.05, green: 0.28, blue: 0.18)], glow: Color(red: 0.55, green: 1.00, blue: 0.72), symbol: "q.circle.fill", label: "QQ"),
                ArtworkPalette(colors: [Color(red: 0.18, green: 0.37, blue: 0.92), Color(red: 0.08, green: 0.11, blue: 0.32)], glow: Color(red: 0.52, green: 0.72, blue: 1.00), symbol: "music.note.tv", label: "TX")
            ]
        case .wy:
            paletteOptions = [
                ArtworkPalette(colors: [Color(red: 0.90, green: 0.23, blue: 0.25), Color(red: 0.39, green: 0.05, blue: 0.11)], glow: Color(red: 1.00, green: 0.55, blue: 0.46), symbol: "record.circle.fill", label: "Netease"),
                ArtworkPalette(colors: [Color(red: 0.95, green: 0.46, blue: 0.34), Color(red: 0.47, green: 0.10, blue: 0.14)], glow: Color(red: 1.00, green: 0.66, blue: 0.54), symbol: "dot.radiowaves.left.and.right", label: "WY")
            ]
        case .mg:
            paletteOptions = [
                ArtworkPalette(colors: [Color(red: 0.98, green: 0.66, blue: 0.22), Color(red: 0.81, green: 0.29, blue: 0.17)], glow: Color(red: 1.00, green: 0.80, blue: 0.46), symbol: "star.fill", label: "Migu"),
                ArtworkPalette(colors: [Color(red: 0.87, green: 0.43, blue: 0.18), Color(red: 0.42, green: 0.14, blue: 0.08)], glow: Color(red: 1.00, green: 0.71, blue: 0.34), symbol: "sun.max.fill", label: "MG")
            ]
        case .all:
            paletteOptions = [
                ArtworkPalette(colors: [Color(red: 0.80, green: 0.40, blue: 0.40), Color(red: 0.20, green: 0.12, blue: 0.22)], glow: Color(red: 1.00, green: 0.58, blue: 0.46), symbol: "music.note", label: "List")
            ]
        }

        let index = abs(seed.hashValue) % max(paletteOptions.count, 1)
        return paletteOptions[index]
    }

    private func getJSON(_ urlString: String, headers: [String: String] = [:]) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: urlString)!)
        request.timeoutInterval = 15
        request.httpMethod = "GET"
        request.setValue("application/json,text/plain,*/*", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
            forHTTPHeaderField: "User-Agent"
        )
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try parseJSONObject(data)
    }

    private func getText(_ urlString: String, headers: [String: String] = [:]) async throws -> String {
        var request = URLRequest(url: URL(string: urlString)!)
        request.timeoutInterval = 15
        request.httpMethod = "GET"
        request.setValue(
            "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        guard let text = String(data: data, encoding: .utf8) else {
            throw MusicPlaylistError.badResponse("文本")
        }
        return text
    }

    private func validate(_ response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw MusicPlaylistError.badResponse("HTTP \(http.statusCode)")
        }
    }

    private func parseJSONObject(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MusicPlaylistError.badResponse("JSON")
        }
        return object
    }

    private func encodeJSONObject(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let text = String(data: data, encoding: .utf8) else {
            throw MusicPlaylistError.badResponse("JSON 编码")
        }
        return text
    }

    private func parseKugouHTMLSongList(_ html: String) throws -> [[String: Any]] {
        let pattern = #"global\.data = (\[.+?\]);"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let dataRange = Range(match.range(at: 1), in: html),
              let data = String(html[dataRange]).data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw MusicPlaylistError.badResponse("酷狗歌单详情")
        }
        return object
    }

    private func parseKugouHTMLInfo(_ html: String) -> (name: String?, pic: String?, desc: String?) {
        let infoPattern = #"global = \{[\s\S]+?name: "(.+?)"[\s\S]+?pic: "(.+?)"[\s\S]+?\};"#
        let descPrefix = #"<div class="pc_specail_text pc_singer_tab_content" id="specailIntroduceWrap">"#

        var name: String?
        var pic: String?
        if let regex = try? NSRegularExpression(pattern: infoPattern),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let nameRange = Range(match.range(at: 1), in: html),
           let picRange = Range(match.range(at: 2), in: html) {
            name = decodeEntity(String(html[nameRange]))
            pic = String(html[picRange])
        }

        var desc: String?
        if let startRange = html.range(of: descPrefix) {
            let after = html[startRange.upperBound...]
            if let endRange = after.range(of: "</div>") {
                desc = decodeEntity(String(after[..<endRange.lowerBound]))
            }
        }
        return (name, pic, desc)
    }

    private var miguHeaders: [String: String] {
        [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1",
            "Referer": "https://m.music.migu.cn/",
        ]
    }

    private func parseKuwoQualityInfo(_ text: String) -> [(String, String?)] {
        guard !text.isEmpty else { return [] }
        let pattern = #"level:(\w+),bitrate:(\d+),format:(\w+),size:([\w.]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges == 5,
                  let bitrateRange = Range(match.range(at: 2), in: text),
                  let sizeRange = Range(match.range(at: 4), in: text) else {
                return nil
            }
            let bitrate = String(text[bitrateRange])
            let size = String(text[sizeRange]).uppercased()
            switch bitrate {
            case "4000":
                return ("flac24bit", size)
            case "2000":
                return ("flac", size)
            case "320":
                return ("320k", size)
            case "128":
                return ("128k", size)
            default:
                return nil
            }
        }
    }

    private func positiveSizeString(_ value: Any?) -> String? {
        switch value {
        case let int as Int where int > 0:
            return formatSize(bytes: int)
        case let number as NSNumber where number.intValue > 0:
            return formatSize(bytes: number.intValue)
        case let string as String:
            let int = Int(string) ?? 0
            return int > 0 ? formatSize(bytes: int) : nil
        default:
            return nil
        }
    }

    private func stringValue(_ value: Any?) -> String {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case let value?:
            return String(describing: value)
        default:
            return ""
        }
    }

    private func intValue(_ value: Any?) -> Int {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string) ?? 0
        default:
            return 0
        }
    }

    private func parseDuration(_ value: String) -> TimeInterval {
        let parts = value.split(separator: ":").compactMap { Double($0) }
        guard !parts.isEmpty else { return 0 }
        return parts.reversed().enumerated().reduce(into: 0) { partialResult, item in
            partialResult += item.element * pow(60, Double(item.offset))
        }
    }

    private func formatDuration(seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let remain = max(seconds, 0) % 60
        return String(format: "%02d:%02d", minutes, remain)
    }

    private func formatDuration(milliseconds: Int) -> String {
        formatDuration(seconds: milliseconds / 1000)
    }

    private func formatMiguDuration(_ value: Any?) -> String {
        let number = intValue(value)
        if number <= 0 { return "00:00" }
        return number > 1000 ? formatDuration(milliseconds: number) : formatDuration(seconds: number)
    }

    private func formatSize(bytes: Int) -> String {
        let size = Double(bytes)
        if size > 1024 * 1024 * 1024 {
            return String(format: "%.2fG", size / 1024 / 1024 / 1024)
        }
        return String(format: "%.2fM", size / 1024 / 1024)
    }

    private func formatSinger(_ raw: String) -> String {
        raw.replacingOccurrences(of: "&", with: "、")
    }

    private func joinNames(_ raw: Any?) -> String {
        guard let array = raw as? [[String: Any]] else { return "" }
        let names = array.compactMap {
            stringValue($0["name"]).nilIfEmpty ?? stringValue($0["author_name"]).nilIfEmpty
        }
        return names.joined(separator: "、")
    }

    private func joinKugouAuthors(_ raw: Any?) -> String {
        guard let array = raw as? [[String: Any]] else { return "" }
        return array.compactMap {
            stringValue($0["singername"]).nilIfEmpty ?? stringValue($0["name"]).nilIfEmpty
        }
        .joined(separator: "、")
    }

    private func decodeEntity(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    private func decodeHTMLBreaks(_ text: String) -> String {
        decodeEntity(text)
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
    }

    private func excerpt(_ text: String, limit: Int) -> String {
        let compact = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard compact.count > limit else { return compact }
        return String(compact.prefix(limit)) + "…"
    }

    private func formatCount(_ value: Any?) -> String? {
        switch value {
        case let string as String where !string.isEmpty:
            if Int(string) != nil {
                return compactCount(Int(string) ?? 0)
            }
            return string
        case let int as Int:
            return compactCount(int)
        case let number as NSNumber:
            return compactCount(number.intValue)
        default:
            return nil
        }
    }

    private func compactCount(_ value: Int) -> String {
        guard value >= 10_000 else { return "\(value)" }
        let major = value / 10_000
        let minor = (value % 10_000) / 1_000
        return minor == 0 ? "\(major)万" : "\(major).\(minor)万"
    }

    private func dateLabel(fromUnixSeconds seconds: Int) -> String {
        guard seconds > 0 else { return "" }
        return dateLabel(from: Date(timeIntervalSince1970: TimeInterval(seconds)))
    }

    private func dateLabel(fromMilliseconds milliseconds: Int) -> String {
        guard milliseconds > 0 else { return "" }
        return dateLabel(from: Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000))
    }

    private func dateLabel(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func kugouSignature(params: String, platform: String) -> String {
        let secret = platform == "web"
            ? "NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt"
            : "OIlwieks28dk2k092lksi2UIkp"
        let joined = params
            .split(separator: "&")
            .map(String.init)
            .sorted()
            .joined()
        let raw = "\(secret)\(joined)\(secret)"
        return Insecure.MD5.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private struct KugouCollectionInfo {
    let userName: String
    let imageUrl: String
    let desc: String
    let name: String
    let total: Int
    let playCount: Any?
}

private extension String {
    var urlEscaped: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }

    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
