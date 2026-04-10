//
//  MusicSourceRuntime.swift
//  XMusic
//
//  Created by Codex on 2026/3/20.
//

import CryptoKit
import Foundation
import JavaScriptCore
import Security
#if canImport(CommonCrypto)
import CommonCrypto
#endif

struct MusicSourceLyricResult: Hashable {
    let lyric: String
    let tlyric: String?
    let rlyric: String?
    let lxlyric: String?
}

enum MusicSourceLyricNormalizer {
    static func normalize(_ rawValue: Any) -> MusicSourceLyricResult? {
        if let lyric = rawValue as? String {
            return MusicSourceLyricResult(lyric: lyric, tlyric: nil, rlyric: nil, lxlyric: nil)
        }

        guard let data = rawValue as? [String: Any] else { return nil }

        let lyricKeys = ["lyric", "lrc"]
        let tlyricKeys = ["tlyric", "tlrc"]
        let rlyricKeys = ["rlyric", "rlrc"]
        let lxlyricKeys = ["lxlyric", "lxlrc"]

        let primaryLyric = firstString(in: data, keys: lyricKeys)
        let lxlyric = firstString(in: data, keys: lxlyricKeys)
        guard let lyric = primaryLyric ?? lxlyric else { return nil }

        return MusicSourceLyricResult(
            lyric: lyric,
            tlyric: firstString(in: data, keys: tlyricKeys),
            rlyric: firstString(in: data, keys: rlyricKeys),
            lxlyric: lxlyric
        )
    }

    private static func firstString(in data: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let value = data[key] else { continue }
            if let text = value as? String {
                return text
            }
        }
        return nil
    }
}

struct MusicSourceDebugDisplayInfo {
    let title: String
    let artist: String
    let album: String
}

enum MusicSourceRuntimeError: LocalizedError {
    case invalidSongInfoJSON
    case invalidSongInfoObject
    case invalidSongInfo(String)
    case contextUnavailable
    case initializationFailed(String)
    case requestTimedOut
    case invalidResponse(String)
    case networkFailed(String)
    case unsupportedCrypto(String)

    var errorDescription: String? {
        switch self {
        case .invalidSongInfoJSON:
            return "歌曲信息 JSON 解析失败"
        case .invalidSongInfoObject:
            return "歌曲信息格式无效，需要 JSON 对象"
        case let .invalidSongInfo(message):
            return "歌曲信息不完整：\(message)"
        case .contextUnavailable:
            return "音乐源运行环境初始化失败"
        case let .initializationFailed(message):
            return "音乐源初始化失败：\(message)"
        case .requestTimedOut:
            return "音乐源请求超时"
        case let .invalidResponse(message):
            return "音乐源返回了无法识别的数据：\(message)"
        case let .networkFailed(message):
            return "音乐源网络请求失败：\(message)"
        case let .unsupportedCrypto(message):
            return "当前环境缺少脚本所需的加密能力：\(message)"
        }
    }
}

enum LxLegacySongInfo {
    private static let commonSourceNames = ["kw", "kg", "tx", "wy", "mg", "local"]

    static var fallbackSources: [String] {
        commonSourceNames
    }

    static func parseLegacyJSON(_ jsonText: String, sourceName: String) throws -> [String: Any] {
        let text = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw MusicSourceRuntimeError.invalidSongInfoJSON
        }

        guard let data = text.data(using: .utf8) else {
            throw MusicSourceRuntimeError.invalidSongInfoJSON
        }

        let rawObject = try JSONSerialization.jsonObject(with: data)
        guard let object = rawObject as? [String: Any] else {
            throw MusicSourceRuntimeError.invalidSongInfoObject
        }

        let legacyObject = object["meta"] == nil ? buildLegacyInfo(from: object, sourceName: sourceName) : convertFromNewFormat(object, sourceName: sourceName)
        return legacyObject
    }

    static func displayInfo(from legacyObject: [String: Any]) -> MusicSourceDebugDisplayInfo {
        MusicSourceDebugDisplayInfo(
            title: legacyObject["name"] as? String ?? "未命名歌曲",
            artist: legacyObject["singer"] as? String ?? "未知艺人",
            album: legacyObject["albumName"] as? String ?? "自定义音源"
        )
    }

    static func prettyPrintedJSON(from legacyObject: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(legacyObject),
              let data = try? JSONSerialization.data(withJSONObject: legacyObject, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    static func fieldChecks(for sourceName: String, legacyObject: [String: Any]) -> [PlaybackFieldCheck] {
        let fields = expectedFields(for: sourceName)
        return fields.map { item in
            let rawValue = legacyObject[item.field]
            let actualValue = debugString(rawValue)
            let isPresent = isPresentValue(rawValue)
            return PlaybackFieldCheck(
                field: item.field,
                actualValue: actualValue,
                isPresent: isPresent,
                note: item.note
            )
        }
    }

    static func template(for sourceName: String) -> String {
        let info = baseTemplate(sourceName: sourceName)
        let data = try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys])
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    private static func buildLegacyInfo(from object: [String: Any], sourceName: String) -> [String: Any] {
        var merged = baseTemplate(sourceName: sourceName)
        for (key, value) in object {
            merged[key] = value
        }
        merged["source"] = sourceName
        return merged
    }

    private static func convertFromNewFormat(_ object: [String: Any], sourceName: String) -> [String: Any] {
        let meta = object["meta"] as? [String: Any] ?? [:]
        var legacy = baseTemplate(sourceName: sourceName)

        legacy["name"] = object["name"] as? String ?? ""
        legacy["singer"] = object["singer"] as? String ?? ""
        legacy["source"] = sourceName
        legacy["songmid"] = meta["songId"] ?? ""
        legacy["interval"] = object["interval"] as? String ?? ""
        legacy["albumName"] = meta["albumName"] as? String ?? ""
        legacy["img"] = meta["picUrl"] as? String ?? ""
        legacy["albumId"] = meta["albumId"] ?? ""
        legacy["types"] = meta["qualitys"] ?? []
        legacy["_types"] = meta["_qualitys"] ?? [:]

        switch sourceName {
        case "kg":
            legacy["hash"] = meta["hash"] as? String ?? ""
        case "tx":
            legacy["strMediaMid"] = meta["strMediaMid"] as? String ?? ""
            legacy["albumMid"] = meta["albumMid"] as? String ?? ""
            legacy["songId"] = meta["id"] ?? ""
        case "mg":
            legacy["copyrightId"] = meta["copyrightId"] as? String ?? ""
            legacy["lrcUrl"] = meta["lrcUrl"] as? String ?? ""
            legacy["mrcUrl"] = meta["mrcUrl"] as? String ?? ""
            legacy["trcUrl"] = meta["trcUrl"] as? String ?? ""
        default:
            break
        }

        return legacy
    }

    private static func baseTemplate(sourceName: String) -> [String: Any] {
        var info: [String: Any] = [
            "name": "",
            "singer": "",
            "source": sourceName,
            "songmid": "",
            "interval": "03:30",
            "albumName": "",
            "img": "",
            "typeUrl": [:],
        ]

        if sourceName == "local" {
            info["filePath"] = ""
            info["ext"] = "mp3"
        } else {
            info["albumId"] = ""
            info["types"] = []
            info["_types"] = [
                "128k": [
                    "size": NSNull(),
                ],
            ]
        }

        switch sourceName {
        case "kg":
            info["hash"] = ""
        case "tx":
            info["strMediaMid"] = ""
            info["albumMid"] = ""
            info["songId"] = ""
        case "mg":
            info["copyrightId"] = ""
            info["lrcUrl"] = ""
            info["mrcUrl"] = ""
            info["trcUrl"] = ""
        default:
            break
        }

        return info
    }

    private static func expectedFields(for sourceName: String) -> [(field: String, note: String?)] {
        var fields: [(String, String?)] = [
            ("name", "歌曲名"),
            ("singer", "歌手"),
            ("source", "平台标识"),
            ("songmid", "歌曲唯一 ID"),
            ("interval", "时长"),
            ("albumName", "专辑名"),
            ("albumId", "专辑 ID"),
            ("types", "可用音质列表"),
            ("_types", "音质详情映射"),
        ]

        switch sourceName {
        case "kg":
            fields.append(("hash", "LX 常用字段；当前这个源实际也用它来拼 URL"))
        case "tx":
            fields.append(("strMediaMid", "LX 常用字段"))
            fields.append(("albumMid", "专辑 Mid"))
            fields.append(("songId", "QQ 数字 ID"))
        case "mg":
            fields.append(("copyrightId", "LX 常用字段"))
            fields.append(("lrcUrl", "歌词地址，可空"))
        default:
            break
        }

        return fields
    }

    private static func debugString(_ value: Any?) -> String {
        switch value {
        case nil:
            return "<missing>"
        case is NSNull:
            return "null"
        case let string as String:
            return string.isEmpty ? "\"\"" : string
        case let number as NSNumber:
            return number.stringValue
        case let array as [Any]:
            return "Array(\(array.count))"
        case let dict as [String: Any]:
            return "Object(\(dict.keys.sorted().joined(separator: ", ")))"
        default:
            return String(describing: value!)
        }
    }

    private static func isPresentValue(_ value: Any?) -> Bool {
        switch value {
        case nil:
            return false
        case is NSNull:
            return false
        case let string as String:
            return !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case let array as [Any]:
            return !array.isEmpty
        case let dict as [String: Any]:
            return !dict.isEmpty
        default:
            return true
        }
    }
}

final class MusicSourceRuntimeService {
    private typealias NativeCallBlock = @convention(block) (String, String, String) -> Void
    private typealias TimeoutBlock = @convention(block) (String, Int, Int) -> Void
    private typealias StringToStringBlock = @convention(block) (String) -> String
    private typealias DebugLogBlock = @convention(block) (String) -> Void
    private typealias AESBlock = @convention(block) (String, String, String, String) -> String
    private typealias RSABlock = @convention(block) (String, String, String) -> String
    private typealias RandomBytesBlock = @convention(block) (Int) -> String

    private final class InitializationBox {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<[MusicSourceCapability], Error>?
    }

    private let queue = DispatchQueue(label: "XMusic.MusicSourceRuntime")
    private var context: JSContext?
    private var bridge: MusicSourceRuntimeBridge?
    private var currentSourceID: String?
    private var currentSourceName: String?
    private var currentKey = UUID().uuidString
    private var currentInitializationBox: InitializationBox?
    private var pendingScriptRequests: [String: (Result<[String: Any], Error>) -> Void] = [:]
    private var networkTasks: [String: URLSessionDataTask] = [:]
    private var timeoutTasks: [Int: DispatchWorkItem] = [:]
    private var lastExceptionMessage: String?
    private var requestTrace: [String] = []
    private var nativeCallBlock: NativeCallBlock?
    private var timeoutBlock: TimeoutBlock?
    private var stringToBase64Block: StringToStringBlock?
    private var base64ToBytesBlock: StringToStringBlock?
    private var md5Block: StringToStringBlock?
    private var debugLogBlock: DebugLogBlock?
    private var aesBlock: AESBlock?
    private var rsaBlock: RSABlock?
    private var randomBytesBlock: RandomBytesBlock?

    private func debugLog(_ value: @autoclosure () -> String) {
        print("[source-runtime] \(value())")
    }

    fileprivate func handleBridgeNativeCall(_ payloadJSON: String) {
        debugLog("bridge nativeCall payload=\(payloadJSON)")
        guard let object = try? parseJSONObject(payloadJSON),
              let key = object["key"] as? String,
              let action = object["action"] as? String,
              let dataJSON = object["data"] as? String else {
            return
        }

        handleNativeCall(
            key: key,
            action: action,
            dataJSON: dataJSON,
            initialization: currentInitializationBox
        )
    }

    fileprivate func handleBridgeSetTimeout(_ payloadJSON: String) {
        debugLog("bridge setTimeout payload=\(payloadJSON)")
        guard let object = try? parseJSONObject(payloadJSON),
              let key = object["key"] as? String else {
            return
        }

        let timeoutID = (object["id"] as? NSNumber)?.intValue ?? 0
        let timeout = (object["timeout"] as? NSNumber)?.intValue ?? 0
        scheduleTimeout(key: key, timeoutID: timeoutID, milliseconds: timeout)
    }

    private static func scriptRuntimeEnvironment(for source: ImportedMusicSource) -> String {
        let fileName = source.originalFileName?.lowercased()
        if fileName == "latest.js" || source.script.contains("lx-music-api-server") {
            return "desktop"
        }
        return "mobile"
    }

    private static func scriptRuntimeRawScript(for source: ImportedMusicSource) -> String {
        guard scriptRuntimeEnvironment(for: source) == "desktop" else { return source.script }
        if source.script.hasSuffix("\n\n") { return source.script }
        if source.script.hasSuffix("\n") { return source.script + "\n" }
        return source.script + "\n\n"
    }

    fileprivate static func digestPreview(_ value: String) -> String {
        let digest = Insecure.SHA1.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
        return digest.prefix(16) + "..."
    }

    private static func digestPreview(_ data: Data) -> String {
        let digest = Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return digest.prefix(16) + "..."
    }

    func runtimeCapabilities(for source: ImportedMusicSource) async throws -> [MusicSourceCapability] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let capabilities = try self.ensureContextLoaded(for: source)
                    continuation.resume(returning: capabilities)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func resetRequestTrace() async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.requestTrace.removeAll()
                continuation.resume()
            }
        }
    }

    func latestRequestTrace() async -> [String] {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.requestTrace)
            }
        }
    }

    func resolveMusicURL(
        with source: ImportedMusicSource,
        platformSource: String,
        legacySongInfo: [String: Any],
        quality: String
    ) async throws -> URL {
        debugLog("resolveMusicURL source=\(platformSource) quality=\(quality) title=\(legacySongInfo["name"] ?? "")")
        try Self.validateMusicURLRequest(platformSource: platformSource, legacySongInfo: legacySongInfo)

        let rawResult = try await performRequest(
            with: source,
            platformSource: platformSource,
            action: .musicUrl,
            legacySongInfo: legacySongInfo,
            quality: quality
        )

        guard let data = rawResult["data"] as? [String: Any],
              let urlString = data["url"] as? String,
              let url = URL(string: urlString) else {
            throw MusicSourceRuntimeError.invalidResponse("musicUrl")
        }

        debugLog("resolveMusicURL success source=\(platformSource) quality=\(quality) url=\(url.absoluteString)")
        return url
    }

    func resolveLyric(
        with source: ImportedMusicSource,
        platformSource: String,
        legacySongInfo: [String: Any]
    ) async throws -> MusicSourceLyricResult {
        let rawResult = try await performRequest(
            with: source,
            platformSource: platformSource,
            action: .lyric,
            legacySongInfo: legacySongInfo,
            quality: nil
        )

        guard let normalized = MusicSourceLyricNormalizer.normalize(rawResult["data"] as Any) else {
            throw MusicSourceRuntimeError.invalidResponse("lyric")
        }

        return normalized
    }

    func resolvePicture(
        with source: ImportedMusicSource,
        platformSource: String,
        legacySongInfo: [String: Any]
    ) async throws -> URL {
        let rawResult = try await performRequest(
            with: source,
            platformSource: platformSource,
            action: .pic,
            legacySongInfo: legacySongInfo,
            quality: nil
        )

        guard let data = rawResult["data"] as? String,
              let url = URL(string: data) else {
            throw MusicSourceRuntimeError.invalidResponse("pic")
        }

        return url
    }

    private func performRequest(
        with source: ImportedMusicSource,
        platformSource: String,
        action: MusicSourceAction,
        legacySongInfo: [String: Any],
        quality: String?
    ) async throws -> [String: Any] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Any], Error>) in
            queue.async {
                _ = Result {
                    _ = try self.ensureContextLoaded(for: source)

                    let requestKey = UUID().uuidString
                    let timeoutItem = DispatchWorkItem { [weak self] in
                        self?.completeRequest(requestKey, with: .failure(MusicSourceRuntimeError.requestTimedOut))
                    }

                    self.pendingScriptRequests[requestKey] = { result in
                        timeoutItem.cancel()
                        continuation.resume(with: result)
                    }

                    self.queue.asyncAfter(deadline: .now() + 45, execute: timeoutItem)

                    let requestType: Any = quality ?? NSNull()
                    let payload: [String: Any] = [
                        "requestKey": requestKey,
                        "data": [
                            "source": platformSource,
                            "action": action.rawValue,
                            "info": [
                                "type": requestType,
                                "musicInfo": legacySongInfo,
                            ],
                        ],
                    ]

                    self.debugLog(
                        "script request key=\(requestKey) source=\(platformSource) action=\(action.rawValue) quality=\(quality ?? "nil") songmid=\(legacySongInfo["songmid"] ?? "") hash=\(legacySongInfo["hash"] ?? "") copyrightId=\(legacySongInfo["copyrightId"] ?? "")"
                    )

                    do {
                        try self.sendActionToScript("request", data: payload)
                    } catch {
                        timeoutItem.cancel()
                        self.completeRequest(requestKey, with: .failure(error))
                    }
                }.mapError { error in
                    continuation.resume(throwing: error)
                    return error
                }
            }
        }
    }

    private func completeRequest(_ requestKey: String, with result: Result<[String: Any], Error>) {
        guard let completion = pendingScriptRequests.removeValue(forKey: requestKey) else { return }
        completion(result)
    }

    private func ensureContextLoaded(for source: ImportedMusicSource) throws -> [MusicSourceCapability] {
        if currentSourceID == source.id, context != nil {
            return source.capabilities
        }

        destroyLocked()

        guard let context = JSContext() else {
            throw MusicSourceRuntimeError.contextUnavailable
        }

        self.context = context
        currentSourceID = source.id
        currentSourceName = source.name
        currentKey = UUID().uuidString
        lastExceptionMessage = nil

        context.exceptionHandler = { [weak self] _, exception in
            self?.lastExceptionMessage = exception?.toString() ?? "Unknown JavaScript error"
        }

        let initBox = InitializationBox()
        currentInitializationBox = initBox
        defer { currentInitializationBox = nil }
        bridge = MusicSourceRuntimeBridge(service: self)

        nativeCallBlock = { [weak self] key, action, data in
            guard let self else { return }
            self.handleNativeCall(
                key: key,
                action: action,
                dataJSON: data,
                initialization: initBox
            )
        }

        timeoutBlock = { [weak self] key, timeoutID, timeout in
            guard let self else { return }
            self.scheduleTimeout(key: key, timeoutID: timeoutID, milliseconds: timeout)
        }

        stringToBase64Block = { value in
            Data(value.utf8).base64EncodedString()
        }

        base64ToBytesBlock = { value in
            guard let data = Data(base64Encoded: value) else { return "[]" }
            let values = data.map { Int(Int8(bitPattern: $0)) }
            let jsonData = try? JSONSerialization.data(withJSONObject: values)
            return jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        }

        md5Block = { value in
            let result = Insecure.MD5.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
            let preview = value.count > 300 ? String(value.prefix(300)) + "..." : value
            print("[source-runtime:crypto] md5 len=\(value.count) in=\(Self.digestPreview(value)) text=\(preview) out=\(result)")
            return result
        }

        debugLogBlock = { message in
            print("[source-runtime:sha256] \(message)")
        }

        aesBlock = { dataB64, keyB64, ivB64, mode in
            do {
                let encrypted = try Self.encryptAES(dataB64: dataB64, keyB64: keyB64, ivB64: ivB64, mode: mode)
                let result = encrypted.base64EncodedString()
                print("[source-runtime:crypto] aes mode=\(mode) in=\(Self.digestPreview(dataB64)) out=\(Self.digestPreview(result))")
                return result
            } catch {
                print("[source-runtime:crypto] aes mode=\(mode) failed=\(error.localizedDescription)")
                return ""
            }
        }

        rsaBlock = { dataB64, key, _ in
            do {
                let encrypted = try Self.encryptRSA(dataB64: dataB64, publicKey: key)
                let result = encrypted.base64EncodedString()
                print("[source-runtime:crypto] rsa in=\(Self.digestPreview(dataB64)) out=\(Self.digestPreview(result))")
                return result
            } catch {
                print("[source-runtime:crypto] rsa failed=\(error.localizedDescription)")
                return ""
            }
        }

        randomBytesBlock = { size in
            let count = max(0, size)
            guard count > 0 else { return Data().base64EncodedString() }
            var data = Data(count: count)
            let status = data.withUnsafeMutableBytes { rawBuffer in
                guard let baseAddress = rawBuffer.baseAddress else { return errSecParam }
                return SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
            }
            guard status == errSecSuccess else {
                print("[source-runtime:crypto] randomBytes size=\(count) failed status=\(status)")
                return Data().base64EncodedString()
            }
            let result = data.base64EncodedString()
            print("[source-runtime:crypto] randomBytes size=\(count) out=\(Self.digestPreview(result))")
            return result
        }

        context.setObject(bridge, forKeyedSubscript: "__xmusic_bridge__" as NSString)

        context.evaluateScript(MusicSourceRuntimePreload.bridgeScript)
        if let lastExceptionMessage {
            throw MusicSourceRuntimeError.initializationFailed(lastExceptionMessage)
        }

        context.evaluateScript(MusicSourceRuntimePreload.script)
        if let lastExceptionMessage {
            throw MusicSourceRuntimeError.initializationFailed(lastExceptionMessage)
        }

        let setupFunction = context.objectForKeyedSubscript("lx_setup")
        _ = setupFunction?.call(withArguments: [
            currentKey,
            source.id,
            source.name,
            source.description,
            source.version,
            source.author,
            source.homepage,
            Self.scriptRuntimeRawScript(for: source),
            Self.scriptRuntimeEnvironment(for: source),
        ])

        if let lastExceptionMessage {
            throw MusicSourceRuntimeError.initializationFailed(lastExceptionMessage)
        }

        context.evaluateScript(source.script)
        if let lastExceptionMessage {
            throw MusicSourceRuntimeError.initializationFailed(lastExceptionMessage)
        }

        context.evaluateScript("if (typeof globalThis.__lx_install_sha256_hooks__ === 'function') globalThis.__lx_install_sha256_hooks__();")
        if let lastExceptionMessage {
            throw MusicSourceRuntimeError.initializationFailed(lastExceptionMessage)
        }

        guard initBox.semaphore.wait(timeout: .now() + 6) == .success else {
            throw MusicSourceRuntimeError.initializationFailed("脚本初始化超时")
        }

        switch initBox.result {
        case let .success(capabilities):
            return capabilities
        case let .failure(error):
            throw error
        case .none:
            throw MusicSourceRuntimeError.initializationFailed("脚本没有返回初始化结果")
        }
    }

    private func destroyLocked() {
        networkTasks.values.forEach { $0.cancel() }
        networkTasks.removeAll()
        timeoutTasks.values.forEach { $0.cancel() }
        timeoutTasks.removeAll()
        pendingScriptRequests.removeAll()
        requestTrace.removeAll()
        bridge = nil
        currentInitializationBox = nil
        nativeCallBlock = nil
        timeoutBlock = nil
        stringToBase64Block = nil
        base64ToBytesBlock = nil
        md5Block = nil
        debugLogBlock = nil
        aesBlock = nil
        rsaBlock = nil
        randomBytesBlock = nil
        context = nil
        currentSourceID = nil
        currentSourceName = nil
        lastExceptionMessage = nil
    }

    private func scheduleTimeout(key: String, timeoutID: Int, milliseconds: Int) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.queue.async {
                try? self.sendActionToScript("__set_timeout__", data: timeoutID, keyOverride: key)
            }
        }

        timeoutTasks[timeoutID]?.cancel()
        timeoutTasks[timeoutID] = workItem
        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + .milliseconds(max(0, milliseconds)),
            execute: workItem
        )
    }

    private func handleNativeCall(
        key: String,
        action: String,
        dataJSON: String,
        initialization: InitializationBox?
    ) {
        guard key == currentKey else { return }

        switch action {
        case "init":
            guard let initialization else { return }
            do {
                let object = try parseJSONObject(dataJSON)
                let status = object["status"] as? Bool ?? false
                if status {
                    let info = object["info"] as? [String: Any] ?? [:]
                    let rawSources = info["sources"] as? [String: Any] ?? [:]
                    let capabilities = Self.extractCapabilities(from: rawSources)
                    initialization.result = .success(capabilities)
                } else {
                    let message = object["errorMessage"] as? String ?? "Init failed"
                    initialization.result = .failure(MusicSourceRuntimeError.initializationFailed(message))
                }
            } catch {
                initialization.result = .failure(error)
            }
            initialization.semaphore.signal()

        case "response":
            do {
                let object = try parseJSONObject(dataJSON)
                let requestKey = object["requestKey"] as? String ?? ""

                if object["status"] as? Bool == true {
                    let result = object["result"] as? [String: Any] ?? [:]
                    completeRequest(requestKey, with: .success(result))
                } else {
                    let errorMessage = object["errorMessage"] as? String ?? "Script request failed"
                    completeRequest(requestKey, with: .failure(MusicSourceRuntimeError.invalidResponse(errorMessage)))
                }
            } catch {
                if let object = try? parseJSONObject(dataJSON),
                   let requestKey = object["requestKey"] as? String {
                    completeRequest(requestKey, with: .failure(error))
                }
            }

        case "request":
            do {
                let object = try parseJSONObject(dataJSON)
                startNetworkRequest(with: object)
            } catch {
                // Ignore malformed request from script.
            }

        case "cancelRequest":
            let requestKey = (try? parseJSONValue(dataJSON) as? String) ?? dataJSON
            networkTasks.removeValue(forKey: requestKey)?.cancel()

        case "log", "showUpdateAlert":
            break

        default:
            break
        }
    }

    private func startNetworkRequest(with object: [String: Any]) {
        guard let requestKey = object["requestKey"] as? String,
              let urlString = object["url"] as? String,
              let url = URL(string: urlString) else {
            return
        }

        let options = object["options"] as? [String: Any] ?? [:]

        do {
            let request = try Self.buildURLRequest(url: url, options: options)
            requestTrace.append("-> \(request.httpMethod ?? "GET") \(url.absoluteString)")
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let sign = components.queryItems?.first(where: { $0.name == "sign" })?.value {
                debugLog("http sign key=\(requestKey) sign=\(sign)")
            }
            debugLog("http request key=\(requestKey) method=\(request.httpMethod ?? "GET") url=\(url.absoluteString)")
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self else { return }
                let binaryResponse = options["binary"] as? Bool == true
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                self.queue.async {
                    if let error {
                        self.requestTrace.append("<- ERR \(request.httpMethod ?? "GET") \(url.absoluteString) :: \(error.localizedDescription)")
                        self.debugLog("http error key=\(requestKey) method=\(request.httpMethod ?? "GET") url=\(url.absoluteString) error=\(error.localizedDescription)")
                    } else {
                        self.requestTrace.append("<- \(statusCode) \(request.httpMethod ?? "GET") \(url.absoluteString)")
                        let preview = Self.debugPreview(data: data)
                        self.debugLog("http response key=\(requestKey) status=\(statusCode) method=\(request.httpMethod ?? "GET") url=\(url.absoluteString) body=\(preview)")
                    }
                }

                let payload: [String: Any]
                if let error {
                    #if os(macOS)
                    if Self.shouldFallbackToCurl(for: request, error: error) {
                        do {
                            let (curlData, curlResponse) = try Self.performCurlRequest(for: request)
                            payload = [
                                "requestKey": requestKey,
                                "error": NSNull(),
                                "response": Self.makeResponsePayload(data: curlData, response: curlResponse, binary: binaryResponse),
                            ]
                        } catch {
                            payload = [
                                "requestKey": requestKey,
                                "error": "\(error.localizedDescription) [\(url.absoluteString)]",
                                "response": NSNull(),
                            ]
                        }
                    } else {
                        payload = [
                            "requestKey": requestKey,
                            "error": "\(error.localizedDescription) [\(url.absoluteString)]",
                            "response": NSNull(),
                        ]
                    }
                    #else
                    payload = [
                        "requestKey": requestKey,
                        "error": "\(error.localizedDescription) [\(url.absoluteString)]",
                        "response": NSNull(),
                    ]
                    #endif
                } else {
                    payload = [
                        "requestKey": requestKey,
                        "error": NSNull(),
                        "response": Self.makeResponsePayload(data: data, response: response, binary: binaryResponse),
                    ]
                }

                self.queue.async {
                    self.networkTasks.removeValue(forKey: requestKey)
                    try? self.sendActionToScript("response", data: payload)
                }
            }

            networkTasks[requestKey] = task
            task.resume()
        } catch {
            let payload: [String: Any] = [
                "requestKey": requestKey,
                "error": "\(error.localizedDescription) [\(url.absoluteString)]",
                "response": NSNull(),
            ]

            try? sendActionToScript("response", data: payload)
        }
    }

    private func sendActionToScript(_ action: String, data: Any, keyOverride: String? = nil) throws {
        guard let context else {
            throw MusicSourceRuntimeError.contextUnavailable
        }

        let native = context.objectForKeyedSubscript("__lx_native__")
        let serialized = try serializeJSONString(data)
        _ = native?.call(withArguments: [keyOverride ?? currentKey, action, serialized])

        if let lastExceptionMessage {
            throw MusicSourceRuntimeError.initializationFailed(lastExceptionMessage)
        }
    }

    private func serializeJSONString(_ object: Any) throws -> String {
        let compatible = Self.makeJSONCompatible(object)
        let data = try JSONSerialization.data(withJSONObject: compatible)
        return String(decoding: data, as: UTF8.self)
    }

    fileprivate func parseJSONObject(_ json: String) throws -> [String: Any] {
        guard let data = json.data(using: .utf8) else {
            throw MusicSourceRuntimeError.invalidResponse("invalid json string")
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MusicSourceRuntimeError.invalidResponse("invalid json object")
        }

        return object
    }

    private func parseJSONValue(_ json: String) throws -> Any {
        guard let data = json.data(using: .utf8) else {
            throw MusicSourceRuntimeError.invalidResponse("invalid json string")
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private static func makeJSONCompatible(_ value: Any) -> Any {
        if value is NSNull { return value }

        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number
        case let bool as Bool:
            return bool
        case let int as Int:
            return int
        case let double as Double:
            return double
        case let array as [Any]:
            return array.map { makeJSONCompatible($0) }
        case let dictionary as [String: Any]:
            return dictionary.reduce(into: [String: Any]()) { partialResult, element in
                partialResult[element.key] = makeJSONCompatible(element.value)
            }
        case let optional as Optional<Any>:
            switch optional {
            case let .some(wrapped):
                return makeJSONCompatible(wrapped)
            case .none:
                return NSNull()
            }
        default:
            return "\(value)"
        }
    }

    private static func extractCapabilities(from rawSources: [String: Any]) -> [MusicSourceCapability] {
        let supportedQualities: [String: [String]] = [
            "kw": ["128k", "320k", "flac", "flac24bit"],
            "kg": ["128k", "320k", "flac", "flac24bit"],
            "tx": ["128k", "320k", "flac", "flac24bit"],
            "wy": ["128k", "320k", "flac", "flac24bit"],
            "mg": ["128k", "320k", "flac", "flac24bit"],
            "local": [],
        ]
        let supportedActions: [String: [MusicSourceAction]] = [
            "kw": [.musicUrl, .lyric, .pic],
            "kg": [.musicUrl, .lyric, .pic],
            "tx": [.musicUrl, .lyric, .pic],
            "wy": [.musicUrl, .lyric, .pic],
            "mg": [.musicUrl, .lyric, .pic],
            "local": [.musicUrl, .lyric, .pic],
        ]

        return rawSources.compactMap { key, value in
            guard let info = value as? [String: Any],
                  (info["type"] as? String) == MusicSourceKind.music.rawValue else { return nil }

            let actions = (info["actions"] as? [String] ?? []).compactMap(MusicSourceAction.init(rawValue:))
            let qualitys = info["qualitys"] as? [String] ?? []

            return MusicSourceCapability(
                source: key,
                type: .music,
                actions: supportedActions[key, default: []].filter(actions.contains),
                qualitys: supportedQualities[key, default: []].filter(qualitys.contains)
            )
        }
        .sorted { $0.source < $1.source }
    }

    private static func buildURLRequest(url: URL, options: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = ((options["method"] as? String) ?? "get").uppercased()
        request.timeoutInterval = min(max((options["timeout"] as? Double ?? 13_000) / 1000, 1), 60)

        if let headers = options["headers"] as? [String: Any] {
            for (key, value) in headers {
                request.setValue("\(value)", forHTTPHeaderField: key)
            }
        }

        if let form = options["form"] as? [String: Any] {
            let body = form.map { key, value in
                "\(key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key)=\("\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "\(value)")"
            }
            .joined(separator: "&")
            request.httpBody = Data(body.utf8)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }
        } else if let body = options["body"] {
            if let string = body as? String {
                request.httpBody = Data(string.utf8)
            } else if JSONSerialization.isValidJSONObject(body) {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            }
        }

        if request.value(forHTTPHeaderField: "User-Agent") == nil {
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
                forHTTPHeaderField: "User-Agent"
            )
        }

        if request.value(forHTTPHeaderField: "Accept") == nil {
            request.setValue("application/json,text/plain,*/*", forHTTPHeaderField: "Accept")
        }

        return request
    }

    private static func makeResponsePayload(data: Data?, response: URLResponse?, binary: Bool) -> [String: Any] {
        let http = response as? HTTPURLResponse
        let headers = (http?.allHeaderFields ?? [:]).reduce(into: [String: String]()) { partialResult, element in
            partialResult["\(element.key)"] = "\(element.value)"
        }
        let statusCode = http?.statusCode ?? 0
        let rawData = data ?? Data()

        let body: Any
        if binary {
            body = Array(rawData)
        } else if let data, let json = try? JSONSerialization.jsonObject(with: data) {
            body = json
        } else {
            body = decodeText(from: data) ?? ""
        }

        return [
            "statusCode": statusCode,
            "statusMessage": HTTPURLResponse.localizedString(forStatusCode: statusCode),
            "headers": headers,
            "bytes": rawData.count,
            "raw": Array(rawData),
            "body": body,
        ]
    }

    private static func decodeText(from data: Data?) -> String? {
        guard let data else { return nil }
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .unicode)
            ?? String(data: data, encoding: .isoLatin1)
    }

    private static func debugPreview(data: Data?, limit: Int = 300) -> String {
        guard let text = decodeText(from: data), !text.isEmpty else { return "<empty>" }
        let trimmed = text.replacingOccurrences(of: "\n", with: "\\n")
        return trimmed.count > limit ? String(trimmed.prefix(limit)) + "..." : trimmed
    }

    private static func summarizedHTTPErrorText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("<"), trimmed.contains(">") else { return trimmed }

        let patterns = [
            #"<title>(.*?)</title>"#,
            #"<h1[^>]*>(.*?)</h1>"#,
            #"<body[^>]*>(.*?)</body>"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               let range = Range(match.range(at: 1), in: trimmed) {
                let candidate = trimmed[range]
                    .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty {
                    return candidate
                }
            }
        }

        return trimmed.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func validateMusicURLRequest(platformSource: String, legacySongInfo: [String: Any]) throws {
        func nonEmptyString(_ key: String) -> String {
            if let string = legacySongInfo[key] as? String {
                return string.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let number = legacySongInfo[key] as? NSNumber {
                return number.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ""
        }

        switch platformSource {
        case "kg":
            guard !nonEmptyString("hash").isEmpty else {
                throw MusicSourceRuntimeError.invalidSongInfo("酷狗源缺少 `hash`，默认模板不能直接解析，请换成真实 songInfo 或从搜索结果直接播放。")
            }
        case "kw", "wy":
            guard !nonEmptyString("songmid").isEmpty else {
                throw MusicSourceRuntimeError.invalidSongInfo("\(platformSource.uppercased()) 源缺少 `songmid`。")
            }
        case "tx":
            guard !nonEmptyString("songmid").isEmpty else {
                throw MusicSourceRuntimeError.invalidSongInfo("QQ 源缺少 `songmid`。")
            }
            guard !nonEmptyString("strMediaMid").isEmpty else {
                throw MusicSourceRuntimeError.invalidSongInfo("QQ 源缺少 `strMediaMid`。")
            }
        case "mg":
            guard !nonEmptyString("copyrightId").isEmpty else {
                throw MusicSourceRuntimeError.invalidSongInfo("咪咕源缺少 `copyrightId`。")
            }
        default:
            break
        }
    }

    #if os(macOS)
    private static func shouldFallbackToCurl(for request: URLRequest, error: Error) -> Bool {
        guard request.url?.scheme?.lowercased() == "http" else { return false }

        if let urlError = error as? URLError,
           urlError.code == .appTransportSecurityRequiresSecureConnection {
            return true
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain,
           nsError.code == URLError.appTransportSecurityRequiresSecureConnection.rawValue {
            return true
        }

        let description = error.localizedDescription.lowercased()
        return description.contains("app transport security")
            && description.contains("secure connection")
    }

    private static func performCurlRequest(for request: URLRequest) throws -> (Data, HTTPURLResponse?) {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryDirectory) }

        let headerFileURL = temporaryDirectory.appendingPathComponent("headers.txt", isDirectory: false)
        let bodyFileURL = temporaryDirectory.appendingPathComponent("body.dat", isDirectory: false)
        let requestBodyURL = temporaryDirectory.appendingPathComponent("request-body.dat", isDirectory: false)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")

        var arguments = [
            "-L",
            "--silent",
            "--show-error",
            "--compressed",
            "--request", request.httpMethod ?? "GET",
            "--max-time", "\(max(1, Int(ceil(request.timeoutInterval))))",
            "--dump-header", headerFileURL.path,
            "--output", bodyFileURL.path,
            "--write-out", "%{http_code}",
        ]

        let headers = request.allHTTPHeaderFields ?? [:]
        for header in headers.keys.sorted() {
            if let value = headers[header] {
                arguments.append(contentsOf: ["-H", "\(header): \(value)"])
            }
        }

        if let body = request.httpBody, !body.isEmpty {
            try body.write(to: requestBodyURL, options: .atomic)
            arguments.append(contentsOf: ["--data-binary", "@\(requestBodyURL.path)"])
        }

        guard let url = request.url else {
            throw URLError(.badURL)
        }
        arguments.append(url.absoluteString)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.arguments = arguments

        try process.run()
        process.waitUntilExit()

        let statusData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "XMusic.CurlRequest",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: message ?? "curl request failed"]
            )
        }

        let body = (try? Data(contentsOf: bodyFileURL)) ?? Data()
        let statusCode = Int(String(decoding: statusData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)) ?? 200
        let headerFields = parseCurlHeaderFields(from: headerFileURL)
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headerFields)
        return (body, response)
    }

    private static func parseCurlHeaderFields(from fileURL: URL) -> [String: String] {
        guard let rawText = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return [:]
        }

        let lines = rawText.components(separatedBy: .newlines)
        var blocks: [[String]] = []
        var currentBlock: [String] = []

        for line in lines {
            if line.isEmpty {
                if !currentBlock.isEmpty {
                    blocks.append(currentBlock)
                    currentBlock = []
                }
                continue
            }
            currentBlock.append(line)
        }

        if !currentBlock.isEmpty {
            blocks.append(currentBlock)
        }

        guard let finalBlock = blocks.reversed().first(where: { block in
            (block.first ?? "").uppercased().hasPrefix("HTTP/")
        }) else {
            return [:]
        }

        var headers: [String: String] = [:]
        for line in finalBlock.dropFirst() {
            guard let separatorIndex = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(line[line.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            headers[key] = value
        }

        return headers
    }
    #endif

    fileprivate static func encryptRSA(dataB64: String, publicKey: String) throws -> Data {
        guard let data = Data(base64Encoded: dataB64) else {
            throw MusicSourceRuntimeError.unsupportedCrypto("RSA input")
        }

        let cleanedKey = publicKey
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()

        guard let keyData = Data(base64Encoded: cleanedKey) else {
            throw MusicSourceRuntimeError.unsupportedCrypto("RSA key")
        }

        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits: keyData.count * 8,
        ]

        var error: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error) else {
            throw (error?.takeRetainedValue() as Error?) ?? MusicSourceRuntimeError.unsupportedCrypto("RSA create key")
        }

        guard let encrypted = SecKeyCreateEncryptedData(secKey, .rsaEncryptionRaw, data as CFData, &error) as Data? else {
            throw (error?.takeRetainedValue() as Error?) ?? MusicSourceRuntimeError.unsupportedCrypto("RSA encrypt")
        }

        return encrypted
    }

    fileprivate static func encryptAES(dataB64: String, keyB64: String, ivB64: String, mode: String) throws -> Data {
        #if canImport(CommonCrypto)
        guard let data = Data(base64Encoded: dataB64),
              let key = Data(base64Encoded: keyB64) else {
            throw MusicSourceRuntimeError.unsupportedCrypto("AES input")
        }

        let iv = Data(base64Encoded: ivB64) ?? Data()
        let isCBC = mode == "AES/CBC/PKCS7Padding"
        let options = isCBC
            ? CCOptions(kCCOptionPKCS7Padding)
            : CCOptions(kCCOptionECBMode | kCCOptionPKCS7Padding)

        var outLength = 0
        var outData = Data(count: data.count + kCCBlockSizeAES128)
        let outDataCount = outData.count

        let status = outData.withUnsafeMutableBytes { outBytes in
            data.withUnsafeBytes { dataBytes in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            options,
                            keyBytes.baseAddress,
                            kCCKeySizeAES128,
                            isCBC ? ivBytes.baseAddress : nil,
                            dataBytes.baseAddress,
                            data.count,
                            outBytes.baseAddress,
                            outDataCount,
                            &outLength
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            throw MusicSourceRuntimeError.unsupportedCrypto("AES encrypt")
        }

        outData.removeSubrange(outLength..<outData.count)
        return outData
        #else
        throw MusicSourceRuntimeError.unsupportedCrypto("AES is unavailable")
        #endif
    }
}

enum MusicSourceRuntimePreload {
    static let bridgeScript = #"""
    'use strict';

    globalThis.__xmusic_native_call__ = function(key, action, data) {
      return __xmusic_bridge__.nativeCall(JSON.stringify({
        key: String(key),
        action: String(action),
        data: String(data),
      }));
    };

    globalThis.__xmusic_set_timeout__ = function(key, id, timeout) {
      return __xmusic_bridge__.setTimeout(JSON.stringify({
        key: String(key),
        id: Number(id) || 0,
        timeout: Number(timeout) || 0,
      }));
    };

    globalThis.__xmusic_utils_str2b64 = function(input) {
      return __xmusic_bridge__.str2b64(String(input));
    };

    globalThis.__xmusic_utils_b642buf = function(input) {
      return __xmusic_bridge__.b642buf(String(input));
    };

    globalThis.__xmusic_utils_str2md5 = function(input) {
      return __xmusic_bridge__.str2md5(String(input));
    };

    globalThis.__xmusic_debug_log__ = function(message) {
      return __xmusic_bridge__.debugLog(String(message));
    };

    globalThis.__xmusic_utils_aes_encrypt = function(data, keyValue, ivValue, mode) {
      return __xmusic_bridge__.aesEncrypt(JSON.stringify({
        data: String(data),
        key: String(keyValue),
        iv: String(ivValue),
        mode: String(mode),
      }));
    };

    globalThis.__xmusic_utils_rsa_encrypt = function(data, keyValue, mode) {
      return __xmusic_bridge__.rsaEncrypt(JSON.stringify({
        data: String(data),
        key: String(keyValue),
        mode: String(mode),
      }));
    };

    globalThis.__xmusic_utils_random_bytes = function(size) {
      return __xmusic_bridge__.randomBytes(Number(size) || 0);
    };
    """#

    static let sha256HookScript = #"""
      const wordArrayToBytes = function(wordArray) {
        const words = Array.isArray(wordArray && wordArray.words) ? wordArray.words : [];
        const sigBytes = typeof (wordArray && wordArray.sigBytes) === 'number' ? wordArray.sigBytes : words.length * 4;
        const bytes = [];
        for (let index = 0; index < sigBytes; index += 1) {
          const word = words[index >>> 2] || 0;
          bytes.push((word >>> (24 - (index % 4) * 8)) & 255);
        }
        return bytes;
      };

      const describeSha256Input = function(input) {
        if (typeof input === 'string') {
          return {
            inputType: 'string',
            inputLength: input.length,
            inputText: input,
          };
        }

        if (ArrayBuffer.isView(input)) {
          const bytes = new Uint8Array(input.buffer, input.byteOffset, input.byteLength);
          return {
            inputType: input && input.constructor && input.constructor.name ? input.constructor.name : 'TypedArray',
            inputLength: bytes.length,
            inputText: bytesToString(Array.from(bytes)),
          };
        }

        if (input instanceof ArrayBuffer) {
          const bytes = new Uint8Array(input);
          return {
            inputType: 'ArrayBuffer',
            inputLength: bytes.length,
            inputText: bytesToString(Array.from(bytes)),
          };
        }

        if (Array.isArray(input)) {
          const bytes = input.map(function(value) { return Number(value) & 255; });
          return {
            inputType: 'Array',
            inputLength: bytes.length,
            inputText: bytesToString(bytes),
          };
        }

        if (input && typeof input === 'object' && Array.isArray(input.words) && typeof input.sigBytes === 'number') {
          const bytes = wordArrayToBytes(input);
          return {
            inputType: 'CryptoJSWordArray',
            inputLength: bytes.length,
            inputText: bytesToString(bytes),
          };
        }

        const text = input == null ? '' : String(input);
        return {
          inputType: input == null ? String(input) : typeof input,
          inputLength: text.length,
          inputText: text,
        };
      };

      const sha256WrappedKey = '__lx_sha256_wrapped__';

      const emitSha256Debug = function(label, input, extra) {
        try {
          const payload = Object.assign({
            stage: 'sha256-input',
            hook: label,
          }, describeSha256Input(input), extra || {});
          if (typeof globalThis.__lx_emit_sha256_debug__ === 'function') {
            globalThis.__lx_emit_sha256_debug__(payload);
          }
        } catch (_) {}
      };

      const wrapSha256Function = function(label, fn) {
        if (typeof fn !== 'function') return fn;
        if (fn[sha256WrappedKey]) return fn;
        const wrapped = function() {
          emitSha256Debug(label, arguments[0], { argumentCount: arguments.length });
          return fn.apply(this, arguments);
        };
        try {
          Object.defineProperty(wrapped, sha256WrappedKey, { value: true });
        } catch (_) {
          wrapped[sha256WrappedKey] = true;
        }
        return wrapped;
      };

      const hookNamedShaFunction = function(name) {
        try {
          let current = wrapSha256Function(name, globalThis[name]);
          Object.defineProperty(globalThis, name, {
            configurable: true,
            enumerable: true,
            get() {
              return current;
            },
            set(next) {
              current = wrapSha256Function(name, next);
            },
          });
        } catch (_) {
          try {
            globalThis[name] = wrapSha256Function(name, globalThis[name]);
          } catch (_) {}
        }
      };

      const hookCryptoJSObject = function(value) {
        if (!value || (typeof value !== 'object' && typeof value !== 'function')) return value;
        try {
          let current = wrapSha256Function('CryptoJS.SHA256', value.SHA256);
          Object.defineProperty(value, 'SHA256', {
            configurable: true,
            enumerable: true,
            get() {
              return current;
            },
            set(next) {
              current = wrapSha256Function('CryptoJS.SHA256', next);
            },
          });
        } catch (_) {
          try {
            value.SHA256 = wrapSha256Function('CryptoJS.SHA256', value.SHA256);
          } catch (_) {}
        }
        return value;
      };

      const installCryptoJSHook = function() {
        try {
          let current = hookCryptoJSObject(globalThis.CryptoJS);
          Object.defineProperty(globalThis, 'CryptoJS', {
            configurable: true,
            enumerable: true,
            get() {
              return current;
            },
            set(next) {
              current = hookCryptoJSObject(next);
            },
          });
        } catch (_) {
          hookCryptoJSObject(globalThis.CryptoJS);
        }
      };

      const installSubtleDigestHook = function() {
        try {
          const subtle = globalThis.crypto && globalThis.crypto.subtle;
          if (!subtle || typeof subtle.digest !== 'function') return;
          if (subtle.digest[sha256WrappedKey]) return;
          const originalDigest = subtle.digest.bind(subtle);
          const wrappedDigest = function(algorithm, data) {
            const algorithmName = typeof algorithm === 'string' ? algorithm : algorithm && algorithm.name;
            if (typeof algorithmName === 'string' && algorithmName.toUpperCase() === 'SHA-256') {
              emitSha256Debug('crypto.subtle.digest', data, { algorithm: algorithmName });
            }
            return originalDigest(algorithm, data);
          };
          try {
            Object.defineProperty(wrappedDigest, sha256WrappedKey, { value: true });
          } catch (_) {
            wrappedDigest[sha256WrappedKey] = true;
          }
          subtle.digest = wrappedDigest;
        } catch (_) {}
      };

      globalThis.__lx_install_sha256_hooks__ = function() {
        hookNamedShaFunction('sha256');
        hookNamedShaFunction('SHA256');
        installCryptoJSHook();
        installSubtleDigestHook();
      };

      globalThis.__lx_install_sha256_hooks__();
    """#

    static let script = #"""
    'use strict';

    globalThis.lx_setup = function(key, id, name, description, version, author, homepage, rawScript, envName) {
      const nativeCall = function(action, data) {
        __xmusic_native_call__(key, action, JSON.stringify(data));
      };

      const nativeFuncs = {
        setTimeout(id, timeout) {
          __xmusic_set_timeout__(key, id, timeout);
        },
        str2b64(input) {
          return __xmusic_utils_str2b64(String(input));
        },
        b642buf(input) {
          return __xmusic_utils_b642buf(String(input));
        },
        str2md5(input) {
          return __xmusic_utils_str2md5(String(input));
        },
        aesEncrypt(data, keyValue, ivValue, mode) {
          return __xmusic_utils_aes_encrypt(data, keyValue, ivValue, mode);
        },
        rsaEncrypt(data, keyValue, mode) {
          return __xmusic_utils_rsa_encrypt(data, keyValue, mode);
        },
        randomBytes(size) {
          return __xmusic_utils_random_bytes(size);
        },
      };

      globalThis.__lx_emit_sha256_debug__ = function(payload) {
        try {
          __xmusic_debug_log__(JSON.stringify(payload));
        } catch (_) {}
      };

      const callbacks = new Map();
      let timeoutId = 0;

      const bytesToString = function(bytes) {
        let result = '';
        let i = 0;
        while (i < bytes.length) {
          const byte = bytes[i];
          if (byte < 128) {
            result += String.fromCharCode(byte);
            i += 1;
          } else if (byte >= 192 && byte < 224) {
            result += String.fromCharCode(((byte & 31) << 6) | (bytes[i + 1] & 63));
            i += 2;
          } else {
            result += String.fromCharCode(((byte & 15) << 12) | ((bytes[i + 1] & 63) << 6) | (bytes[i + 2] & 63));
            i += 3;
          }
        }
        return result;
      };

      const stringToBytes = function(input) {
        const bytes = [];
        for (let i = 0; i < input.length; i++) {
          const charCode = input.charCodeAt(i);
          if (charCode < 128) {
            bytes.push(charCode);
          } else if (charCode < 2048) {
            bytes.push((charCode >> 6) | 192);
            bytes.push((charCode & 63) | 128);
          } else {
            bytes.push((charCode >> 12) | 224);
            bytes.push(((charCode >> 6) & 63) | 128);
            bytes.push((charCode & 63) | 128);
          }
        }
        return bytes;
      };

    \#(sha256HookScript)

      const dataToB64 = function(data) {
        if (typeof data === 'string') return nativeFuncs.str2b64(data);
        if (Array.isArray(data) || ArrayBuffer.isView(data)) return utils.buffer.bufToString(data, 'base64');
        throw new Error('Unsupported data type');
      };

      const digestString = function(value) {
        try {
          const text = String(value);
          return nativeFuncs.str2md5(text).slice(0, 16);
        } catch (_) {
          return 'digest-failed';
        }
      };

      const verifyLyricInfo = function(info) {
        if (typeof info === 'string') {
          return {
            lyric: info,
            tlyric: null,
            rlyric: null,
            lxlyric: null,
          };
        }
        if (!info || typeof info !== 'object') throw new Error('failed');

        const lxlyric = typeof info.lxlyric === 'string'
          ? info.lxlyric
          : (typeof info.lxlrc === 'string' ? info.lxlrc : null);
        const lyric = typeof info.lyric === 'string'
          ? info.lyric
          : (typeof info.lrc === 'string' ? info.lrc : lxlyric);
        if (typeof lyric !== 'string') throw new Error('failed');

        return {
          lyric,
          tlyric: typeof info.tlyric === 'string' ? info.tlyric : (typeof info.tlrc === 'string' ? info.tlrc : null),
          rlyric: typeof info.rlyric === 'string' ? info.rlyric : (typeof info.rlrc === 'string' ? info.rlrc : null),
          lxlyric,
        };
      };

      const supportQualitys = {
        kw: ['128k', '320k', 'flac', 'flac24bit'],
        kg: ['128k', '320k', 'flac', 'flac24bit'],
        tx: ['128k', '320k', 'flac', 'flac24bit'],
        wy: ['128k', '320k', 'flac', 'flac24bit'],
        mg: ['128k', '320k', 'flac', 'flac24bit'],
        local: [],
      };

      const supportActions = {
        kw: ['musicUrl', 'lyric', 'pic'],
        kg: ['musicUrl', 'lyric', 'pic'],
        tx: ['musicUrl', 'lyric', 'pic'],
        wy: ['musicUrl', 'lyric', 'pic'],
        mg: ['musicUrl', 'lyric', 'pic'],
        local: ['musicUrl', 'lyric', 'pic'],
      };

      const EVENT_NAMES = {
        request: 'request',
        inited: 'inited',
        updateAlert: 'updateAlert',
      };

      const events = {
        request: null,
      };
      const requestQueue = new Map();
      const allSources = ['kw', 'kg', 'tx', 'wy', 'mg', 'local'];
      let isInitedApi = false;
      let isShowedUpdateAlert = false;

      globalThis.__lx_native__ = function(receivedKey, action, data) {
        if (receivedKey !== key) return 'Invalid key';
        switch (action) {
          case '__set_timeout__': {
            const target = callbacks.get(data);
            if (!target) return '';
            callbacks.delete(data);
            target.callback.apply(null, target.params);
            return '';
          }
          case 'response': {
            const payload = JSON.parse(data);
            const target = requestQueue.get(payload.requestKey);
            if (!target) return '';
            requestQueue.delete(payload.requestKey);
            target.requestInfo.aborted = true;
            if (payload.error == null) target.callback(null, payload.response);
            else target.callback(new Error(payload.error), null);
            return '';
          }
          case 'request': {
            const payload = JSON.parse(data);
            if (!events.request) {
              nativeCall('response', { requestKey: payload.requestKey, status: false, errorMessage: 'Request event is not defined' });
              return '';
            }

            Promise.resolve(events.request.call(globalThis.lx, payload.data)).then((response) => {
              let result;
              switch (payload.data.action) {
                case 'musicUrl':
                  if (typeof response !== 'string' || !/^https?:/.test(response)) throw new Error('failed');
                  result = {
                    source: payload.data.source,
                    action: payload.data.action,
                    data: {
                      type: payload.data.info.type,
                      url: response,
                    },
                  };
                  break;
                case 'lyric':
                  result = {
                    source: payload.data.source,
                    action: payload.data.action,
                    data: verifyLyricInfo(response),
                  };
                  break;
                case 'pic':
                  if (typeof response !== 'string' || !/^https?:/.test(response)) throw new Error('failed');
                  result = {
                    source: payload.data.source,
                    action: payload.data.action,
                    data: response,
                  };
                  break;
                default:
                  throw new Error('Unknown request action');
              }
              nativeCall('response', { requestKey: payload.requestKey, status: true, result: result });
            }).catch((error) => {
              nativeCall('response', {
                requestKey: payload.requestKey,
                status: false,
                errorMessage: error && error.message ? error.message : String(error),
              });
            });
            return '';
          }
          default:
            return '';
        }
      };

      const _setTimeout = function(callback, timeout) {
        const params = Array.prototype.slice.call(arguments, 2);
        if (typeof callback !== 'function') throw new Error('callback required a function');
        timeout = typeof timeout === 'number' ? timeout : 0;
        const currentId = timeoutId++;
        callbacks.set(currentId, { callback: callback, params: params });
        nativeFuncs.setTimeout(currentId, parseInt(timeout, 10));
        return currentId;
      };

      const _clearTimeout = function(id) {
        callbacks.delete(id);
      };

      const sendNativeRequest = function(url, options, callback) {
        const requestKey = Math.random().toString();
        const requestInfo = {
          aborted: false,
          abort() {
            nativeCall('cancelRequest', requestKey);
          },
        };

        requestQueue.set(requestKey, { callback: callback, requestInfo: requestInfo });
        nativeCall('request', { requestKey: requestKey, url: url, options: options });
        return requestInfo;
      };

      const handleInit = function(info) {
        if (!info || typeof info !== 'object') {
          nativeCall('init', { info: null, status: false, errorMessage: 'Missing required parameter init info' });
          return;
        }

        const sourceInfo = { sources: {} };
        try {
          allSources.forEach((sourceName) => {
            const userSource = info.sources && info.sources[sourceName];
            if (!userSource || userSource.type !== 'music') return;
            sourceInfo.sources[sourceName] = {
              type: 'music',
              actions: supportActions[sourceName].filter((action) => userSource.actions.includes(action)),
              qualitys: supportQualitys[sourceName].filter((quality) => userSource.qualitys.includes(quality)),
            };
          });
        } catch (error) {
          nativeCall('init', {
            info: null,
            status: false,
            errorMessage: error && error.message ? error.message : String(error),
          });
          return;
        }

        nativeCall('init', { info: sourceInfo, status: true });
      };

      const utils = {
        crypto: {
          aesEncrypt(buffer, mode, aesKey, iv) {
            switch (mode) {
              case 'aes-128-cbc':
                return utils.buffer.from(nativeFuncs.aesEncrypt(dataToB64(buffer), dataToB64(aesKey), dataToB64(iv), 'AES/CBC/PKCS7Padding'), 'base64');
              case 'aes-128-ecb':
                return utils.buffer.from(nativeFuncs.aesEncrypt(dataToB64(buffer), dataToB64(aesKey), '', 'AES'), 'base64');
              default:
                throw new Error('Unsupported AES mode');
            }
          },
          rsaEncrypt(buffer, publicKey) {
            const keyValue = String(publicKey)
              .replace('-----BEGIN PUBLIC KEY-----', '')
              .replace('-----END PUBLIC KEY-----', '');
            return utils.buffer.from(nativeFuncs.rsaEncrypt(dataToB64(buffer), keyValue, 'RSA/ECB/NoPadding'), 'base64');
          },
          randomBytes(size) {
            return utils.buffer.from(nativeFuncs.randomBytes(size), 'base64');
          },
          md5(str) {
            return nativeFuncs.str2md5(String(str));
          },
        },
        buffer: {
          from(input, encoding) {
            if (typeof input === 'string') {
              console.log('[source-runtime:buffer]', JSON.stringify({
                stage: 'from',
                encoding: encoding || 'utf8',
                digest: digestString(input),
                length: input.length,
              }));
              switch (encoding) {
                case 'base64':
                  return new Uint8Array(JSON.parse(nativeFuncs.b642buf(input)));
                case 'hex':
                  return new Uint8Array(input.match(/.{1,2}/g).map((byte) => parseInt(byte, 16)));
                default:
                  return new Uint8Array(stringToBytes(input));
              }
            }
            if (Array.isArray(input)) return new Uint8Array(input);
            throw new Error('Unsupported input type');
          },
          bufToString(buf, format) {
            const bytes = Array.from(buf);
            console.log('[source-runtime:buffer]', JSON.stringify({
              stage: 'bufToString',
              format: format || 'utf8',
              length: bytes.length,
            }));
            switch (format) {
              case 'hex':
                return bytes.reduce((str, byte) => str + byte.toString(16).padStart(2, '0'), '');
              case 'base64':
                return nativeFuncs.str2b64(bytesToString(bytes));
              case 'utf8':
              case 'utf-8':
              default:
                return bytesToString(bytes);
            }
          },
        },
      };

      globalThis.lx = {
        EVENT_NAMES: EVENT_NAMES,
        request(url, options, callback) {
          const normalized = Object.assign({ method: 'get', headers: {}, binary: false }, options || {});
          let request = sendNativeRequest(url, normalized, function(error, response) {
            if (error) callback(error, null, null);
            else callback(null, {
              statusCode: response.statusCode,
              statusMessage: response.statusMessage,
              headers: response.headers,
              body: response.body,
            }, response.body);
          });
          return function() {
            if (!request.aborted) request.abort();
            request = null;
          };
        },
        send(eventName, data) {
          switch (eventName) {
            case EVENT_NAMES.inited:
              if (isInitedApi) return Promise.reject(new Error('Script is inited'));
              isInitedApi = true;
              handleInit(data);
              return Promise.resolve();
            case EVENT_NAMES.updateAlert:
              if (isShowedUpdateAlert) return Promise.reject(new Error('The update alert can only be called once.'));
              isShowedUpdateAlert = true;
              nativeCall('showUpdateAlert', data || {});
              return Promise.resolve();
            default:
              return Promise.reject(new Error('Unknown event name: ' + eventName));
          }
        },
        on(eventName, handler) {
          if (eventName !== EVENT_NAMES.request) return Promise.reject(new Error('The event is not supported: ' + eventName));
          events.request = handler;
          return Promise.resolve();
        },
        utils: utils,
        currentScriptInfo: {
          name: name,
          description: description,
          version: version,
          author: author,
          homepage: homepage,
          rawScript: rawScript,
        },
        version: '2.0.0',
        env: typeof envName === 'string' && envName ? envName : 'mobile',
      };

      globalThis.setTimeout = _setTimeout;
      globalThis.clearTimeout = _clearTimeout;
      globalThis.globalThis = globalThis;
      globalThis.global = globalThis;
    };
    """#
}

@objc private protocol MusicSourceRuntimeBridgeExports: JSExport {
    func nativeCall(_ payloadJSON: String)
    func setTimeout(_ payloadJSON: String)
    func str2b64(_ input: String) -> String
    func b642buf(_ input: String) -> String
    func str2md5(_ input: String) -> String
    func debugLog(_ message: String)
    func aesEncrypt(_ payloadJSON: String) -> String
    func rsaEncrypt(_ payloadJSON: String) -> String
    func randomBytes(_ size: NSNumber) -> String
}

private final class MusicSourceRuntimeBridge: NSObject, MusicSourceRuntimeBridgeExports {
    weak var service: MusicSourceRuntimeService?

    init(service: MusicSourceRuntimeService) {
        self.service = service
    }

    func nativeCall(_ payloadJSON: String) {
        service?.handleBridgeNativeCall(payloadJSON)
    }

    func setTimeout(_ payloadJSON: String) {
        service?.handleBridgeSetTimeout(payloadJSON)
    }

    func str2b64(_ input: String) -> String {
        Data(input.utf8).base64EncodedString()
    }

    func b642buf(_ input: String) -> String {
        guard let data = Data(base64Encoded: input) else { return "[]" }
        let values = data.map { Int(Int8(bitPattern: $0)) }
        let jsonData = try? JSONSerialization.data(withJSONObject: values)
        return jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    func str2md5(_ input: String) -> String {
        let result = Insecure.MD5.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
        let preview = input.count > 300 ? String(input.prefix(300)) + "..." : input
        print("[source-runtime:crypto] md5 len=\(input.count) in=\(MusicSourceRuntimeService.digestPreview(input)) text=\(preview) out=\(result)")
        return result
    }

    func debugLog(_ message: String) {
        print("[source-runtime:sha256] \(message)")
    }

    func aesEncrypt(_ payloadJSON: String) -> String {
        guard let service,
              let object = try? service.parseJSONObject(payloadJSON),
              let dataB64 = object["data"] as? String,
              let keyB64 = object["key"] as? String,
              let ivB64 = object["iv"] as? String,
              let mode = object["mode"] as? String else {
            return ""
        }

        do {
            let encrypted = try MusicSourceRuntimeService.encryptAES(
                dataB64: dataB64,
                keyB64: keyB64,
                ivB64: ivB64,
                mode: mode
            )
            let result = encrypted.base64EncodedString()
            print("[source-runtime:crypto] aes mode=\(mode) in=\(MusicSourceRuntimeService.digestPreview(dataB64)) out=\(MusicSourceRuntimeService.digestPreview(result))")
            return result
        } catch {
            print("[source-runtime:crypto] aes mode=\(mode) failed=\(error.localizedDescription)")
            return ""
        }
    }

    func rsaEncrypt(_ payloadJSON: String) -> String {
        guard let service,
              let object = try? service.parseJSONObject(payloadJSON),
              let dataB64 = object["data"] as? String,
              let key = object["key"] as? String else {
            return ""
        }

        do {
            let encrypted = try MusicSourceRuntimeService.encryptRSA(dataB64: dataB64, publicKey: key)
            let result = encrypted.base64EncodedString()
            print("[source-runtime:crypto] rsa in=\(MusicSourceRuntimeService.digestPreview(dataB64)) out=\(MusicSourceRuntimeService.digestPreview(result))")
            return result
        } catch {
            print("[source-runtime:crypto] rsa failed=\(error.localizedDescription)")
            return ""
        }
    }

    func randomBytes(_ size: NSNumber) -> String {
        let count = max(0, size.intValue)
        guard count > 0 else { return Data().base64EncodedString() }

        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
        }
        guard status == errSecSuccess else {
            print("[source-runtime:crypto] randomBytes size=\(count) failed status=\(status)")
            return Data().base64EncodedString()
        }

        let result = data.base64EncodedString()
        print("[source-runtime:crypto] randomBytes size=\(count) out=\(MusicSourceRuntimeService.digestPreview(result))")
        return result
    }
}
