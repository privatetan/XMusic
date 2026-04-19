//
//  CarPlaySceneDelegate.swift
//  XMusic
//
//  Created by Codex on 2026/4/19.
//

#if os(iOS)
import CarPlay
import Combine
import SwiftUI
import UIKit

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private let context = XMusicAppContext.shared
    private var interfaceController: CPInterfaceController?
    private var rootTemplate: CPListTemplate?
    private var cancellables: Set<AnyCancellable> = []

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        configureObservers()

        let template = makeRootTemplate()
        rootTemplate = template
        interfaceController.setRootTemplate(template, animated: false, completion: nil)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        cancellables.removeAll()
        rootTemplate = nil
        self.interfaceController = nil
    }

    private func configureObservers() {
        guard cancellables.isEmpty else { return }

        context.player.$currentTrack
            .sink { [weak self] _ in self?.refreshTemplate() }
            .store(in: &cancellables)

        context.player.$isPlaying
            .sink { [weak self] _ in self?.refreshTemplate() }
            .store(in: &cancellables)

        context.player.$cachedTracks
            .sink { [weak self] _ in self?.refreshTemplate() }
            .store(in: &cancellables)

        context.library.$savedTracks
            .sink { [weak self] _ in self?.refreshTemplate() }
            .store(in: &cancellables)
    }

    private func refreshTemplate() {
        guard let rootTemplate else { return }
        rootTemplate.updateSections(makeSections())
    }

    private func makeRootTemplate() -> CPListTemplate {
        let template = CPListTemplate(title: "XMusic", sections: makeSections())
        let nowPlayingButton = CPBarButton(title: "正在播放") { [weak self] _ in
            self?.showNowPlaying()
        }
        template.trailingNavigationBarButtons = [nowPlayingButton]
        return template
    }

    private func makeSections() -> [CPListSection] {
        [
            CPListSection(items: makePlaybackItems(), header: "播放控制", sectionIndexTitle: nil),
            CPListSection(items: makeTrackItems(from: context.library.savedTracks, title: "我的收藏"), header: "我的收藏", sectionIndexTitle: nil),
            CPListSection(items: makeTrackItems(from: context.player.cachedTracks, title: "离线缓存"), header: "离线缓存", sectionIndexTitle: nil)
        ]
    }

    private func makePlaybackItems() -> [CPListItem] {
        let player = context.player
        let currentTitle = player.currentTrack?.title ?? "当前没有正在播放的歌曲"
        let currentDetail = player.currentTrack.map { "\($0.artist) · \($0.album)" } ?? "在手机上选歌后，这里会同步显示"

        let nowPlayingItem = CPListItem(
            text: currentTitle,
            detailText: currentDetail,
            image: artworkImage(for: player.currentTrack)
        )
        nowPlayingItem.isPlaying = player.isPlaying
        nowPlayingItem.handler = { [weak self] _, completion in
            self?.showNowPlaying()
            completion()
        }

        let playPauseItem = CPListItem(
            text: player.isPlaying ? "暂停" : "播放",
            detailText: player.currentTrack == nil ? "暂无可控制的歌曲" : "控制当前歌曲"
        )
        playPauseItem.isEnabled = player.currentTrack != nil
        playPauseItem.handler = { [weak self] _, completion in
            self?.context.player.togglePlayback()
            completion()
        }

        let previousItem = CPListItem(text: "上一首", detailText: "回到队列中的上一首")
        previousItem.isEnabled = player.currentTrack != nil
        previousItem.handler = { [weak self] _, completion in
            self?.context.player.playPrevious()
            completion()
        }

        let nextItem = CPListItem(text: "下一首", detailText: "跳到队列中的下一首")
        nextItem.isEnabled = player.currentTrack != nil
        nextItem.handler = { [weak self] _, completion in
            self?.context.player.playNext()
            completion()
        }

        return [nowPlayingItem, playPauseItem, previousItem, nextItem]
    }

    private func makeTrackItems(from tracks: [Track], title: String) -> [CPListItem] {
        let displayTracks = Array(tracks.prefix(60))

        guard !displayTracks.isEmpty else {
            let emptyItem = CPListItem(text: "暂无内容", detailText: "先在手机端添加\(title)")
            emptyItem.isEnabled = false
            return [emptyItem]
        }

        return displayTracks.map { track in
            let item = CPListItem(
                text: track.title,
                detailText: "\(track.artist) · \(track.album)",
                image: artworkImage(for: track)
            )
            item.isPlaying = context.player.isCurrentTrack(track) && context.player.isPlaying
            item.handler = { [weak self] _, completion in
                self?.context.player.play(track, from: displayTracks)
                completion()
            }
            return item
        }
    }

    private func artworkImage(for track: Track?) -> UIImage? {
        guard let track else { return nil }
        return context.player.artworkImageForSystemSurfaces(for: track)
    }

    private func showNowPlaying() {
        guard let interfaceController else { return }
        interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true) { _, _ in }
    }
}
#endif
