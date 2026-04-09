import XCTest
@testable import XMusic

final class MusicSourceLyricNormalizerTests: XCTestCase {
    func testNormalizeAcceptsRawStringLyric() throws {
        let result = try XCTUnwrap(MusicSourceLyricNormalizer.normalize("[00:00.00]hello"))

        XCTAssertEqual(result.lyric, "[00:00.00]hello")
        XCTAssertNil(result.tlyric)
        XCTAssertNil(result.rlyric)
        XCTAssertNil(result.lxlyric)
    }

    func testNormalizeAcceptsAliasKeys() throws {
        let result = try XCTUnwrap(
            MusicSourceLyricNormalizer.normalize([
                "lrc": "[00:00.00]hello",
                "tlrc": "[00:00.00]你好",
                "rlrc": "[00:00.00]ni hao",
                "lxlrc": "<0,500>hello",
            ])
        )

        XCTAssertEqual(result.lyric, "[00:00.00]hello")
        XCTAssertEqual(result.tlyric, "[00:00.00]你好")
        XCTAssertEqual(result.rlyric, "[00:00.00]ni hao")
        XCTAssertEqual(result.lxlyric, "<0,500>hello")
    }
}
