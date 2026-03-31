import Foundation
import XCTest
@testable import XMusic

final class LxLegacySongInfoTests: XCTestCase {
    @MainActor
    func testParseLegacyJSONMergesDefaultsForLegacyPayload() throws {
        let json = """
        {
          "name": "Legacy Song",
          "singer": "Legacy Singer",
          "songmid": "kw-123"
        }
        """

        let legacy = try LxLegacySongInfo.parseLegacyJSON(json, sourceName: "kw")

        XCTAssertEqual(legacy["name"] as? String, "Legacy Song")
        XCTAssertEqual(legacy["singer"] as? String, "Legacy Singer")
        XCTAssertEqual(legacy["source"] as? String, "kw")
        XCTAssertEqual(legacy["songmid"] as? String, "kw-123")
        XCTAssertEqual(legacy["interval"] as? String, "03:30")
        XCTAssertEqual(legacy["albumId"] as? String, "")
        XCTAssertEqual(legacy["types"] as? [String], [])

        let qualityMap = try XCTUnwrap(legacy["_types"] as? [String: Any])
        let defaultQuality = try XCTUnwrap(qualityMap["128k"] as? [String: Any])
        XCTAssertTrue(defaultQuality["size"] is NSNull)
    }

    @MainActor
    func testParseLegacyJSONConvertsNewFormatForQQSource() throws {
        let json = """
        {
          "name": "New Song",
          "singer": "Singer",
          "interval": "04:05",
          "meta": {
            "songId": "song-mid",
            "albumName": "Album",
            "picUrl": "http://example.com/cover.jpg",
            "albumId": "album-id",
            "qualitys": ["320k"],
            "_qualitys": {
              "320k": {
                "size": 2048
              }
            },
            "strMediaMid": "media-mid",
            "albumMid": "album-mid",
            "id": 99
          }
        }
        """

        let legacy = try LxLegacySongInfo.parseLegacyJSON(json, sourceName: "tx")

        XCTAssertEqual(legacy["name"] as? String, "New Song")
        XCTAssertEqual(legacy["singer"] as? String, "Singer")
        XCTAssertEqual(legacy["source"] as? String, "tx")
        XCTAssertEqual(legacy["songmid"] as? String, "song-mid")
        XCTAssertEqual(legacy["interval"] as? String, "04:05")
        XCTAssertEqual(legacy["albumName"] as? String, "Album")
        XCTAssertEqual(legacy["img"] as? String, "http://example.com/cover.jpg")
        XCTAssertEqual(legacy["albumId"] as? String, "album-id")
        XCTAssertEqual(legacy["types"] as? [String], ["320k"])
        XCTAssertEqual(legacy["strMediaMid"] as? String, "media-mid")
        XCTAssertEqual(legacy["albumMid"] as? String, "album-mid")
        XCTAssertEqual(legacy["songId"] as? Int, 99)
    }

    @MainActor
    func testFieldChecksExposePresenceAndDebugSummaries() throws {
        let checks = LxLegacySongInfo.fieldChecks(
            for: "kw",
            legacyObject: [
                "name": "Song",
                "source": "kw",
                "songmid": "",
                "types": ["320k"],
                "_types": ["320k": ["size": 1024]],
            ]
        )

        let nameCheck = try fieldCheck(named: "name", in: checks)
        XCTAssertTrue(nameCheck.isPresent)
        XCTAssertEqual(nameCheck.actualValue, "Song")

        let songmidCheck = try fieldCheck(named: "songmid", in: checks)
        XCTAssertFalse(songmidCheck.isPresent)
        XCTAssertEqual(songmidCheck.actualValue, "\"\"")

        let typesCheck = try fieldCheck(named: "types", in: checks)
        XCTAssertTrue(typesCheck.isPresent)
        XCTAssertEqual(typesCheck.actualValue, "Array(1)")

        let detailCheck = try fieldCheck(named: "_types", in: checks)
        XCTAssertTrue(detailCheck.isPresent)
        XCTAssertEqual(detailCheck.actualValue, "Object(320k)")

        let albumCheck = try fieldCheck(named: "albumId", in: checks)
        XCTAssertFalse(albumCheck.isPresent)
        XCTAssertEqual(albumCheck.actualValue, "<missing>")
    }

    private func fieldCheck(named field: String, in checks: [PlaybackFieldCheck]) throws -> PlaybackFieldCheck {
        try XCTUnwrap(checks.first(where: { $0.field == field }))
    }
}
