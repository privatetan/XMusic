//
//  MusicSearchService.swift
//  XMusic
//
//  Created by Codex on 2026/3/20.
//

import CryptoKit
import Foundation
#if canImport(CommonCrypto)
import CommonCrypto
#endif

struct MusicSearchService {
    func search(
        query: String,
        page: Int,
        source: SearchPlatformSource,
        allowedSources: [SearchPlatformSource]
    ) async throws -> SearchResponseBundle {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return SearchResponseBundle(
                result: SearchPageResult(source: source, list: [], total: 0, limit: 20, maxPage: 0),
                debugItems: []
            )
        }

        if source == .all {
            let activeSources = allowedSources.filter { $0 != .all }
            let reports = try await withThrowingTaskGroup(of: SearchDebugItem.self) { group in
                for source in activeSources {
                    group.addTask {
                        await buildDebugItem(query: normalizedQuery, page: page, source: source)
                    }
                }

                var items: [SearchDebugItem] = []
                for try await item in group {
                    items.append(item)
                }
                return items.sorted { $0.source.rawValue < $1.source.rawValue }
            }

            let results = reports.compactMap { report in
                report.pageResult
            }

            let merged = sortAllSourceResults(
                deduplicate(results.flatMap(\.list)),
                keyword: normalizedQuery
            )

            let maxPage = results.map(\.maxPage).max() ?? 0
            let total = results.map(\.total).max() ?? merged.count
            let limit = results.map(\.limit).max() ?? 20
            return SearchResponseBundle(
                result: SearchPageResult(source: .all, list: merged, total: total, limit: limit, maxPage: maxPage),
                debugItems: reports
            )
        }

        let item = await buildDebugItem(query: normalizedQuery, page: page, source: source)
        guard item.status != .error, let result = item.pageResult else {
            throw MusicSearchError.badResponse(item.message)
        }
        return SearchResponseBundle(result: result, debugItems: [item])
    }

    func findFallbackCandidates(
        for song: SearchSong,
        allowedSources: [SearchPlatformSource]
    ) async throws -> [SearchSong] {
        let fallbackSources = allowedSources.filter { $0 != .all && $0 != song.source }
        guard !fallbackSources.isEmpty else { return [] }

        let queryParts = [
            song.title.trimmingCharacters(in: .whitespacesAndNewlines),
            song.artist.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        .filter { !$0.isEmpty }
        let query = queryParts.joined(separator: " ")
        let normalizedQuery = query.isEmpty ? song.title : query
        let bundle = try await search(
            query: normalizedQuery,
            page: 1,
            source: .all,
            allowedSources: fallbackSources
        )

        let grouped = Dictionary(grouping: bundle.result.list.filter { $0.source != song.source }) { $0.source }
        var rankedSongs: [(song: SearchSong, score: Int)] = []

        for source in fallbackSources {
            guard let songs = grouped[source], !songs.isEmpty else { continue }
            let ranked = songs
                .filter { isViableFallback(target: song, candidate: $0) }
                .map { (song: $0, score: fallbackScore(target: song, candidate: $0)) }
                .sorted { lhs, rhs in
                    if lhs.score != rhs.score { return lhs.score > rhs.score }
                    return lhs.song.id < rhs.song.id
                }

            guard let best = ranked.first, best.score >= 480 else { continue }
            rankedSongs.append(best)
        }

        return rankedSongs
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.song.source.rawValue < rhs.song.source.rawValue
            }
            .map(\.song)
    }

    private func buildDebugItem(query: String, page: Int, source: SearchPlatformSource) async -> SearchDebugItem {
        do {
            let result = try await searchSingle(query: query, page: page, source: source)
            let message = result.list.isEmpty
                ? "请求成功，但这一页没有结果"
                : "请求成功"
            return SearchDebugItem(
                source: source,
                status: result.list.isEmpty ? .empty : .success,
                resultCount: result.list.count,
                total: result.total,
                page: page,
                maxPage: result.maxPage,
                message: message,
                pageResult: result
            )
        } catch {
            return SearchDebugItem(
                source: source,
                status: .error,
                resultCount: 0,
                total: 0,
                page: page,
                maxPage: 0,
                message: error.localizedDescription,
                pageResult: nil
            )
        }
    }

    private func searchSingle(query: String, page: Int, source: SearchPlatformSource) async throws -> SearchPageResult {
        let result: SearchPageResult
        switch source {
        case .kw:
            result = try await searchKuwo(query: query, page: page, limit: 30)
        case .kg:
            result = try await searchKugou(query: query, page: page, limit: 30)
        case .tx:
            result = try await searchQQ(query: query, page: page, limit: 50)
        case .wy:
            result = try await searchNetease(query: query, page: page, limit: 30)
        case .mg:
            result = try await searchMigu(query: query, page: page, limit: 20)
        case .all:
            throw MusicSearchError.unsupportedSource
        }
        return result
    }

    private func searchKuwo(query: String, page: Int, limit: Int) async throws -> SearchPageResult {
        let urlString = "https://search.kuwo.cn/r.s?client=kt&all=\(query.urlEscaped)&pn=\(page - 1)&rn=\(limit)&uid=794762570&ver=kwplayer_ar_9.2.2.1&vipver=1&show_copyright_off=1&newver=1&ft=music&cluster=0&strategy=2012&encoding=utf8&rformat=json&vermerge=1&mobi=1&issubtitle=1"
        let object = try await getJSON(urlString)
        guard let totalString = object["TOTAL"] as? String,
              let total = Int(totalString),
              let rawList = object["abslist"] as? [[String: Any]] else {
            throw MusicSearchError.badResponse("酷我")
        }

        let songs = rawList.compactMap(makeKuwoSong)
        return SearchPageResult(
            source: .kw,
            list: songs,
            total: total,
            limit: limit,
            maxPage: Int(ceil(Double(total) / Double(limit)))
        )
    }

    private func makeKuwoSong(raw: [String: Any]) -> SearchSong? {
        guard let musicRid = raw["MUSICRID"] as? String else { return nil }
        let songID = musicRid.replacingOccurrences(of: "MUSIC_", with: "")
        let qualityPairs = parseKuwoQualityInfo(raw["N_MINFO"] as? String ?? "")
        let types = qualityPairs.map { ["type": $0.0, "size": $0.1] }
        let _types = Dictionary(uniqueKeysWithValues: qualityPairs.map { ($0.0, ["size": $0.1]) })

        let legacy: [String: Any] = [
            "name": decodeEntity(raw["SONGNAME"] as? String ?? ""),
            "singer": formatSinger(raw["ARTIST"] as? String ?? ""),
            "source": SearchPlatformSource.kw.rawValue,
            "songmid": songID,
            "albumId": stringValue(raw["ALBUMID"]),
            "interval": formatDuration(seconds: Int(raw["DURATION"] as? String ?? "") ?? 0),
            "albumName": decodeEntity(raw["ALBUM"] as? String ?? ""),
            "lrc": NSNull(),
            "img": NSNull(),
            "types": types,
            "_types": _types,
            "typeUrl": [:],
        ]

        return makeSearchSong(
            id: "kw_\(songID)",
            source: .kw,
            title: legacy["name"] as? String ?? "",
            artist: legacy["singer"] as? String ?? "",
            album: legacy["albumName"] as? String ?? "",
            durationText: legacy["interval"] as? String ?? "",
            artworkURL: nil,
            qualities: qualityPairs.map(\.0),
            legacy: legacy
        )
    }

    private func searchKugou(query: String, page: Int, limit: Int) async throws -> SearchPageResult {
        let urlString = "https://songsearch.kugou.com/song_search_v2?keyword=\(query.urlEscaped)&page=\(page)&pagesize=\(limit)&userid=0&clientver=&platform=WebFilter&filter=2&iscorrection=1&privilege_filter=0&area_code=1"
        let object = try await getJSON(urlString)
        guard let data = object["data"] as? [String: Any],
              let total = data["total"] as? Int,
              let rawList = data["lists"] as? [[String: Any]] else {
            throw MusicSearchError.badResponse("酷狗")
        }

        var songs: [SearchSong] = []
        var ids = Set<String>()
        for item in rawList {
            if let song = makeKugouSong(raw: item), ids.insert(song.id).inserted {
                songs.append(song)
            }
            if let groupItems = item["Grp"] as? [[String: Any]] {
                for child in groupItems {
                    if let song = makeKugouSong(raw: child), ids.insert(song.id).inserted {
                        songs.append(song)
                    }
                }
            }
        }

        return SearchPageResult(
            source: .kg,
            list: songs,
            total: total,
            limit: limit,
            maxPage: Int(ceil(Double(total) / Double(limit)))
        )
    }

    private func makeKugouSong(raw: [String: Any]) -> SearchSong? {
        guard let audioID = stringValue(raw["Audioid"]).nilIfEmpty,
              let fileHash = raw["FileHash"] as? String else { return nil }

        var qualities: [(String, String?, String)] = []

        if let size = positiveSizeString(raw["FileSize"]) {
            qualities.append(("128k", size, fileHash))
        }
        if let size = positiveSizeString(raw["HQFileSize"]),
           let hash = raw["HQFileHash"] as? String {
            qualities.append(("320k", size, hash))
        }
        if let size = positiveSizeString(raw["SQFileSize"]),
           let hash = raw["SQFileHash"] as? String {
            qualities.append(("flac", size, hash))
        }
        if let size = positiveSizeString(raw["ResFileSize"]),
           let hash = raw["ResFileHash"] as? String {
            qualities.append(("flac24bit", size, hash))
        }

        let types = qualities.map { ["type": $0.0, "size": $0.1, "hash": $0.2] }
        let _types = Dictionary(uniqueKeysWithValues: qualities.map { ($0.0, ["size": $0.1, "hash": $0.2]) })

        let legacy: [String: Any] = [
            "name": decodeEntity(raw["SongName"] as? String ?? ""),
            "singer": formatSingerList(raw["Singers"]),
            "albumName": decodeEntity(raw["AlbumName"] as? String ?? ""),
            "albumId": stringValue(raw["AlbumID"]),
            "songmid": audioID,
            "source": SearchPlatformSource.kg.rawValue,
            "interval": formatDuration(seconds: raw["Duration"] as? Int ?? 0),
            "_interval": raw["Duration"] as? Int ?? 0,
            "img": NSNull(),
            "lrc": NSNull(),
            "hash": fileHash,
            "types": types,
            "_types": _types,
            "typeUrl": [:],
        ]

        return makeSearchSong(
            id: "\(audioID)_\(fileHash)",
            source: .kg,
            title: legacy["name"] as? String ?? "",
            artist: legacy["singer"] as? String ?? "",
            album: legacy["albumName"] as? String ?? "",
            durationText: legacy["interval"] as? String ?? "",
            artworkURL: nil,
            qualities: qualities.map(\.0),
            legacy: legacy
        )
    }

    private func searchQQ(query: String, page: Int, limit: Int) async throws -> SearchPageResult {
        let body: [String: Any] = [
            "comm": [
                "ct": "11",
                "cv": "14090508",
                "v": "14090508",
                "tmeAppID": "qqmusic",
                "phonetype": "EBG-AN10",
                "deviceScore": "553.47",
                "devicelevel": "50",
                "newdevicelevel": "20",
                "rom": "HuaWei/EMOTION/EmotionUI_14.2.0",
                "os_ver": "12",
                "OpenUDID": "0",
                "OpenUDID2": "0",
                "QIMEI36": "0",
                "udid": "0",
                "chid": "0",
                "aid": "0",
                "oaid": "0",
                "taid": "0",
                "tid": "0",
                "wid": "0",
                "uid": "0",
                "sid": "0",
                "modeSwitch": "6",
                "teenMode": "0",
                "ui_mode": "2",
                "nettype": "1020",
                "v4ip": "",
            ],
            "req": [
                "module": "music.search.SearchCgiService",
                "method": "DoSearchForQQMusicMobile",
                "param": [
                    "search_type": 0,
                    "query": query,
                    "page_num": page,
                    "num_per_page": limit,
                    "highlight": 0,
                    "nqc_flag": 0,
                    "multi_zhida": 0,
                    "cat": 2,
                    "grp": 1,
                    "sin": 0,
                    "sem": 0,
                ],
            ],
        ]

        let object = try await postJSON(
            "https://u.y.qq.com/cgi-bin/musicu.fcg",
            headers: ["User-Agent": "QQMusic 14090508(android 12)"],
            body: body
        )

        guard let req = object["req"] as? [String: Any],
              let code = req["code"] as? Int,
              code == 0,
              let data = req["data"] as? [String: Any],
              let meta = data["meta"] as? [String: Any],
              let total = meta["estimate_sum"] as? Int,
              let body = data["body"] as? [String: Any],
              let itemSongs = body["item_song"] as? [[String: Any]] else {
            throw MusicSearchError.badResponse("QQ 音乐")
        }

        let songs = itemSongs.compactMap(makeQQSong)
        return SearchPageResult(
            source: .tx,
            list: songs,
            total: total,
            limit: limit,
            maxPage: Int(ceil(Double(total) / Double(limit)))
        )
    }

    private func makeQQSong(raw: [String: Any]) -> SearchSong? {
        guard let file = raw["file"] as? [String: Any],
              let mediaMid = file["media_mid"] as? String,
              !mediaMid.isEmpty,
              let songMid = raw["mid"] as? String else {
            return nil
        }

        var qualities: [(String, String?)] = []
        if let size = positiveSizeString(file["size_128mp3"]) { qualities.append(("128k", size)) }
        if let size = positiveSizeString(file["size_320mp3"]) { qualities.append(("320k", size)) }
        if let size = positiveSizeString(file["size_flac"]) { qualities.append(("flac", size)) }
        if let size = positiveSizeString(file["size_hires"]) { qualities.append(("flac24bit", size)) }

        let types = qualities.map { ["type": $0.0, "size": $0.1] }
        let _types = Dictionary(uniqueKeysWithValues: qualities.map { ($0.0, ["size": $0.1]) })

        let album = raw["album"] as? [String: Any]
        let albumMid = album?["mid"] as? String ?? ""
        let albumName = album?["name"] as? String ?? ""
        let artwork = albumMid.isEmpty ? nil : URL(string: "https://y.gtimg.cn/music/photo_new/T002R500x500M000\(albumMid).jpg")

        let legacy: [String: Any] = [
            "singer": formatSingerList(raw["singer"]),
            "name": "\(raw["name"] as? String ?? "")\(raw["title_extra"] as? String ?? "")",
            "albumName": albumName,
            "albumId": albumMid,
            "source": SearchPlatformSource.tx.rawValue,
            "interval": formatDuration(seconds: raw["interval"] as? Int ?? 0),
            "songId": stringValue(raw["id"]),
            "albumMid": albumMid,
            "strMediaMid": mediaMid,
            "songmid": songMid,
            "img": artwork?.absoluteString ?? "",
            "types": types,
            "_types": _types,
            "typeUrl": [:],
        ]

        return makeSearchSong(
            id: "tx_\(songMid)",
            source: .tx,
            title: legacy["name"] as? String ?? "",
            artist: legacy["singer"] as? String ?? "",
            album: albumName,
            durationText: legacy["interval"] as? String ?? "",
            artworkURL: artwork,
            qualities: qualities.map(\.0),
            legacy: legacy
        )
    }

    private func searchNetease(query: String, page: Int, limit: Int) async throws -> SearchPageResult {
        let payload: [String: Any] = [
            "keyword": query,
            "needCorrect": "1",
            "channel": "typing",
            "offset": limit * (page - 1),
            "scene": "normal",
            "total": page == 1,
            "limit": limit,
        ]

        let params = try makeNeteaseEapiParams(url: "/api/search/song/list/page", body: payload)
        let object = try await postForm(
            "https://interface.music.163.com/eapi/batch",
            headers: [
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36",
                "origin": "https://music.163.com",
            ],
            form: params
        )

        guard let data = object["data"] as? [String: Any],
              let resources = data["resources"] as? [[String: Any]] else {
            throw MusicSearchError.badResponse("网易云")
        }

        let songs = resources.compactMap(makeNeteaseSong)
        let total = data["totalCount"] as? Int ?? songs.count
        return SearchPageResult(
            source: .wy,
            list: songs,
            total: total,
            limit: limit,
            maxPage: Int(ceil(Double(max(total, 1)) / Double(limit)))
        )
    }

    private func makeNeteaseSong(raw: [String: Any]) -> SearchSong? {
        guard let baseInfo = (raw["baseInfo"] as? [String: Any])?["simpleSongData"] as? [String: Any],
              let songID = stringValue(baseInfo["id"]).nilIfEmpty else { return nil }

        let privilege = baseInfo["privilege"] as? [String: Any] ?? [:]
        let maxBrLevel = privilege["maxBrLevel"] as? String ?? ""
        let maxBr = privilege["maxbr"] as? Int ?? 0
        var qualities: [(String, String?)] = []

        if maxBrLevel == "hires",
           let hr = baseInfo["hr"] as? [String: Any],
           let size = positiveSizeString(hr["size"]) {
            qualities.append(("flac24bit", size))
        }
        if maxBr >= 999_000,
           let sq = baseInfo["sq"] as? [String: Any],
           let size = positiveSizeString(sq["size"]) {
            qualities.append(("flac", size))
        }
        if maxBr >= 320_000,
           let h = baseInfo["h"] as? [String: Any],
           let size = positiveSizeString(h["size"]) {
            qualities.append(("320k", size))
        }
        if maxBr >= 128_000,
           let l = baseInfo["l"] as? [String: Any],
           let size = positiveSizeString(l["size"]) {
            qualities.append(("128k", size))
        }

        let types = qualities.reversed().map { ["type": $0.0, "size": $0.1] }
        let _types = Dictionary(uniqueKeysWithValues: qualities.map { ($0.0, ["size": $0.1]) })
        let album = baseInfo["al"] as? [String: Any] ?? [:]
        let picture = URL(string: album["picUrl"] as? String ?? "")

        let legacy: [String: Any] = [
            "singer": joinNames(baseInfo["ar"]),
            "name": baseInfo["name"] as? String ?? "",
            "albumName": album["name"] as? String ?? "",
            "albumId": stringValue(album["id"]),
            "source": SearchPlatformSource.wy.rawValue,
            "interval": formatDuration(milliseconds: baseInfo["dt"] as? Int ?? 0),
            "songmid": songID,
            "img": picture?.absoluteString ?? "",
            "lrc": NSNull(),
            "types": types,
            "_types": _types,
            "typeUrl": [:],
        ]

        return makeSearchSong(
            id: "wy_\(songID)",
            source: .wy,
            title: legacy["name"] as? String ?? "",
            artist: legacy["singer"] as? String ?? "",
            album: legacy["albumName"] as? String ?? "",
            durationText: legacy["interval"] as? String ?? "",
            artworkURL: picture,
            qualities: qualities.map(\.0),
            legacy: legacy
        )
    }

    private func searchMigu(query: String, page: Int, limit: Int) async throws -> SearchPageResult {
        let time = String(Int(Date().timeIntervalSince1970 * 1000))
        let signature = createMiguSignature(time: time, text: query)
        let urlString = "https://jadeite.migu.cn/music_search/v3/search/searchAll?isCorrect=0&isCopyright=1&searchSwitch=%7B%22song%22%3A1%2C%22album%22%3A0%2C%22singer%22%3A0%2C%22tagSong%22%3A1%2C%22mvSong%22%3A0%2C%22bestShow%22%3A1%2C%22songlist%22%3A0%2C%22lyricSong%22%3A0%7D&pageSize=\(limit)&text=\(query.urlEscaped)&pageNo=\(page)&sort=0&sid=USS"
        let object = try await getJSON(
            urlString,
            headers: [
                "uiVersion": "A_music_3.6.1",
                "deviceId": signature.deviceID,
                "timestamp": time,
                "sign": signature.sign,
                "channel": "0146921",
                "User-Agent": "Mozilla/5.0 (Linux; Android 11.0.0; MI 11 Build/OPR1.170623.032) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30",
            ]
        )

        guard (object["code"] as? String) == "000000",
              let songResultData = object["songResultData"] as? [String: Any],
              let rawLists = songResultData["resultList"] as? [[[String: Any]]] else {
            throw MusicSearchError.badResponse("咪咕")
        }

        let songs = rawLists.flatMap { $0 }.compactMap(makeMiguSong)
        let total = Int(songResultData["totalCount"] as? String ?? "") ?? songs.count
        return SearchPageResult(
            source: .mg,
            list: deduplicate(songs),
            total: total,
            limit: limit,
            maxPage: Int(ceil(Double(max(total, 1)) / Double(limit)))
        )
    }

    private func makeMiguSong(raw: [String: Any]) -> SearchSong? {
        guard let songID = stringValue(raw["songId"]).nilIfEmpty,
              let copyrightID = stringValue(raw["copyrightId"]).nilIfEmpty else { return nil }

        var qualities: [(String, String?)] = []
        if let audioFormats = raw["audioFormats"] as? [[String: Any]] {
            for format in audioFormats {
                let type = format["formatType"] as? String ?? ""
                let sizeValue = format["asize"] ?? format["isize"]
                let size = positiveSizeString(sizeValue)
                switch type {
                case "PQ":
                    qualities.append(("128k", size))
                case "HQ":
                    qualities.append(("320k", size))
                case "SQ":
                    qualities.append(("flac", size))
                case "ZQ24":
                    qualities.append(("flac24bit", size))
                default:
                    break
                }
            }
        }

        let types = qualities.map { ["type": $0.0, "size": $0.1] }
        let _types = Dictionary(uniqueKeysWithValues: qualities.map { ($0.0, ["size": $0.1]) })
        var artworkURL: URL?
        if let img = (raw["img3"] as? String) ?? (raw["img2"] as? String) ?? (raw["img1"] as? String) {
            let url = img.hasPrefix("http") ? img : "http://d.musicapp.migu.cn\(img)"
            artworkURL = URL(string: url)
        }

        let legacy: [String: Any] = [
            "singer": joinNames(raw["singerList"]),
            "name": raw["name"] as? String ?? "",
            "albumName": raw["album"] as? String ?? "",
            "albumId": stringValue(raw["albumId"]),
            "songmid": songID,
            "copyrightId": copyrightID,
            "source": SearchPlatformSource.mg.rawValue,
            "interval": formatMiguDuration(raw["duration"]),
            "img": artworkURL?.absoluteString ?? "",
            "lrcUrl": raw["lrcUrl"] as? String ?? "",
            "mrcUrl": raw["mrcurl"] as? String ?? "",
            "trcUrl": raw["trcUrl"] as? String ?? "",
            "types": types,
            "_types": _types,
            "typeUrl": [:],
        ]

        return makeSearchSong(
            id: "mg_\(copyrightID)",
            source: .mg,
            title: legacy["name"] as? String ?? "",
            artist: legacy["singer"] as? String ?? "",
            album: legacy["albumName"] as? String ?? "",
            durationText: legacy["interval"] as? String ?? "",
            artworkURL: artworkURL,
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
              let json = String(data: data, encoding: .utf8) else { return nil }

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

    private func postJSON(_ urlString: String, headers: [String: String] = [:], body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: urlString)!)
        request.timeoutInterval = 15
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json,text/plain,*/*", forHTTPHeaderField: "Accept")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try parseJSONObject(data)
    }

    private func postForm(_ urlString: String, headers: [String: String] = [:], form: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: urlString)!)
        request.timeoutInterval = 15
        request.httpMethod = "POST"
        let body = form.map { key, value in
            "\(key.urlEscaped)=\(value.urlEscaped)"
        }
        .joined(separator: "&")
        request.httpBody = Data(body.utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json,text/plain,*/*", forHTTPHeaderField: "Accept")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try parseJSONObject(data)
    }

    private func validate(_ response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw MusicSearchError.badResponse("HTTP \(http.statusCode)")
        }
    }

    private func parseJSONObject(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MusicSearchError.badResponse("JSON")
        }
        return object
    }

    private func parseKuwoQualityInfo(_ text: String) -> [(String, String?)] {
        guard !text.isEmpty else { return [] }
        let pattern = #"level:(\w+),bitrate:(\d+),format:(\w+),size:([\w.]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        return matches.compactMap { match in
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

    private func formatDuration(seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let remain = max(seconds, 0) % 60
        return String(format: "%02d:%02d", minutes, remain)
    }

    private func formatDuration(milliseconds: Int) -> String {
        formatDuration(seconds: milliseconds / 1000)
    }

    private func formatMiguDuration(_ value: Any?) -> String {
        let number: Int
        switch value {
        case let int as Int:
            number = int
        case let numberValue as NSNumber:
            number = numberValue.intValue
        case let string as String:
            number = Int(string) ?? 0
        default:
            number = 0
        }
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

    private func formatSingerList(_ raw: Any?) -> String {
        guard let array = raw as? [[String: Any]] else { return "" }
        return array.compactMap { $0["name"] as? String }.joined(separator: "、")
    }

    private func joinNames(_ raw: Any?) -> String {
        guard let array = raw as? [[String: Any]] else { return "" }
        return array.compactMap { $0["name"] as? String }.joined(separator: "、")
    }

    private func decodeEntity(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    private func score(query: String, song: SearchSong) -> Int {
        let normalizedQuery = normalize(query)
        let title = normalize(song.title)
        let artist = normalize(song.artist)
        let combo = normalize("\(song.title) \(song.artist)")

        if title == normalizedQuery { return 1000 }
        if combo.hasPrefix(normalizedQuery) { return 900 }
        if title.hasPrefix(normalizedQuery) { return 850 }
        if title.contains(normalizedQuery) { return 700 }
        if artist.contains(normalizedQuery) { return 550 }
        if combo.contains(normalizedQuery) { return 500 }
        return 100
    }

    private func sortAllSourceResults(_ songs: [SearchSong], keyword: String) -> [SearchSong] {
        songs.sorted { lhs, rhs in
            let lhsScore = lxSimilarity(keyword, "\(lhs.title) \(lhs.artist)")
            let rhsScore = lxSimilarity(keyword, "\(rhs.title) \(rhs.artist)")
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return lhs.id < rhs.id
        }
    }

    private func lxSimilarity(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }

        var short = Array(a)
        var long = Array(b)
        if short.count > long.count {
            swap(&short, &long)
        }

        let shortCount = short.count
        let longCount = long.count
        var matrix = Array(0...longCount)

        for i in 1...shortCount {
            let character = short[i - 1]
            var leftTop = matrix[0]
            matrix[0] += 1

            for j in 1...longCount {
                let temp = min(
                    matrix[j] + 1,
                    matrix[j - 1] + 1,
                    leftTop + (character == long[j - 1] ? 0 : 1)
                )
                leftTop = matrix[j]
                matrix[j] = temp
            }
        }

        return 1 - (Double(matrix[longCount]) / Double(max(longCount, 1)))
    }

    private func fallbackScore(target: SearchSong, candidate: SearchSong) -> Int {
        let targetTitle = normalize(target.title)
        let candidateTitle = normalize(candidate.title)
        let targetArtist = normalize(target.artist)
        let candidateArtist = normalize(candidate.artist)
        let targetAlbum = normalize(target.album)
        let candidateAlbum = normalize(candidate.album)

        var score = 0

        if !targetTitle.isEmpty, !candidateTitle.isEmpty {
            if targetTitle == candidateTitle {
                score += 600
            } else if targetTitle.contains(candidateTitle) || candidateTitle.contains(targetTitle) {
                score += 420
            }
        }

        if !targetArtist.isEmpty, !candidateArtist.isEmpty {
            if targetArtist == candidateArtist {
                score += 300
            } else if targetArtist.contains(candidateArtist) || candidateArtist.contains(targetArtist) {
                score += 180
            }
        }

        if !targetAlbum.isEmpty, !candidateAlbum.isEmpty {
            if targetAlbum == candidateAlbum {
                score += 80
            } else if targetAlbum.contains(candidateAlbum) || candidateAlbum.contains(targetAlbum) {
                score += 40
            }
        }

        let targetDuration = parseDuration(song: target)
        let candidateDuration = parseDuration(song: candidate)
        if targetDuration > 0, candidateDuration > 0 {
            let diff = abs(targetDuration - candidateDuration)
            switch diff {
            case 0:
                score += 140
            case 1...3:
                score += 100
            case 4...6:
                score += 60
            default:
                score -= 160
            }
        }

        if candidate.qualities.isEmpty {
            score -= 120
        } else if candidate.qualities.contains(target.preferredQuality) {
            score += 40
        }

        return score
    }

    private func isViableFallback(target: SearchSong, candidate: SearchSong) -> Bool {
        let targetTitle = normalize(target.title)
        let candidateTitle = normalize(candidate.title)
        guard !targetTitle.isEmpty, !candidateTitle.isEmpty else { return false }

        let titleMatches = targetTitle == candidateTitle
            || targetTitle.contains(candidateTitle)
            || candidateTitle.contains(targetTitle)
        guard titleMatches else { return false }

        let targetArtist = normalize(target.artist)
        let candidateArtist = normalize(candidate.artist)
        if !targetArtist.isEmpty, !candidateArtist.isEmpty {
            let artistMatches = targetArtist == candidateArtist
                || targetArtist.contains(candidateArtist)
                || candidateArtist.contains(targetArtist)
            if !artistMatches { return false }
        }

        let targetDuration = parseDuration(song: target)
        let candidateDuration = parseDuration(song: candidate)
        if targetDuration > 0, candidateDuration > 0 {
            let diff = abs(targetDuration - candidateDuration)
            if diff > 15 { return false }
        }

        return true
    }

    private func parseDuration(song: SearchSong) -> Int {
        let parts = song.durationText.split(separator: ":").compactMap { Int($0) }
        guard !parts.isEmpty else { return 0 }
        return parts.reversed().enumerated().reduce(into: 0) { partialResult, item in
            partialResult += item.element * Int(pow(60.0, Double(item.offset)))
        }
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
    }

    private func deduplicate(_ songs: [SearchSong]) -> [SearchSong] {
        var seen = Set<String>()
        return songs.filter { seen.insert($0.id).inserted }
    }

    private func createMiguSignature(time: String, text: String) -> (sign: String, deviceID: String) {
        let deviceID = "963B7AA0D21511ED807EE5846EC87D20"
        let signatureMD5 = "6cdc72a439cef99a3418d2a78aa28c73"
        let raw = "\(text)\(signatureMD5)yyapp2d16148780a1dcc7408e06336b98cfd50\(deviceID)\(time)"
        let sign = Insecure.MD5.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
        return (sign, deviceID)
    }

    private func makeNeteaseEapiParams(url: String, body: [String: Any]) throws -> [String: String] {
        let textData = try JSONSerialization.data(withJSONObject: body)
        let text = String(decoding: textData, as: UTF8.self)
        let message = "nobody\(url)use\(text)md5forencrypt"
        let digest = Insecure.MD5.hash(data: Data(message.utf8)).map { String(format: "%02x", $0) }.joined()
        let data = "\(url)-36cd479b6b5-\(text)-36cd479b6b5-\(digest)"

        let key = Data("e82ckenh8dichen8".utf8)
        let encrypted = try aesEncryptECBPKCS7(data: Data(data.utf8), key: key)
        return ["params": encrypted.map { String(format: "%02X", $0) }.joined()]
    }

    private func aesEncryptECBPKCS7(data: Data, key: Data) throws -> Data {
        #if canImport(CommonCrypto)
        var outputLength = 0
        let outputCount = data.count + kCCBlockSizeAES128
        var output = Data(count: outputCount)

        let status = output.withUnsafeMutableBytes { outputBytes in
            data.withUnsafeBytes { dataBytes in
                key.withUnsafeBytes { keyBytes in
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionECBMode | kCCOptionPKCS7Padding),
                        keyBytes.baseAddress,
                        key.count,
                        nil,
                        dataBytes.baseAddress,
                        data.count,
                        outputBytes.baseAddress,
                        outputCount,
                        &outputLength
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw MusicSearchError.badResponse("网易加密")
        }

        output.removeSubrange(outputLength..<output.count)
        return output
        #else
        throw MusicSearchError.badResponse("网易加密")
        #endif
    }
}

private extension String {
    var urlEscaped: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
