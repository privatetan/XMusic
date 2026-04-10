//
//  MusicSourceModels.swift
//  XMusic
//
//  Created by Codex on 2026/3/20.
//

import Foundation

enum PlaybackQualityPreference: String, CaseIterable, Identifiable {
    case hiresLossless = "flac24bit"
    case lossless = "flac"
    case high = "320k"
    case standard = "128k"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hiresLossless:
            return "Hi-Res 无损"
        case .lossless:
            return "无损 FLAC"
        case .high:
            return "高品质 320k"
        case .standard:
            return "标准 128k"
        }
    }

    var subtitle: String {
        switch self {
        case .hiresLossless:
            return "优先 24bit / Hi-Res，无可用时自动降级"
        case .lossless:
            return "优先 FLAC，无可用时自动降级"
        case .high:
            return "优先 320k，无可用时自动切到最近可用音质"
        case .standard:
            return "优先 128k，更省流量和缓存空间"
        }
    }

    var shortLabel: String {
        switch self {
        case .hiresLossless:
            return "Hi-Res"
        case .lossless:
            return "FLAC"
        case .high:
            return "320k"
        case .standard:
            return "128k"
        }
    }

    var symbol: String {
        switch self {
        case .hiresLossless:
            return "hifispeaker.fill"
        case .lossless:
            return "waveform.path"
        case .high:
            return "bolt.fill"
        case .standard:
            return "antenna.radiowaves.left.and.right"
        }
    }
}

enum MusicSourceAction: String, Codable, CaseIterable, Hashable {
    case musicUrl
    case lyric
    case pic

    var title: String {
        switch self {
        case .musicUrl:
            return "音乐地址"
        case .lyric:
            return "歌词"
        case .pic:
            return "封面"
        }
    }
}

enum MusicSourceKind: String, Codable, Hashable {
    case music
}

struct MusicSourceCapability: Codable, Hashable, Identifiable {
    var id: String { source }

    let source: String
    let type: MusicSourceKind
    let actions: [MusicSourceAction]
    let qualitys: [String]
}

struct ImportedMusicSource: Codable, Hashable, Identifiable {
    let id: String
    var name: String
    var description: String
    var author: String
    var homepage: String
    var version: String
    var allowShowUpdateAlert: Bool
    var script: String
    var capabilities: [MusicSourceCapability]
    var parseErrorMessage: String?
    var importedAt: Date
    var originalFileName: String?

    var hasRuntimeParseError: Bool {
        parseErrorMessage != nil
    }

    func supports(source platformSource: String, action: MusicSourceAction) -> Bool {
        capabilities.contains { capability in
            capability.source == platformSource && capability.actions.contains(action)
        }
    }
}

struct MusicSourceSnapshot: Codable {
    var activeSourceID: String?
    var sources: [ImportedMusicSource]
}

struct PlaybackFieldCheck: Identifiable, Hashable {
    let id = UUID()
    let field: String
    let actualValue: String
    let isPresent: Bool
    let note: String?
}

struct PlaybackDebugInfo: Identifiable, Hashable {
    let id = UUID()
    let originalURL: String
    let preparedURL: String
    let usedLocalCache: Bool
    let localPath: String?
    let fileExists: Bool
    let requestedSource: String?
    let resolvedSource: String?
    let requestedQuality: String?
    let resolvedQuality: String?
    let resolutionStrategy: String?
    let resolutionNote: String?
    let usedResolverCache: Bool
    let attemptedSources: [String]
    let legacyInfoJSON: String?
    let fieldChecks: [PlaybackFieldCheck]
    let requestTrace: [String]

    init(
        originalURL: String,
        preparedURL: String,
        usedLocalCache: Bool,
        localPath: String?,
        fileExists: Bool,
        requestedSource: String? = nil,
        resolvedSource: String? = nil,
        requestedQuality: String? = nil,
        resolvedQuality: String? = nil,
        resolutionStrategy: String? = nil,
        resolutionNote: String? = nil,
        usedResolverCache: Bool = false,
        attemptedSources: [String] = [],
        legacyInfoJSON: String? = nil,
        fieldChecks: [PlaybackFieldCheck] = [],
        requestTrace: [String] = []
    ) {
        self.originalURL = originalURL
        self.preparedURL = preparedURL
        self.usedLocalCache = usedLocalCache
        self.localPath = localPath
        self.fileExists = fileExists
        self.requestedSource = requestedSource
        self.resolvedSource = resolvedSource
        self.requestedQuality = requestedQuality
        self.resolvedQuality = resolvedQuality
        self.resolutionStrategy = resolutionStrategy
        self.resolutionNote = resolutionNote
        self.usedResolverCache = usedResolverCache
        self.attemptedSources = attemptedSources
        self.legacyInfoJSON = legacyInfoJSON
        self.fieldChecks = fieldChecks
        self.requestTrace = requestTrace
    }
}

struct PlaybackResolutionResult {
    let playableURL: URL
    let debugInfo: PlaybackDebugInfo
}

struct MediaCacheSummary: Hashable {
    let fileCount: Int
    let totalBytes: Int64

    static let empty = MediaCacheSummary(fileCount: 0, totalBytes: 0)

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    var isEmpty: Bool {
        fileCount == 0 || totalBytes == 0
    }
}

enum MusicSourceParseError: LocalizedError {
    case invalidSourceFile
    case unsupportedFileEncoding
    case javaScriptEnvironmentUnavailable
    case javaScriptExecutionFailed(String)
    case missingInitInfo
    case invalidInitInfo(String)

    var errorDescription: String? {
        switch self {
        case .invalidSourceFile:
            return "无效的自定义源文件"
        case .unsupportedFileEncoding:
            return "无法识别该源文件的文本编码"
        case .javaScriptEnvironmentUnavailable:
            return "当前设备无法初始化音乐源脚本解析环境"
        case let .javaScriptExecutionFailed(message):
            return "音乐源脚本执行失败：\(message)"
        case .missingInitInfo:
            return "脚本没有声明初始化结果，请检查是否调用了 lx.send(lx.EVENT_NAMES.inited, ...)"
        case let .invalidInitInfo(message):
            return "音乐源初始化信息无效：\(message)"
        }
    }
}
