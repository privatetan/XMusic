import Foundation
import XCTest
@testable import XMusic

final class ModelBehaviorTests: XCTestCase {
    @MainActor
    func testSearchSongPrefersHighestKnownQualityAndUpgradesArtworkURL() {
        let song = SearchSong(
            id: "song-1",
            source: .kw,
            title: "Track",
            artist: "Artist",
            album: "Album",
            durationText: "03:21",
            artworkURL: URL(string: "http://example.com/artwork.jpg"),
            qualities: ["128k", "flac", "320k"],
            legacyInfoJSON: "{}"
        )

        XCTAssertEqual(song.preferredQuality, "flac")
        XCTAssertEqual(song.artworkURL?.absoluteString, "https://example.com/artwork.jpg")
    }

    @MainActor
    func testTrackStorageKeyPrefersSearchSongThenSourceNameThenCatalog() {
        let searchSong = SearchSong(
            id: "search-id",
            source: .tx,
            title: " Song Title ",
            artist: " Singer ",
            album: " Album ",
            durationText: "02:10",
            artworkURL: nil,
            qualities: ["128k"],
            legacyInfoJSON: "{}"
        )

        let searchTrack = Track.searchResultTrack(from: searchSong, sourceName: "Remote")
        XCTAssertEqual(searchTrack.storageKey, "search:search-id")

        let sourceTrack = Track(
            title: " Song Title ",
            artist: " Singer ",
            album: " Album ",
            blurb: "blurb",
            genre: "genre",
            duration: 120,
            audioURL: nil,
            artwork: SearchPlatformSource.kw.searchArtworkPalette,
            sourceName: " Remote Source "
        )
        XCTAssertEqual(sourceTrack.catalogKey, "song title|singer|album")
        XCTAssertEqual(sourceTrack.storageKey, "source:remote source|song title|singer|album")

        let catalogTrack = Track(
            title: " Song Title ",
            artist: " Singer ",
            album: " Album ",
            blurb: "blurb",
            genre: "genre",
            duration: 120,
            audioURL: nil,
            artwork: SearchPlatformSource.kw.searchArtworkPalette
        )
        XCTAssertEqual(catalogTrack.storageKey, "catalog:song title|singer|album")
    }

    @MainActor
    func testSearchResultTrackBuildsDurationAndDefaultFallback() {
        let song = SearchSong(
            id: "song-1",
            source: .mg,
            title: "Track",
            artist: "Artist",
            album: "Album",
            durationText: "01:02:03",
            artworkURL: nil,
            qualities: ["128k"],
            legacyInfoJSON: "{}"
        )
        let invalidDurationSong = SearchSong(
            id: "song-2",
            source: .wy,
            title: "Track",
            artist: "Artist",
            album: "Album",
            durationText: "",
            artworkURL: nil,
            qualities: ["128k"],
            legacyInfoJSON: "{}"
        )

        let resolvedURL = URL(string: "https://example.com/audio.mp3")
        let track = Track.searchResultTrack(from: song, sourceName: "custom", resolvedURL: resolvedURL)
        let fallbackTrack = Track.searchResultTrack(from: invalidDurationSong)

        XCTAssertEqual(track.duration, 3723, accuracy: 0.001)
        XCTAssertEqual(track.audioURL, resolvedURL)
        XCTAssertEqual(track.sourceName, "custom")
        XCTAssertEqual(fallbackTrack.duration, 240, accuracy: 0.001)
    }

    @MainActor
    func testPlaylistFormattingAndCustomStableKeys() {
        let playlist = Playlist(
            source: .kw,
            sourceIdentifier: Playlist.customStableKey(for: "playlist-1"),
            title: "Playlist",
            curator: "Curator",
            summary: "Summary",
            description: "Description",
            categories: [],
            tracks: [],
            artwork: SearchPlatformSource.kw.searchArtworkPalette,
            remoteArtworkURL: URL(string: "http://example.com/cover.jpg"),
            playCount: 123_456,
            followerCount: 5,
            playCountDisplay: nil,
            followerCountDisplay: "9.9万",
            declaredTrackCount: 8,
            updatedLabel: "今天",
            updatedOrder: 1
        )

        XCTAssertEqual(playlist.primaryCategory, "推荐")
        XCTAssertEqual(playlist.trackCount, 8)
        XCTAssertEqual(playlist.playCountText, "12.3万")
        XCTAssertEqual(playlist.followerCountText, "9.9万")
        XCTAssertTrue(playlist.hasPlayCount)
        XCTAssertTrue(playlist.hasFollowerCount)
        XCTAssertEqual(playlist.customPlaylistID, "playlist-1")
        XCTAssertTrue(playlist.isCustomPlaylist)
        XCTAssertEqual(playlist.remoteArtworkURL?.absoluteString, "https://example.com/cover.jpg")
    }

    @MainActor
    func testPreparePlayableURLStreamsRemoteMediaWhenNoCacheExists() async throws {
        let library = MusicSourceLibrary()
        let remoteURL = URL(string: "https://example.com/\(UUID().uuidString).flac")!

        let preparedURL = try await library.preparePlayableURL(from: remoteURL)

        XCTAssertEqual(preparedURL, remoteURL)
    }

    @MainActor
    func testPreparePlayableURLPrefersHTTPSCandidateFor126Net() async throws {
        let library = MusicSourceLibrary()
        let remoteURL = URL(string: "http://m10.music.126.net/\(UUID().uuidString).mp3")!

        let preparedURL = try await library.preparePlayableURL(from: remoteURL)

        XCTAssertEqual(preparedURL.absoluteString, remoteURL.absoluteString.replacingOccurrences(of: "http://", with: "https://"))
    }
}
