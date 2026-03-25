//
//  MusicSourceParser.swift
//  XMusic
//
//  Created by Codex on 2026/3/20.
//

import CryptoKit
import Foundation
import JavaScriptCore

enum MusicSourceParser {
    private static let infoLimits: [String: Int] = [
        "name": 24,
        "description": 36,
        "author": 56,
        "homepage": 1024,
        "version": 36,
    ]

    private static let supportedSources = ["kw", "kg", "tx", "wy", "mg", "local"]
    private static let supportedQualities: [String: [String]] = [
        "kw": ["128k", "320k", "flac", "flac24bit"],
        "kg": ["128k", "320k", "flac", "flac24bit"],
        "tx": ["128k", "320k", "flac", "flac24bit"],
        "wy": ["128k", "320k", "flac", "flac24bit"],
        "mg": ["128k", "320k", "flac", "flac24bit"],
        "local": [],
    ]
    private static let supportedActions: [String: [MusicSourceAction]] = [
        "kw": [.musicUrl],
        "kg": [.musicUrl],
        "tx": [.musicUrl],
        "wy": [.musicUrl],
        "mg": [.musicUrl],
        "local": [.musicUrl, .lyric, .pic],
    ]

    static func importSource(
        script: String,
        fileName: String? = nil,
        existingID: String? = nil,
        importedAt: Date? = nil
    ) throws -> ImportedMusicSource {
        let header = try extractLeadingComment(from: script)
        let metadata = parseMetadata(from: header)

        let sourceID = existingID ?? generateSourceID()
        let capabilities: [MusicSourceCapability]
        let parseErrorMessage: String?

        do {
            capabilities = try parseCapabilities(from: script, fileName: fileName, metadata: metadata)
            parseErrorMessage = nil
        } catch {
            capabilities = []
            parseErrorMessage = error.localizedDescription
        }

        return ImportedMusicSource(
            id: sourceID,
            name: metadata.name,
            description: metadata.description,
            author: metadata.author,
            homepage: metadata.homepage,
            version: metadata.version,
            allowShowUpdateAlert: true,
            script: script,
            capabilities: capabilities.sorted { $0.source < $1.source },
            parseErrorMessage: parseErrorMessage,
            importedAt: importedAt ?? .now,
            originalFileName: fileName
        )
    }

    static func readScript(from fileURL: URL) throws -> String {
        let isScoped = fileURL.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: fileURL)
        return try readScript(from: data)
    }

    static func readScript(from data: Data) throws -> String {
        for encoding in candidateEncodings {
            if let content = String(data: data, encoding: encoding) {
                return content
            }
        }

        throw MusicSourceParseError.unsupportedFileEncoding
    }

    private static var candidateEncodings: [String.Encoding] {
        return [
            .utf8,
            .unicode,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
        ]
    }

    private static func scriptRuntimeEnvironment(fileName: String?, script: String) -> String {
        let normalizedFileName = fileName?.lowercased()
        if normalizedFileName == "latest.js" || script.contains("lx-music-api-server") {
            return "desktop"
        }
        return "mobile"
    }

    private static func scriptRuntimeRawScript(fileName: String?, script: String) -> String {
        guard scriptRuntimeEnvironment(fileName: fileName, script: script) == "desktop" else { return script }
        if script.hasSuffix("\n\n") { return script }
        if script.hasSuffix("\n") { return script + "\n" }
        return script + "\n\n"
    }

    private static func extractLeadingComment(from script: String) throws -> String {
        let pattern = #"^/\*[\s\S]+?\*/"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(script.startIndex..., in: script)

        guard let match = regex.firstMatch(in: script, range: range),
              match.range.location != NSNotFound,
              let swiftRange = Range(match.range, in: script) else {
            throw MusicSourceParseError.invalidSourceFile
        }

        return String(script[swiftRange])
    }

    private static func parseMetadata(from comment: String) -> (
        name: String,
        description: String,
        author: String,
        homepage: String,
        version: String
    ) {
        let regex = try? NSRegularExpression(pattern: #"^\s?\*\s?@(\w+)\s(.+)$"#)
        var values: [String: String] = [:]

        for line in comment.components(separatedBy: .newlines) {
            let range = NSRange(line.startIndex..., in: line)
            guard let regex,
                  let match = regex.firstMatch(in: line, range: range),
                  match.numberOfRanges == 3,
                  let keyRange = Range(match.range(at: 1), in: line),
                  let valueRange = Range(match.range(at: 2), in: line) else {
                continue
            }

            let key = String(line[keyRange])
            guard infoLimits[key] != nil else { continue }
            values[key] = String(line[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        for (key, limit) in infoLimits {
            let original = values[key, default: ""]
            values[key] = original.count > limit ? String(original.prefix(limit)) + "..." : original
        }

        let fallbackName = "user_api_\(DateFormatter.localizedString(from: .now, dateStyle: .short, timeStyle: .short))"

        return (
            name: values["name"].flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName,
            description: values["description", default: ""],
            author: values["author", default: ""],
            homepage: values["homepage", default: ""],
            version: values["version", default: ""]
        )
    }

    private static func generateSourceID() -> String {
        let random = String(format: "%03d", Int.random(in: 0...999))
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        return "user_api_\(random)_\(timestamp)"
    }

    private static func parseCapabilities(
        from script: String,
        fileName: String?,
        metadata: (name: String, description: String, author: String, homepage: String, version: String)
    ) throws -> [MusicSourceCapability] {
        guard let context = JSContext() else {
            throw MusicSourceParseError.javaScriptEnvironmentUnavailable
        }

        var scriptException: MusicSourceParseError?
        context.exceptionHandler = { _, exception in
            let message = exception?.toString() ?? "Unknown JavaScript error"
            scriptException = .javaScriptExecutionFailed(message)
        }

        let md5Block: @convention(block) (String) -> String = { input in
            Insecure.MD5.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
        }
        let debugLogBlock: @convention(block) (String) -> Void = { message in
            print("[source-parse:sha256] \(message)")
        }
        context.setObject(md5Block, forKeyedSubscript: "__lx_md5__" as NSString)
        context.setObject(debugLogBlock, forKeyedSubscript: "__lx_debug_log__" as NSString)

        let preload = try makePreloadScript(
            rawScript: script,
            fileName: fileName,
            metadata: metadata
        )

        context.evaluateScript(preload)
        if let scriptException { throw scriptException }

        context.evaluateScript(script)
        if let scriptException { throw scriptException }

        context.evaluateScript("if (typeof globalThis.__lx_install_sha256_hooks__ === 'function') globalThis.__lx_install_sha256_hooks__();")
        if let scriptException { throw scriptException }

        _ = context.evaluateScript("void 0")
        if let scriptException { throw scriptException }

        guard let state = context.objectForKeyedSubscript("__lx_parse_state__"),
              let initData = state.forProperty("initData"),
              !initData.isUndefined,
              !initData.isNull else {
            throw MusicSourceParseError.missingInitInfo
        }

        guard let rawInit = initData.toObject() as? [String: Any],
              let rawSources = rawInit["sources"] as? [String: Any] else {
            throw MusicSourceParseError.invalidInitInfo("缺少 sources 字段")
        }

        var capabilities: [MusicSourceCapability] = []

        for source in supportedSources {
            guard let info = rawSources[source] as? [String: Any] else { continue }
            guard (info["type"] as? String) == MusicSourceKind.music.rawValue else { continue }

            let rawActions = info["actions"] as? [String] ?? []
            let rawQualitys = info["qualitys"] as? [String] ?? []

            let actions = supportedActions[source, default: []].filter { rawActions.contains($0.rawValue) }
            let qualitys = supportedQualities[source, default: []].filter { rawQualitys.contains($0) }

            capabilities.append(
                MusicSourceCapability(
                    source: source,
                    type: .music,
                    actions: actions,
                    qualitys: qualitys
                )
            )
        }

        return capabilities
    }

    private static func makePreloadScript(
        rawScript: String,
        fileName: String?,
        metadata: (name: String, description: String, author: String, homepage: String, version: String)
    ) throws -> String {
        let info: [String: String] = [
            "name": metadata.name,
            "description": metadata.description,
            "author": metadata.author,
            "homepage": metadata.homepage,
            "version": metadata.version,
            "rawScript": scriptRuntimeRawScript(fileName: fileName, script: rawScript),
        ]

        let infoData = try JSONSerialization.data(withJSONObject: info, options: [])
        let infoJSON = String(decoding: infoData, as: UTF8.self)
        let runtimeEnvironment = scriptRuntimeEnvironment(fileName: fileName, script: rawScript)

        return #"""
        (() => {
          const currentScriptInfo = \#(infoJSON);
          const EVENT_NAMES = {
            request: 'request',
            inited: 'inited',
            updateAlert: 'updateAlert',
          };
          const state = {
            initData: null,
            updateAlertData: null,
            requestHandler: null,
          };

          const bytesToString = (bytes) => {
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

          const stringToBytes = (input) => {
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

          globalThis.__lx_emit_sha256_debug__ = (payload) => {
            try {
              __lx_debug_log__(JSON.stringify(payload));
            } catch (_) {}
          };

        \#(MusicSourceRuntimePreload.sha256HookScript)

          const decodeBase64 = (input) => {
            const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
            let str = input.replace(/=+$/, '');
            let output = [];
            let buffer = 0;
            let bits = 0;

            for (let i = 0; i < str.length; i++) {
              const value = chars.indexOf(str[i]);
              if (value < 0) continue;
              buffer = (buffer << 6) | value;
              bits += 6;
              if (bits >= 8) {
                bits -= 8;
                output.push((buffer >> bits) & 0xff);
              }
            }

            return output;
          };

          const encodeBase64 = (bytes) => {
            const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
            let output = '';
            let i = 0;

            while (i < bytes.length) {
              const a = bytes[i++];
              const b = i < bytes.length ? bytes[i++] : NaN;
              const c = i < bytes.length ? bytes[i++] : NaN;
              const triple = (a << 16) | ((b || 0) << 8) | (c || 0);

              output += chars[(triple >> 18) & 63];
              output += chars[(triple >> 12) & 63];
              output += Number.isNaN(b) ? '=' : chars[(triple >> 6) & 63];
              output += Number.isNaN(c) ? '=' : chars[triple & 63];
            }

            return output;
          };

          globalThis.console = globalThis.console || {
            log() {},
            info() {},
            warn() {},
            error() {},
          };

          globalThis.setTimeout = globalThis.setTimeout || function() { return 0; };
          globalThis.clearTimeout = globalThis.clearTimeout || function() {};

          globalThis.lx = {
            EVENT_NAMES,
            request(url, options, callback) {
              if (typeof callback === 'function') callback(new Error('request is unavailable during parse'), null, null);
              return function() {};
            },
            send(eventName, data) {
              switch (eventName) {
                case EVENT_NAMES.inited:
                  state.initData = data;
                  return Promise.resolve();
                case EVENT_NAMES.updateAlert:
                  state.updateAlertData = data;
                  return Promise.resolve();
                default:
                  return Promise.reject(new Error('Unknown event: ' + eventName));
              }
            },
            on(eventName, handler) {
              if (eventName !== EVENT_NAMES.request) return Promise.reject(new Error('Unsupported event: ' + eventName));
              state.requestHandler = handler;
              return Promise.resolve();
            },
            utils: {
              crypto: {
                aesEncrypt() {
                  throw new Error('aesEncrypt is unavailable during parse');
                },
                rsaEncrypt() {
                  throw new Error('rsaEncrypt is unavailable during parse');
                },
                randomBytes(size) {
                  const byteArray = new Uint8Array(size);
                  for (let i = 0; i < size; i++) byteArray[i] = Math.floor(Math.random() * 256);
                  return byteArray;
                },
                md5(str) {
                  return __lx_md5__(String(str));
                },
              },
              buffer: {
                from(input, encoding) {
                  if (typeof input === 'string') {
                    switch (encoding) {
                      case 'base64':
                        return new Uint8Array(decodeBase64(input));
                      case 'hex':
                        return new Uint8Array(input.match(/.{1,2}/g).map(byte => parseInt(byte, 16)));
                      default:
                        return new Uint8Array(stringToBytes(input));
                    }
                  }
                  if (Array.isArray(input)) return new Uint8Array(input);
                  throw new Error('Unsupported buffer input');
                },
                bufToString(buf, format) {
                  const bytes = Array.from(buf);
                  switch (format) {
                    case 'base64':
                      return encodeBase64(bytes);
                    case 'hex':
                      return bytes.reduce((str, byte) => str + byte.toString(16).padStart(2, '0'), '');
                    case 'utf8':
                    case 'utf-8':
                    default:
                      return bytesToString(bytes);
                  }
                },
              },
            },
            currentScriptInfo,
            version: '2.0.0',
            env: '\#(runtimeEnvironment)',
          };

          globalThis.__lx_parse_state__ = state;
        })();
        """#
    }
}
