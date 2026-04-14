import Compression
import CryptoKit
import Foundation
#if canImport(CommonCrypto)
import CommonCrypto
#endif

actor BuiltInLyricService {
    static let shared = BuiltInLyricService()

    private var cache: [String: MusicSourceLyricResult] = [:]

    func resolveLyric(for song: SearchSong) async throws -> MusicSourceLyricResult {
        if let cached = cache[song.id] {
            return cached
        }

        let result: MusicSourceLyricResult
        switch song.source {
        case .kw:
            result = try await fetchKuwo(song)
        case .kg:
            result = try await fetchKugou(song)
        case .tx:
            result = try await fetchQQ(song)
        case .wy:
            result = try await fetchNetease(song)
        case .mg:
            result = try await fetchMigu(song)
        case .all:
            throw BuiltInLyricError.unsupportedSource
        }

        cache[song.id] = result
        return result
    }

    private func fetchKuwo(_ song: SearchSong) async throws -> MusicSourceLyricResult {
        let legacy = try parseLegacy(song.legacyInfoJSON)
        let songID = stringValue(legacy["songmid"])
        guard !songID.isEmpty else { throw BuiltInLyricError.invalidSongInfo("酷我缺少 songmid") }

        let query = buildKuwoLyricQuery(songID: songID, includeLyricX: false)
        let url = "http://newlyric.kuwo.cn/newlyric.lrc?\(query)"
        let data = try await getData(url, headers: [
            "User-Agent": "Mozilla/5.0",
        ])
        guard data.count > 10,
              String(decoding: data.prefix(10), as: UTF8.self) == "tp=content",
              let range = data.range(of: Data("\r\n\r\n".utf8)),
              let inflated = inflateZlib(Data(data[range.upperBound...])),
              let lrc = decodeGB18030(inflated),
              !lrc.isEmpty else {
            throw BuiltInLyricError.badResponse("酷我歌词")
        }

        let parsed = parseDuplicatedTimedLyrics(lrc)
        guard hasTimedLyric(parsed.lyric) else {
            throw BuiltInLyricError.badResponse("酷我歌词为空")
        }

        return parsed
    }

    private func fetchKugou(_ song: SearchSong) async throws -> MusicSourceLyricResult {
        let legacy = try parseLegacy(song.legacyInfoJSON)
        let name = stringValue(legacy["name"])
        let hash = stringValue(legacy["hash"])
        let rawDuration = stringValue(legacy["_interval"])
        let duration = rawDuration.isEmpty ? seconds(from: stringValue(legacy["interval"])) : rawDuration
        guard !name.isEmpty, !hash.isEmpty, !duration.isEmpty else {
            throw BuiltInLyricError.invalidSongInfo("酷狗缺少 name/hash/interval")
        }

        let keyword = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let searchURL = "http://lyrics.kugou.com/search?ver=1&man=yes&client=pc&keyword=\(keyword)&hash=\(hash)&timelength=\(duration)&lrctxt=1"
        let search = try await getJSON(searchURL, headers: kugouHeaders)
        guard let candidates = search["candidates"] as? [[String: Any]],
              let first = candidates.first else {
            throw BuiltInLyricError.badResponse("酷狗歌词候选为空")
        }

        let id = stringValue(first["id"])
        let accessKey = stringValue(first["accesskey"])
        let format = ((first["krctype"] as? Int) == 1 && (first["contenttype"] as? Int) != 1) ? "krc" : "lrc"
        guard !id.isEmpty, !accessKey.isEmpty else {
            throw BuiltInLyricError.badResponse("酷狗歌词候选无效")
        }

        let downloadURL = "http://lyrics.kugou.com/download?ver=1&client=pc&id=\(id)&accesskey=\(accessKey)&fmt=\(format)&charset=utf8"
        let payload = try await getJSON(downloadURL, headers: kugouHeaders)
        let fmt = stringValue(payload["fmt"]).lowercased()

        switch fmt {
        case "krc":
            let content = stringValue(payload["content"])
            guard !content.isEmpty else { throw BuiltInLyricError.badResponse("酷狗 KRC 为空") }
            return try decodeKugouKrc(content)
        case "lrc":
            let content = stringValue(payload["content"])
            guard let data = Data(base64Encoded: content),
                  let text = String(data: data, encoding: .utf8),
                  hasTimedLyric(text) else {
                throw BuiltInLyricError.badResponse("酷狗 LRC 无效")
            }
            return MusicSourceLyricResult(lyric: text, tlyric: nil, rlyric: nil, lxlyric: nil)
        default:
            throw BuiltInLyricError.badResponse("未知酷狗歌词格式 \(fmt)")
        }
    }

    private func fetchQQ(_ song: SearchSong) async throws -> MusicSourceLyricResult {
        let legacy = try parseLegacy(song.legacyInfoJSON)
        let songMid = stringValue(legacy["songmid"])
        guard !songMid.isEmpty else { throw BuiltInLyricError.invalidSongInfo("QQ 缺少 songmid") }

        let url = "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=\(songMid)&g_tk=5381&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8&platform=yqq"
        let object = try await getJSON(url, headers: [
            "Referer": "https://y.qq.com/portal/player.html",
            "User-Agent": "Mozilla/5.0",
        ])

        let lyric = try decodeQQBase64Lyric(stringValue(object["lyric"]))
        let tlyric = try decodeQQBase64Lyric(stringValue(object["trans"]))

        guard hasTimedLyric(lyric) else {
            throw BuiltInLyricError.badResponse("QQ 歌词为空")
        }

        return MusicSourceLyricResult(
            lyric: lyric,
            tlyric: nilIfBlank(tlyric),
            rlyric: nil,
            lxlyric: nil
        )
    }

    private func fetchNetease(_ song: SearchSong) async throws -> MusicSourceLyricResult {
        let legacy = try parseLegacy(song.legacyInfoJSON)
        let songID = stringValue(legacy["songmid"])
        guard !songID.isEmpty else { throw BuiltInLyricError.invalidSongInfo("网易云缺少 songmid") }

        let params = try makeNeteaseEapiParams(url: "/api/song/lyric/v1", body: [
            "id": songID,
            "cp": false,
            "tv": 0,
            "lv": 0,
            "rv": 0,
            "kv": 0,
            "yv": 0,
            "ytv": 0,
            "yrv": 0,
        ])

        let object = try await postForm(
            "https://interface.music.163.com/eapi/song/lyric/v1",
            headers: [
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36",
                "origin": "https://music.163.com",
            ],
            form: params
        )

        let lyric = normalizeLineEndings((object["lrc"] as? [String: Any])?["lyric"] as? String ?? "")
        let tlyric = normalizeLineEndings((object["tlyric"] as? [String: Any])?["lyric"] as? String ?? "")
        let rlyric = normalizeLineEndings((object["romalrc"] as? [String: Any])?["lyric"] as? String ?? "")

        guard hasTimedLyric(lyric) else {
            throw BuiltInLyricError.badResponse("网易云歌词为空")
        }

        return MusicSourceLyricResult(
            lyric: lyric,
            tlyric: nilIfBlank(tlyric),
            rlyric: nilIfBlank(rlyric),
            lxlyric: nil
        )
    }

    private func fetchMigu(_ song: SearchSong) async throws -> MusicSourceLyricResult {
        let legacy = try parseLegacy(song.legacyInfoJSON)
        let lrcURL = stringValue(legacy["lrcUrl"])
        let trcURL = stringValue(legacy["trcUrl"])

        guard !lrcURL.isEmpty else {
            throw BuiltInLyricError.invalidSongInfo("咪咕缺少 lrcUrl")
        }

        let lyric = try await getText(lrcURL, headers: miguHeaders)
        let tlyric = trcURL.isEmpty ? nil : try? await getText(trcURL, headers: miguHeaders)

        guard hasTimedLyric(lyric) else {
            throw BuiltInLyricError.badResponse("咪咕歌词为空")
        }

        return MusicSourceLyricResult(
            lyric: normalizeLineEndings(lyric),
            tlyric: nilIfBlank(tlyric.map(normalizeLineEndings)),
            rlyric: nil,
            lxlyric: nil
        )
    }

    private var kugouHeaders: [String: String] {
        [
            "KG-RC": "1",
            "KG-THash": "expand_search_manager.cpp:852736169:451",
            "User-Agent": "KuGou2012-9020-ExpandSearchManager",
        ]
    }

    private var miguHeaders: [String: String] {
        [
            "Referer": "https://app.c.nf.migu.cn/",
            "User-Agent": "Mozilla/5.0 (Linux; Android 5.1.1; Nexus 6 Build/LYZ28E) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Mobile Safari/537.36",
            "channel": "0146921",
        ]
    }

    private func buildKuwoLyricQuery(songID: String, includeLyricX: Bool) -> String {
        let key = Array("yeelion".utf8)
        var params = "user=12345,web,web,web&requester=localhost&req=1&rid=MUSIC_\(songID)"
        if includeLyricX {
            params += "&lrcx=1"
        }

        let bytes = Array(params.utf8)
        let output = zip(bytes.indices, bytes).map { index, byte in
            byte ^ key[index % key.count]
        }
        return Data(output).base64EncodedString()
    }

    private func decodeKugouKrc(_ content: String) throws -> MusicSourceLyricResult {
        let key: [UInt8] = [0x40, 0x47, 0x61, 0x77, 0x5e, 0x32, 0x74, 0x47, 0x51, 0x36, 0x31, 0x2d, 0xce, 0xd2, 0x6e, 0x69]
        guard var data = Data(base64Encoded: content), data.count > 4 else {
            throw BuiltInLyricError.badResponse("酷狗 KRC 无法解码")
        }
        data.removeFirst(4)
        for index in data.indices {
            data[index] ^= key[data.distance(from: data.startIndex, to: index) % key.count]
        }
        guard let inflated = inflateZlib(data),
              var text = String(data: inflated, encoding: .utf8) else {
            throw BuiltInLyricError.badResponse("酷狗 KRC 解压失败")
        }

        text = text.replacingOccurrences(of: "\r", with: "")
        if let range = text.range(of: #"^.*\[id:\$\w+\]\n"#, options: .regularExpression) {
            text.removeSubrange(range)
        }

        var translated: [String] = []
        var romanized: [String] = []
        if let match = text.firstMatch(of: #"\[language:([\w=+/]+)\]"#),
           let payload = Data(base64Encoded: match.first),
           let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
           let content = object["content"] as? [[String: Any]] {
            text = text.replacingOccurrences(of: match.full, with: "")
            for item in content {
                let type = item["type"] as? Int ?? -1
                let lines = item["lyricContent"] as? [[String]] ?? []
                let merged = lines.map { $0.joined() }
                switch type {
                case 0:
                    romanized = merged
                case 1:
                    translated = merged
                default:
                    break
                }
            }
        }

        var lyricLines: [String] = []
        var lxlyricLines: [String] = []
        var tlyricLines: [String] = []
        var rlyricLines: [String] = []
        var lineIndex = 0

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            guard let match = line.firstMatch(of: #"\[((\d+),\d+)\].*"#) else { continue }
            let time = Int(match.second) ?? 0
            let tag = timeTag(milliseconds: time)
            let converted = line.replacingOccurrences(of: match.first, with: tag.dropFirst().dropLast().description)
            let lx = decodeHTMLEntities(converted.replacingOccurrences(of: #"<(\d+,\d+),\d+>"#, with: "<$1>", options: .regularExpression))
            lyricLines.append(lx.replacingOccurrences(of: #"<\d+,\d+>"#, with: "", options: .regularExpression))
            lxlyricLines.append(lx)

            if lineIndex < translated.count {
                tlyricLines.append("\(tag)\(decodeHTMLEntities(translated[lineIndex]))")
            }
            if lineIndex < romanized.count {
                rlyricLines.append("\(tag)\(decodeHTMLEntities(romanized[lineIndex]))")
            }
            lineIndex += 1
        }

        let lyric = normalizeLineEndings(lyricLines.joined(separator: "\n"))
        guard hasTimedLyric(lyric) else {
            throw BuiltInLyricError.badResponse("酷狗 KRC 解析为空")
        }

        return MusicSourceLyricResult(
            lyric: lyric,
            tlyric: nilIfBlank(tlyricLines.joined(separator: "\n")),
            rlyric: nilIfBlank(rlyricLines.joined(separator: "\n")),
            lxlyric: nilIfBlank(lxlyricLines.joined(separator: "\n"))
        )
    }

    private func parseDuplicatedTimedLyrics(_ text: String) -> MusicSourceLyricResult {
        let lines = normalizeLineEndings(text).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var tags: [String] = []
        var primary: [(String, String)] = []
        var secondary: [(String, String)] = []
        var seen = Set<String>()

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if let match = trimmed.firstMatch(of: #"^\[([\d:.]+)\](.*)$"#) {
                var time = match.first
                if time.range(of: #"\.\d\d$"#, options: .regularExpression) != nil {
                    time += "0"
                }
                let text = decodeHTMLEntities(match.second.trimmingCharacters(in: .whitespaces))
                if seen.contains(time) {
                    secondary.append((time, text))
                } else {
                    primary.append((time, text))
                    seen.insert(time)
                }
            } else if trimmed.range(of: #"^\[(ver|ti|ar|al|offset|by|kuwo):"#, options: .regularExpression) != nil {
                tags.append(trimmed)
            }
        }

        let lyric = buildTimedLrc(tags: tags, lines: primary)
        let tlyric = secondary.isEmpty ? nil : buildTimedLrc(tags: tags, lines: secondary)
        return MusicSourceLyricResult(lyric: lyric, tlyric: nilIfBlank(tlyric), rlyric: nil, lxlyric: nil)
    }

    private func buildTimedLrc(tags: [String], lines: [(String, String)]) -> String {
        let body = lines.map { "[\($0.0)]\($0.1)" }
        return normalizeLineEndings((tags + body).joined(separator: "\n"))
    }

    private func decodeQQBase64Lyric(_ value: String) throws -> String {
        guard !value.isEmpty else { return "" }
        guard let data = Data(base64Encoded: value),
              let text = String(data: data, encoding: .utf8) else {
            throw BuiltInLyricError.badResponse("QQ 歌词解码失败")
        }
        return normalizeLineEndings(text)
    }

    private func getData(_ urlString: String, headers: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json,text/plain,*/*", forHTTPHeaderField: "Accept")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return data
    }

    private func getText(_ urlString: String, headers: [String: String] = [:]) async throws -> String {
        let data = try await getData(urlString, headers: headers)
        guard let text = String(data: data, encoding: .utf8) else {
            throw BuiltInLyricError.badResponse("文本解码失败")
        }
        return text
    }

    private func getJSON(_ urlString: String, headers: [String: String] = [:]) async throws -> [String: Any] {
        let data = try await getData(urlString, headers: headers)
        return try parseJSONObject(data)
    }

    private func postForm(_ urlString: String, headers: [String: String] = [:], form: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        let body = form.map { "\(urlEscaped($0.key))=\(urlEscaped($0.value))" }.joined(separator: "&")
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
            throw BuiltInLyricError.badResponse("HTTP \(http.statusCode)")
        }
    }

    private func parseJSONObject(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BuiltInLyricError.badResponse("JSON")
        }
        return object
    }

    private func parseLegacy(_ json: String) throws -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BuiltInLyricError.invalidSongInfo("legacyInfoJSON 解析失败")
        }
        return object
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

    private func hasTimedLyric(_ text: String) -> Bool {
        text.range(of: #"\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\]"#, options: .regularExpression) != nil
    }

    private func seconds(from durationText: String) -> String {
        let parts = durationText.split(separator: ":").compactMap { Int($0) }
        guard !parts.isEmpty else { return "" }
        let total = parts.reversed().enumerated().reduce(into: 0) { result, item in
            result += item.element * Int(pow(60.0, Double(item.offset)))
        }
        return String(total)
    }

    private func timeTag(milliseconds: Int) -> String {
        let total = max(milliseconds, 0)
        let ms = total % 1000
        let seconds = (total / 1000) % 60
        let minutes = total / 60000
        return String(format: "[%02d:%02d.%03d]", minutes, seconds, ms)
    }

    private func nilIfBlank(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizeLineEndings(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func urlEscaped(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#039;", with: "'")
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
            throw BuiltInLyricError.badResponse("网易加密失败")
        }

        output.removeSubrange(outputLength..<output.count)
        return output
        #else
        throw BuiltInLyricError.badResponse("当前环境不支持网易加密")
        #endif
    }

    private func inflateZlib(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }

        let destinationBufferSize = max(data.count * 12, 64 * 1024)
        return data.withUnsafeBytes { sourceBuffer in
            guard let sourceBase = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else { return nil }
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationBufferSize)
            defer { destinationBuffer.deallocate() }

            let decoded = compression_decode_buffer(
                destinationBuffer,
                destinationBufferSize,
                sourceBase,
                data.count,
                nil,
                COMPRESSION_ZLIB
            )

            guard decoded > 0 else { return nil }
            return Data(bytes: destinationBuffer, count: decoded)
        }
    }

    private func decodeGB18030(_ data: Data) -> String? {
        let cfEncoding = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        return String(data: data, encoding: String.Encoding(rawValue: nsEncoding))
    }
}

private enum BuiltInLyricError: LocalizedError {
    case unsupportedSource
    case invalidSongInfo(String)
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSource:
            return "当前来源暂不支持内置歌词"
        case let .invalidSongInfo(message):
            return message
        case let .badResponse(message):
            return message
        }
    }
}

private nonisolated extension String {
    func firstMatch(of pattern: String) -> (full: String, first: String, second: String)? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(startIndex..., in: self)
        guard let match = regex.firstMatch(in: self, range: range), match.numberOfRanges >= 2 else {
            return nil
        }
        let full = Range(match.range(at: 0), in: self).map { String(self[$0]) } ?? ""
        let first = Range(match.range(at: 1), in: self).map { String(self[$0]) } ?? ""
        let second = match.numberOfRanges >= 3
            ? (Range(match.range(at: 2), in: self).map { String(self[$0]) } ?? "")
            : ""
        return (full, first, second)
    }
}
