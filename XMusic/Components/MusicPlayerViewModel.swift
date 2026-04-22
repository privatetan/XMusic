//
//  MusicPlayerViewModel.swift
//  XMusic
//
//  Created by Codex on 2026/3/20.
//

import AVFoundation
import Combine
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if os(iOS)
import MediaPlayer
#endif

private struct PersistedColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    @MainActor
    init(color: Color) {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var resolvedRed: CGFloat = 1
        var resolvedGreen: CGFloat = 1
        var resolvedBlue: CGFloat = 1
        var resolvedAlpha: CGFloat = 1
        uiColor.getRed(&resolvedRed, green: &resolvedGreen, blue: &resolvedBlue, alpha: &resolvedAlpha)
        red = Double(resolvedRed)
        green = Double(resolvedGreen)
        blue = Double(resolvedBlue)
        alpha = Double(resolvedAlpha)
        #elseif canImport(AppKit)
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
        red = Double(nsColor.redComponent)
        green = Double(nsColor.greenComponent)
        blue = Double(nsColor.blueComponent)
        alpha = Double(nsColor.alphaComponent)
        #else
        red = 1
        green = 1
        blue = 1
        alpha = 1
        #endif
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

private struct PersistedArtworkPalette: Codable {
    let colors: [PersistedColor]
    let glow: PersistedColor
    let symbol: String
    let label: String

    @MainActor
    init(artwork: ArtworkPalette) {
        colors = artwork.colors.map(PersistedColor.init)
        glow = PersistedColor(color: artwork.glow)
        symbol = artwork.symbol
        label = artwork.label
    }

    var artworkPalette: ArtworkPalette {
        ArtworkPalette(
            colors: colors.map(\.swiftUIColor),
            glow: glow.swiftUIColor,
            symbol: symbol,
            label: label
        )
    }
}

private struct PersistedSearchSong: Codable {
    let id: String
    let source: String
    let title: String
    let artist: String
    let album: String
    let durationText: String
    let artworkURL: String?
    let qualities: [String]
    let legacyInfoJSON: String

    @MainActor
    init(song: SearchSong) {
        id = song.id
        source = song.source.rawValue
        title = song.title
        artist = song.artist
        album = song.album
        durationText = song.durationText
        artworkURL = song.artworkURL?.absoluteString
        qualities = song.qualities
        legacyInfoJSON = song.legacyInfoJSON
    }

    var searchSong: SearchSong? {
        guard let source = SearchPlatformSource(rawValue: source) else { return nil }
        return SearchSong(
            id: id,
            source: source,
            title: title,
            artist: artist,
            album: album,
            durationText: durationText,
            artworkURL: artworkURL.flatMap(URL.init(string:)),
            qualities: qualities,
            legacyInfoJSON: legacyInfoJSON
        )
    }
}

private struct PersistedTrack: Codable {
    let title: String
    let artist: String
    let album: String
    let blurb: String
    let genre: String
    let duration: TimeInterval
    let audioURL: String?
    let artwork: PersistedArtworkPalette
    let searchSong: PersistedSearchSong?
    let remoteArtworkURL: String?
    let sourceName: String?

    @MainActor
    init(track: Track) {
        title = track.title
        artist = track.artist
        album = track.album
        blurb = track.blurb
        genre = track.genre
        duration = track.duration
        audioURL = track.audioURL?.absoluteString
        artwork = PersistedArtworkPalette(artwork: track.artwork)
        searchSong = track.searchSong.map(PersistedSearchSong.init)
        remoteArtworkURL = track.remoteArtworkURL?.absoluteString
        sourceName = track.sourceName
    }

    var track: Track {
        Track(
            title: title,
            artist: artist,
            album: album,
            blurb: blurb,
            genre: genre,
            duration: duration,
            audioURL: audioURL.flatMap(URL.init(string:)),
            artwork: artwork.artworkPalette,
            searchSong: searchSong?.searchSong,
            remoteArtworkURL: remoteArtworkURL.flatMap(URL.init(string:)),
            sourceName: sourceName
        )
    }
}

private final class SearchPlaybackResolverBox {
    let resolve: @MainActor (SearchSong) async throws -> PlaybackResolutionResult

    init(resolve: @escaping @MainActor (SearchSong) async throws -> PlaybackResolutionResult) {
        self.resolve = resolve
    }
}

private struct PlaybackRequest {
    let track: Track
    let queue: [Track]
    let autoPlay: Bool
}

@MainActor
final class PlaybackTimeline: ObservableObject {
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 1
}

@MainActor
final class MusicPlayerViewModel: ObservableObject {
    @Published var currentTrack: Track?
    @Published var selectedTab: AppTab = .browse
    @Published var isNowPlayingPresented = false
    @Published var isPlaying = false
    @Published var volume: Double = 0.85
    let playbackTimeline = PlaybackTimeline()

    private let player = AVPlayer()
    private var queue: [Track] = []
    @Published private(set) var cachedTracks: [Track] = []
    private var currentIndex = 0
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var searchPlaybackResolverBox: SearchPlaybackResolverBox?
    private var pendingResolveTask: Task<Void, Never>?
    private let lastPlayedTrackStorageKey = "XMusic.LastPlayedTrack"
    private let cachedTracksStorageKey = "XMusic.CachedTracks"
    private var lastAutoAdvancedTrackID: UUID?
    private var currentLoadToken = UUID()
    private var hasPreparedSystemPlayback = false
    private var interruptionObserver: NSObjectProtocol?
    private var shouldResumeAfterInterruption = false
    private var timeControlStatusObservation: NSKeyValueObservation?

    #if os(iOS)
    private var nowPlayingInfo: [String: Any] = [:]
    private var cachedNowPlayingArtworkKey: String?
    private var cachedNowPlayingArtwork: MPMediaItemArtwork?
    private var nowPlayingArtworkLoadTask: Task<Void, Never>?
    private var loadingNowPlayingArtworkURL: URL?
    private var systemVolumeObserver: NSKeyValueObservation?
    private weak var systemVolumeSlider: UISlider?
    #endif

    init() {
        configurePlayerForStreaming()
        bindPlayer()
        #if os(iOS)
        player.volume = 1
        bindSystemVolume()
        #else
        setVolume(volume)
        #endif
        queue = []
        cachedTracks = loadCachedTracks()
        clearPersistedTrack()
        updateNowPlayingInfo()
    }

    var currentTime: TimeInterval {
        get { playbackTimeline.currentTime }
        set { playbackTimeline.currentTime = newValue }
    }

    var duration: TimeInterval {
        get { playbackTimeline.duration }
        set { playbackTimeline.duration = newValue }
    }

    func isCurrentTrack(_ track: Track) -> Bool {
        currentTrack?.storageKey == track.storageKey
    }

    deinit {
        pendingResolveTask?.cancel()

        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }

        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }

        timeControlStatusObservation?.invalidate()

        #if os(iOS)
        systemVolumeObserver?.invalidate()
        nowPlayingArtworkLoadTask?.cancel()
        #endif
    }

    func play(_ track: Track, from tracks: [Track]? = nil, preferCachedQueue: Bool = false) {
        guard !isCurrentTrack(track) else { return }
        performPlayback(
            PlaybackRequest(
                track: track,
                queue: playbackQueue(for: track, preferredQueue: tracks, preferCachedQueue: preferCachedQueue),
                autoPlay: true
            )
        )
    }

    func setSearchPlaybackResolver(_ resolver: @escaping @MainActor (SearchSong) async throws -> PlaybackResolutionResult) {
        searchPlaybackResolverBox = SearchPlaybackResolverBox(resolve: resolver)
    }

    func presentNowPlaying(animated: Bool = true) {
        guard currentTrack != nil else { return }
        guard !isNowPlayingPresented else { return }

        setNowPlayingPresented(true, animated: animated)
    }

    func dismissNowPlaying(animated: Bool = false) {
        guard isNowPlayingPresented else { return }
        setNowPlayingPresented(false, animated: animated)
    }

    func togglePlayback() {
        guard let currentTrack else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
            updateNowPlayingInfo()
            return
        }

        if let searchSong = currentTrack.searchSong,
           shouldResolveSearchTrack(currentTrack) {
            currentLoadToken = UUID()
            let loadToken = currentLoadToken
            resolveSearchTrack(searchSong, trackID: currentTrack.id, autoPlay: true, loadToken: loadToken)
            return
        }

        if player.currentItem == nil {
            performPlayback(
                PlaybackRequest(
                    track: currentTrack,
                    queue: playbackQueue(for: currentTrack, preferredQueue: queue, preferCachedQueue: false),
                    autoPlay: true
                )
            )
            return
        }

        activateAudioSession()
        player.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func playNext() {
        guard !queue.isEmpty else { return }

        currentIndex = (currentIndex + 1) % queue.count
        performPlayback(
            PlaybackRequest(
                track: queue[currentIndex],
                queue: queue,
                autoPlay: true
            )
        )
    }

    func playPrevious() {
        guard !queue.isEmpty else { return }

        if currentTime > 5 {
            seek(to: 0)
            return
        }

        currentIndex = (currentIndex - 1 + queue.count) % queue.count
        performPlayback(
            PlaybackRequest(
                track: queue[currentIndex],
                queue: queue,
                autoPlay: true
            )
        )
    }

    func seek(to time: TimeInterval) {
        let clampedTime = max(0, min(time, duration))
        currentTime = clampedTime
        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        player.seek(to: cmTime)
        updateNowPlayingInfo()
    }

    func setVolume(_ value: Double) {
        volume = max(0, min(value, 1))
        #if os(iOS)
        guard let systemVolumeSlider else { return }
        let targetValue = Float(volume)
        guard abs(systemVolumeSlider.value - targetValue) > 0.0001 else { return }
        systemVolumeSlider.setValue(targetValue, animated: false)
        systemVolumeSlider.sendActions(for: .valueChanged)
        #else
        player.volume = Float(volume)
        #endif
    }

    #if os(iOS)
    func attachSystemVolumeSlider(_ slider: UISlider) {
        systemVolumeSlider = slider
        let currentValue = Float(volume)
        if abs(slider.value - currentValue) > 0.0001 {
            slider.setValue(currentValue, animated: false)
        }
    }
    #endif

    private func bindPlayer() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        let player = self.player

        timeControlStatusObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                self?.syncPlaybackState(with: player.timeControlStatus)
            }
        }

        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let seconds = CMTimeGetSeconds(time)
            let itemDuration = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)

            Task { @MainActor [weak self] in
                guard let self else { return }

                if seconds.isFinite {
                    currentTime = seconds
                }

                if itemDuration.isFinite, itemDuration > 0 {
                    duration = itemDuration
                }

                let effectiveDuration = itemDuration.isFinite && itemDuration > 0 ? itemDuration : duration
                if let currentTrack,
                   isPlaying,
                   effectiveDuration > 1,
                   seconds.isFinite,
                   seconds >= effectiveDuration - 0.2 {
                    advanceQueueIfNeeded(afterFinishing: currentTrack.id)
                }

                updateNowPlayingInfo()
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let trackID = currentTrack?.id else { return }
                advanceQueueIfNeeded(afterFinishing: trackID)
            }
        }
    }

    private func setNowPlayingPresented(_ isPresented: Bool, animated: Bool) {
        if animated {
            withAnimation(nowPlayingAnimation(isPresented: isPresented)) {
                isNowPlayingPresented = isPresented
            }
        } else {
            isNowPlayingPresented = isPresented
        }
    }

    private func nowPlayingAnimation(isPresented: Bool) -> Animation {
        .spring(response: 0.40, dampingFraction: 0.78, blendDuration: 0.12)
    }

    private func performPlayback(_ request: PlaybackRequest) {
        queue = request.queue.isEmpty ? [request.track] : request.queue
        if let index = queue.firstIndex(of: request.track) {
            currentIndex = index
        } else {
            queue = [request.track]
            currentIndex = 0
        }

        beginPlayback(for: queue[currentIndex], autoPlay: request.autoPlay)
    }

    private func beginPlayback(for track: Track, autoPlay: Bool) {
        pendingResolveTask?.cancel()
        pendingResolveTask = nil
        lastAutoAdvancedTrackID = nil
        registerCachedTrackIfNeeded(track)

        // Stop current playback immediately to avoid overlapping audio.
        player.pause()
        player.replaceCurrentItem(with: nil)

        currentLoadToken = UUID()
        let loadToken = currentLoadToken
        currentTrack = track
        currentTime = 0
        duration = max(track.duration, 1)
        isPlaying = false
        updateNowPlayingInfo()

        if let searchSong = track.searchSong, shouldResolveSearchTrack(track) {
            resolveSearchTrack(searchSong, trackID: track.id, autoPlay: autoPlay, loadToken: loadToken)
            return
        }

        guard let url = track.audioURL else { return }

        persistCurrentTrack(track)
        loadResolvedURL(url, autoPlay: autoPlay)
    }

    private func loadResolvedURL(_ url: URL, autoPlay: Bool) {
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 2
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        player.replaceCurrentItem(with: item)

        if autoPlay {
            activateAudioSession()
            player.play()
            isPlaying = true
        } else {
            player.pause()
            isPlaying = false
        }
        updateNowPlayingInfo()
    }

    private func shouldResolveSearchTrack(_ track: Track) -> Bool {
        guard track.searchSong != nil else { return false }
        guard let audioURL = track.audioURL else { return true }
        guard audioURL.isFileURL else { return false }
        return !FileManager.default.fileExists(atPath: audioURL.path)
    }

    private func playbackQueue(for track: Track, preferredQueue: [Track]?, preferCachedQueue: Bool) -> [Track] {
        if preferCachedQueue {
            let cachedQueue = playableCachedTracks()
            if let cachedIndex = cachedQueue.firstIndex(where: { cachedTrackKey(for: $0) == cachedTrackKey(for: track) }) {
                currentIndex = cachedIndex
                return cachedQueue
            }
        }
        if let preferredQueue, !preferredQueue.isEmpty {
            return preferredQueue
        }
        if !queue.isEmpty {
            return queue
        }
        return [track]
    }

    private func advanceQueueIfNeeded(afterFinishing trackID: UUID) {
        guard lastAutoAdvancedTrackID != trackID else { return }
        guard currentTrack?.id == trackID else { return }
        lastAutoAdvancedTrackID = trackID
        playNext()
    }

    private func resolveSearchTrack(_ song: SearchSong, trackID: UUID, autoPlay: Bool, loadToken: UUID) {
        guard let resolverBox = searchPlaybackResolverBox else {
            player.pause()
            isPlaying = false
            return
        }

        print(
            """
            [XMusic][PlaybackResolve] begin
            source=\(song.source.rawValue)
            title=\(song.title)
            artist=\(song.artist)
            """
        )

        pendingResolveTask = Task { [weak self] in
            guard let self else { return }
            do {
                let resolution = try await resolverBox.resolve(song)
                guard !Task.isCancelled else { return }
                guard currentLoadToken == loadToken else { return }
                guard let index = queue.firstIndex(where: { $0.id == trackID }) else { return }
                var updatedTrack = queue[index]
                updatedTrack.audioURL = resolution.playableURL
                queue[index] = updatedTrack
                if currentTrack?.id == trackID {
                    currentTrack = updatedTrack
                    persistCurrentTrack(updatedTrack)
                    loadResolvedURL(resolution.playableURL, autoPlay: autoPlay)
                }
                updateNowPlayingInfo()
            } catch {
                guard !Task.isCancelled else { return }
                print(
                    """
                    [XMusic][PlaybackResolve] failed
                    source=\(song.source.rawValue)
                    title=\(song.title)
                    artist=\(song.artist)
                    error=\(error.localizedDescription)
                    """
                )
                guard currentLoadToken == loadToken else { return }
                guard currentTrack?.id == trackID else { return }
                player.pause()
                isPlaying = false
                updateNowPlayingInfo()
            }
        }
    }

    private func persistCurrentTrack(_ track: Track) {
        let snapshot = PersistedTrack(track: track)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: lastPlayedTrackStorageKey)
    }

    private func loadPersistedTrack() -> Track? {
        guard let data = UserDefaults.standard.data(forKey: lastPlayedTrackStorageKey),
              let snapshot = try? JSONDecoder().decode(PersistedTrack.self, from: data) else {
            return nil
        }
        return snapshot.track
    }

    private func clearPersistedTrack() {
        UserDefaults.standard.removeObject(forKey: lastPlayedTrackStorageKey)
    }

    private func registerCachedTrackIfNeeded(_ track: Track) {
        guard let audioURL = track.audioURL else { return }
        guard audioURL.isFileURL else { return }
        guard FileManager.default.fileExists(atPath: audioURL.path) else { return }

        let key = cachedTrackKey(for: track)
        cachedTracks.removeAll { cachedTrackKey(for: $0) == key }
        cachedTracks.append(track)
        persistCachedTracks()
    }

    private func playableCachedTracks() -> [Track] {
        let filtered = cachedTracks.filter { track in
            guard let audioURL = track.audioURL else { return false }
            guard audioURL.isFileURL else { return false }
            return FileManager.default.fileExists(atPath: audioURL.path)
        }

        if filtered.count != cachedTracks.count {
            cachedTracks = filtered
            persistCachedTracks()
        }

        return filtered
    }

    private func cachedTrackKey(for track: Track) -> String {
        if let searchID = track.searchSong?.id {
            return "search:\(searchID)"
        }
        if let audioURL = track.audioURL?.absoluteString {
            return "url:\(audioURL)"
        }
        return "meta:\(track.title)|\(track.artist)|\(track.album)"
    }

    func removeCachedTrack(_ track: Track) {
        let key = cachedTrackKey(for: track)
        cachedTracks.removeAll { cachedTrackKey(for: $0) == key }
        persistCachedTracks()
    }

    func clearCachedTracks() {
        guard !cachedTracks.isEmpty else {
            UserDefaults.standard.removeObject(forKey: cachedTracksStorageKey)
            return
        }

        cachedTracks = []
        UserDefaults.standard.removeObject(forKey: cachedTracksStorageKey)
    }

    func pruneMissingCachedTracks() {
        _ = playableCachedTracks()
    }

    #if os(iOS)
    func artworkImageForSystemSurfaces(for track: Track) -> UIImage {
        makeArtworkImage(for: track)
    }
    #endif

    private func persistCachedTracks() {
        let snapshots = cachedTracks.map(PersistedTrack.init)
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: cachedTracksStorageKey)
    }

    private func loadCachedTracks() -> [Track] {
        guard let data = UserDefaults.standard.data(forKey: cachedTracksStorageKey),
              let snapshots = try? JSONDecoder().decode([PersistedTrack].self, from: data) else {
            return []
        }

        return snapshots
            .map(\.track)
            .filter { track in
                guard let audioURL = track.audioURL else { return false }
                guard audioURL.isFileURL else { return false }
                return FileManager.default.fileExists(atPath: audioURL.path)
            }
    }
}

private extension MusicPlayerViewModel {
    func configurePlayerForStreaming() {
        player.automaticallyWaitsToMinimizeStalling = false
    }

    func bindSystemVolume() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        volume = Double(session.outputVolume)
        systemVolumeObserver = session.observe(\.outputVolume, options: [.initial, .new]) { [weak self] session, _ in
            Task { @MainActor [weak self] in
                self?.volume = Double(session.outputVolume)
            }
        }
        #endif
    }

    func configureAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
        } catch {
            #if DEBUG
            print("[player] Failed to configure audio session: \(error)")
            #endif
        }
        #endif
    }

    func activateAudioSession() {
        #if os(iOS)
        prepareSystemPlaybackIfNeeded()
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("[player] Failed to activate audio session: \(error)")
            #endif
        }
        #endif
    }

    func prepareSystemPlaybackIfNeeded() {
        #if os(iOS)
        guard !hasPreparedSystemPlayback else { return }
        configureAudioSession()
        bindAudioSessionInterruptions()
        configureRemoteCommandCenter()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        hasPreparedSystemPlayback = true
        #endif
    }

    func bindAudioSessionInterruptions() {
        #if os(iOS)
        guard interruptionObserver == nil else { return }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let userInfo = notification.userInfo
            let typeValue = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0

            Task { @MainActor [weak self] in
                self?.handleAudioSessionInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }
        #endif
    }

    func handleAudioSessionInterruption(typeValue: UInt?, optionsValue: UInt) {
        #if os(iOS)
        guard let typeValue,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            shouldResumeAfterInterruption = isPlaying
            if isPlaying {
                player.pause()
                isPlaying = false
                updateNowPlayingInfo()
            }

        case .ended:
            guard shouldResumeAfterInterruption else { return }
            shouldResumeAfterInterruption = false

            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            guard options.contains(.shouldResume), currentTrack != nil else { return }

            activateAudioSession()
            player.play()
            isPlaying = true
            updateNowPlayingInfo()

        @unknown default:
            shouldResumeAfterInterruption = false
        }
        #endif
    }

    func configureRemoteCommandCenter() {
        #if os(iOS)
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            guard currentTrack != nil else { return .noSuchContent }
            if !isPlaying {
                activateAudioSession()
                player.play()
                isPlaying = true
                updateNowPlayingInfo()
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            guard currentTrack != nil else { return .noSuchContent }
            if isPlaying {
                player.pause()
                isPlaying = false
                updateNowPlayingInfo()
            }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            guard !queue.isEmpty else { return .noSuchContent }
            playNext()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            guard !queue.isEmpty else { return .noSuchContent }
            playPrevious()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self else { return .commandFailed }
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            seek(to: positionEvent.positionTime)
            return .success
        }
        #endif
    }

    func updateNowPlayingInfo() {
        #if os(iOS)
        guard hasPreparedSystemPlayback else { return }
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            if #available(iOS 13.0, *) {
                MPNowPlayingInfoCenter.default().playbackState = .stopped
            }
            nowPlayingInfo.removeAll()
            return
        }

        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.album
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        if let artwork = nowPlayingArtwork(for: track) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        } else {
            nowPlayingInfo.removeValue(forKey: MPMediaItemPropertyArtwork)
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        if #available(iOS 13.0, *) {
            MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        }
        #endif
    }

    func syncPlaybackState(with status: AVPlayer.TimeControlStatus) {
        guard currentTrack != nil || player.currentItem != nil else { return }

        let nextIsPlaying: Bool
        switch status {
        case .paused:
            nextIsPlaying = false
        case .waitingToPlayAtSpecifiedRate, .playing:
            nextIsPlaying = true
        @unknown default:
            nextIsPlaying = player.rate > 0
        }

        guard isPlaying != nextIsPlaying else { return }
        isPlaying = nextIsPlaying
        updateNowPlayingInfo()
    }

    func nowPlayingArtwork(for track: Track) -> MPMediaItemArtwork? {
        #if os(iOS)
        let artworkURL = track.searchSong?.artworkURL ?? track.remoteArtworkURL
        let artworkKey = nowPlayingArtworkCacheKey(for: track, artworkURL: artworkURL)

        if cachedNowPlayingArtworkKey == artworkKey,
           let cachedNowPlayingArtwork {
            return cachedNowPlayingArtwork
        }

        if cachedNowPlayingArtworkKey != artworkKey {
            cachedNowPlayingArtworkKey = artworkKey
            cachedNowPlayingArtwork = nil
            loadingNowPlayingArtworkURL = nil
            nowPlayingArtworkLoadTask?.cancel()
        }

        if let artworkURL {
            loadNowPlayingArtworkIfNeeded(from: artworkURL, for: track, artworkKey: artworkKey)
        }

        if cachedNowPlayingArtwork == nil {
            cachedNowPlayingArtwork = mediaArtwork(from: makeArtworkImage(for: track))
        }
        return cachedNowPlayingArtwork
        #else
        return nil
        #endif
    }

    func makeArtworkImage(for track: Track) -> UIImage {
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

            context.cgContext.setFillColor(UIColor.white.withAlphaComponent(0.15).cgColor)
            context.cgContext.fillEllipse(in: CGRect(x: 48, y: 56, width: 260, height: 260))

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 44, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let artistAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.82)
            ]

            let title = NSString(string: track.title)
            let artist = NSString(string: track.artist)
            title.draw(in: CGRect(x: 42, y: 360, width: 428, height: 90), withAttributes: titleAttributes)
            artist.draw(in: CGRect(x: 42, y: 432, width: 428, height: 48), withAttributes: artistAttributes)
        }
    }

    func nowPlayingArtworkCacheKey(for track: Track, artworkURL: URL?) -> String {
        if let artworkURL {
            return "\(track.id.uuidString)|\(artworkURL.absoluteString)"
        }
        return track.id.uuidString
    }

    func mediaArtwork(from image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    func loadNowPlayingArtworkIfNeeded(from url: URL, for track: Track, artworkKey: String) {
        guard loadingNowPlayingArtworkURL != url else { return }

        loadingNowPlayingArtworkURL = url
        nowPlayingArtworkLoadTask?.cancel()
        nowPlayingArtworkLoadTask = Task { [weak self] in
            guard let self else { return }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return }
                guard currentTrack?.id == track.id else { return }
                guard cachedNowPlayingArtworkKey == artworkKey else { return }

                cachedNowPlayingArtwork = mediaArtwork(from: image)
                loadingNowPlayingArtworkURL = nil
                updateNowPlayingInfo()
            } catch {
                guard !Task.isCancelled else { return }
                guard currentTrack?.id == track.id else { return }
                guard cachedNowPlayingArtworkKey == artworkKey else { return }

                loadingNowPlayingArtworkURL = nil
            }
        }
    }
}
