import AVFoundation
import SwiftUI
#if os(iOS)
import UIKit
import UniformTypeIdentifiers
#endif

struct TrackExportMenuItem: View {
    let track: Track
    #if !os(iOS)
    @State private var pendingSharedFile: SharedTrackFile?
    #endif
    @State private var isPreparingExport = false

    var body: some View {
        if canExportTrackFile(track) {
            Button {
                guard !isPreparingExport else { return }
                isPreparingExport = true
                Task {
                    let item = await prepareSharedTrackFile(for: track)
                    #if os(iOS)
                    await MainActor.run {
                        if let item {
                            presentActivitySheet(for: item)
                        }
                    }
                    #else
                    pendingSharedFile = item
                    #endif
                    isPreparingExport = false
                }
            } label: {
                Label("保存到文件", systemImage: "square.and.arrow.up")
            }
            .disabled(isPreparingExport)
            #if !os(iOS)
            .sheet(item: $pendingSharedFile) { item in
                CachedMediaShareFallbackView(item: item)
            }
            #endif
        }
    }
}

struct SharedTrackFile: Identifiable {
    let url: URL
    let title: String

    var id: String { url.standardizedFileURL.path }
}

func canExportTrackFile(_ track: Track) -> Bool {
    guard let audioURL = track.audioURL,
          audioURL.isFileURL else { return false }
    return FileManager.default.fileExists(atPath: audioURL.path)
}

func prepareSharedTrackFile(for track: Track) async -> SharedTrackFile? {
    guard let audioURL = track.audioURL,
          audioURL.isFileURL,
          FileManager.default.fileExists(atPath: audioURL.path) else { return nil }

    let exportURL = await makeShareableTrackFileURL(for: track, sourceURL: audioURL)
    let title = [track.title, track.artist]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " - ")

    return SharedTrackFile(
        url: exportURL,
        title: title.isEmpty ? track.title : title
    )
}

private func makeShareableTrackFileURL(for track: Track, sourceURL: URL) async -> URL {
    let fileManager = FileManager.default
    let ext = sourceURL.pathExtension
    let baseName = sanitizedExportFileName(for: track)
    let fileName = ext.isEmpty ? baseName : "\(baseName).\(ext)"
    let exportDirectory = fileManager.temporaryDirectory
        .appendingPathComponent("XMusicSharedCache", isDirectory: true)

    do {
        try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        let destinationURL = uniqueTrackExportURL(
            in: exportDirectory,
            preferredFileName: fileName
        )
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }
        if let metadataOutputURL = await exportTrackWithMetadataIfPossible(
            track: track,
            sourceURL: sourceURL,
            destinationURL: destinationURL
        ) {
            return metadataOutputURL
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    } catch {
        #if DEBUG
        print("[export] Failed to prepare shareable media file: \(error)")
        #endif
        return sourceURL
    }
}

private func sanitizedExportFileName(for track: Track) -> String {
    let title = track.title.trimmingCharacters(in: .whitespacesAndNewlines)
    let artist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
    let album = track.album.trimmingCharacters(in: .whitespacesAndNewlines)

    let rawName: String
    if !title.isEmpty, !artist.isEmpty {
        rawName = "\(title) - \(artist)"
    } else if !title.isEmpty {
        rawName = title
    } else if !artist.isEmpty {
        rawName = artist
    } else if !album.isEmpty {
        rawName = album
    } else {
        rawName = "XMusic Cached Track"
    }

    let invalidCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>")
    let sanitizedScalars = rawName.unicodeScalars.map { scalar -> Character in
        invalidCharacters.contains(scalar) ? "_" : Character(scalar)
    }
    let sanitized = String(sanitizedScalars)
        .trimmingCharacters(in: .whitespacesAndNewlines)

    return sanitized.isEmpty ? "XMusic Cached Track" : sanitized
}

private func uniqueTrackExportURL(in directory: URL, preferredFileName: String) -> URL {
    let fileManager = FileManager.default
    let preferredURL = directory.appendingPathComponent(preferredFileName, isDirectory: false)
    guard fileManager.fileExists(atPath: preferredURL.path) else {
        return preferredURL
    }

    let stem = preferredURL.deletingPathExtension().lastPathComponent
    let ext = preferredURL.pathExtension
    for index in 2...200 {
        let candidateName = ext.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(ext)"
        let candidateURL = directory.appendingPathComponent(candidateName, isDirectory: false)
        if !fileManager.fileExists(atPath: candidateURL.path) {
            return candidateURL
        }
    }

    return directory.appendingPathComponent(UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)"), isDirectory: false)
}

private func exportTrackWithMetadataIfPossible(
    track: Track,
    sourceURL: URL,
    destinationURL: URL
) async -> URL? {
    let asset = AVURLAsset(url: sourceURL)
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
        return nil
    }
    guard let fileType = supportedExportFileType(for: sourceURL, exportSession: exportSession),
          let artworkData = await exportArtworkData(for: track) else {
        return nil
    }

    exportSession.outputURL = destinationURL
    exportSession.outputFileType = fileType
    exportSession.shouldOptimizeForNetworkUse = false
    exportSession.metadata = makeExportMetadata(for: track, artworkData: artworkData, fileType: fileType)

    do {
        try await exportSession.exportAsync()
        if exportSession.status == .completed {
            return destinationURL
        }
        try? FileManager.default.removeItem(at: destinationURL)
        return nil
    } catch {
        #if DEBUG
        print("[export] Failed to write metadata during export: \(error)")
        #endif
        try? FileManager.default.removeItem(at: destinationURL)
        return nil
    }
}

private func supportedExportFileType(for sourceURL: URL, exportSession: AVAssetExportSession) -> AVFileType? {
    let supported = exportSession.supportedFileTypes
    guard !supported.isEmpty else { return nil }

    for candidate in exportFileTypeCandidates(for: sourceURL) where supported.contains(candidate) {
        return candidate
    }

    // Fall back to the first supported type only for containers we know how to decorate safely.
    let safeFallbacks: [AVFileType] = [.m4a, .mp4, .mp3]
    return safeFallbacks.first(where: { supported.contains($0) })
}

private func exportFileTypeCandidates(for sourceURL: URL) -> [AVFileType] {
    switch sourceURL.pathExtension.lowercased() {
    case "m4a":
        return [.m4a, .mp4]
    case "mp3":
        return [.mp3]
    case "mp4":
        return [.mp4, .m4a]
    case "aac":
        return [.m4a, .mp4]
    case "wav":
        return [.wav]
    case "aif", "aiff":
        return [.aiff]
    case "caf":
        return [.caf]
    default:
        return []
    }
}

private func makeExportMetadata(for track: Track, artworkData: Data, fileType: AVFileType) -> [AVMetadataItem] {
    var items: [AVMetadataItem] = []

    let commonFields: [(AVMetadataIdentifier, String)] = [
        (.commonIdentifierTitle, track.title),
        (.commonIdentifierArtist, track.artist),
        (.commonIdentifierAlbumName, track.album),
    ]

    for (identifier, value) in commonFields {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { continue }
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = trimmed as NSString
        item.extendedLanguageTag = "und"
        items.append(item.copy() as? AVMetadataItem ?? item)
    }

    items.append(
        metadataItem(
            identifier: .commonIdentifierArtwork,
            value: artworkData as NSData,
            dataType: UTType.jpeg.identifier
        )
    )

    switch fileType {
    case .m4a, .mp4:
        items.append(contentsOf: iTunesMetadataItems(for: track, artworkData: artworkData))
    case .mp3:
        items.append(contentsOf: id3MetadataItems(for: track, artworkData: artworkData))
    default:
        break
    }

    return items
}

private func iTunesMetadataItems(for track: Track, artworkData: Data) -> [AVMetadataItem] {
    var items: [AVMetadataItem] = []

    let title = track.title.trimmingCharacters(in: .whitespacesAndNewlines)
    let artist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
    let album = track.album.trimmingCharacters(in: .whitespacesAndNewlines)

    if !title.isEmpty {
        items.append(metadataItem(identifier: .iTunesMetadataSongName, value: title as NSString))
    }
    if !artist.isEmpty {
        items.append(metadataItem(identifier: .iTunesMetadataArtist, value: artist as NSString))
        items.append(metadataItem(identifier: .iTunesMetadataAlbumArtist, value: artist as NSString))
    }
    if !album.isEmpty {
        items.append(metadataItem(identifier: .iTunesMetadataAlbum, value: album as NSString))
    }

    items.append(
        metadataItem(
            identifier: .iTunesMetadataCoverArt,
            value: artworkData as NSData,
            dataType: UTType.jpeg.identifier
        )
    )

    return items
}

private func id3MetadataItems(for track: Track, artworkData: Data) -> [AVMetadataItem] {
    var items: [AVMetadataItem] = []

    let title = track.title.trimmingCharacters(in: .whitespacesAndNewlines)
    let artist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
    let album = track.album.trimmingCharacters(in: .whitespacesAndNewlines)

    if !title.isEmpty {
        items.append(metadataItem(identifier: .id3MetadataTitleDescription, value: title as NSString))
    }
    if !artist.isEmpty {
        items.append(metadataItem(identifier: .id3MetadataLeadPerformer, value: artist as NSString))
    }
    if !album.isEmpty {
        items.append(metadataItem(identifier: .id3MetadataAlbumTitle, value: album as NSString))
    }

    items.append(
        metadataItem(
            identifier: .id3MetadataAttachedPicture,
            value: artworkData as NSData,
            dataType: UTType.jpeg.identifier
        )
    )

    return items
}

private func metadataItem(
    identifier: AVMetadataIdentifier,
    value: NSCopying & NSObjectProtocol,
    dataType: String? = nil
) -> AVMetadataItem {
    let item = AVMutableMetadataItem()
    item.identifier = identifier
    item.value = value
    item.dataType = dataType
    item.extendedLanguageTag = "und"
    return item.copy() as? AVMetadataItem ?? item
}

#if os(iOS)
private func exportArtworkData(for track: Track) async -> Data? {
    if let artworkURL = track.searchSong?.artworkURL {
        do {
            let (data, _) = try await URLSession.shared.data(from: artworkURL)
            if let image = UIImage(data: data),
               let jpegData = image.jpegData(compressionQuality: 0.92) {
                return jpegData
            }
        } catch {
            #if DEBUG
            print("[export] Failed to download artwork: \(error)")
            #endif
        }
    }

    let generated = makeFallbackArtworkImage(for: track)
    return generated.jpegData(compressionQuality: 0.92)
}

private func makeFallbackArtworkImage(for track: Track) -> UIImage {
    let colors = track.artwork.colors.isEmpty ? [Color.black, Color.gray] : track.artwork.colors
    let uiColors = colors.map(UIColor.init)
    let size = CGSize(width: 512, height: 512)
    let renderer = UIGraphicsImageRenderer(size: size)

    return renderer.image { context in
        let cgColors = uiColors.map(\.cgColor) as CFArray
        let locations: [CGFloat] = uiColors.count > 1 ? [0, 1] : [0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: locations) {
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        } else {
            uiColors.first?.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        context.cgContext.setFillColor(UIColor.white.withAlphaComponent(0.14).cgColor)
        context.cgContext.fillEllipse(in: CGRect(x: 48, y: 56, width: 260, height: 260))

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 42, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let artistAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 26, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.82)
        ]

        NSString(string: track.title).draw(
            in: CGRect(x: 42, y: 360, width: 428, height: 90),
            withAttributes: titleAttributes
        )
        NSString(string: track.artist).draw(
            in: CGRect(x: 42, y: 432, width: 428, height: 48),
            withAttributes: artistAttributes
        )
    }
}
#else
private func exportArtworkData(for track: Track) async -> Data? {
    _ = track
    return nil
}
#endif

#if os(iOS)
private extension AVAssetExportSession {
    func exportAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportAsynchronously {
                if let error = self.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

@MainActor
private func presentActivitySheet(for item: SharedTrackFile) {
    let controller = UIActivityViewController(
        activityItems: [TrackShareItemSource(item: item)],
        applicationActivities: nil
    )
    controller.excludedActivityTypes = [.assignToContact, .postToVimeo, .postToTencentWeibo, .postToWeibo]

    guard let presenter = topViewController() else { return }

    if let popover = controller.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(
            x: presenter.view.bounds.midX,
            y: presenter.view.bounds.midY,
            width: 1,
            height: 1
        )
    }

    presenter.present(controller, animated: true)
}

@MainActor
private func topViewController(
    from root: UIViewController? = UIApplication.shared
        .connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)?
        .rootViewController
) -> UIViewController? {
    if let navigation = root as? UINavigationController {
        return topViewController(from: navigation.visibleViewController)
    }
    if let tab = root as? UITabBarController {
        return topViewController(from: tab.selectedViewController)
    }
    if let presented = root?.presentedViewController {
        return topViewController(from: presented)
    }
    return root
}

private final class TrackShareItemSource: NSObject, UIActivityItemSource {
    private let item: SharedTrackFile

    init(item: SharedTrackFile) {
        self.item = item
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        item.url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        item.url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        item.title
    }
}
#else
private struct CachedMediaShareFallbackView: View {
    let item: SharedTrackFile

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(AppThemeTextColors.primary)
                    .multilineTextAlignment(.center)

                ShareLink(item: item.url) {
                    Label("分享缓存文件", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Text(item.url.lastPathComponent)
                    .font(.footnote)
                    .foregroundStyle(AppThemeTextColors.primary.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppBackgroundView().ignoresSafeArea())
        }
        .presentationDetents([.medium])
    }
}
#endif
