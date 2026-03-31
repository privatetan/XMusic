import Foundation
import XCTest
@testable import XMusic

final class MusicSourceParserTests: XCTestCase {
    @MainActor
    func testImportSourceParsesMetadataAndCapabilities() throws {
        let script = """
        /*
         * @name Example Source
         * @description Parsed from unit test
         * @author Codex
         * @homepage http://example.com/source
         * @version 1.0.0
         */
        lx.send(lx.EVENT_NAMES.inited, {
          sources: {
            kw: {
              type: 'music',
              actions: ['musicUrl', 'lyric'],
              qualitys: ['320k', 'flac', 'ignored']
            },
            local: {
              type: 'music',
              actions: ['musicUrl', 'lyric', 'pic'],
              qualitys: ['128k']
            },
            tx: {
              type: 'other',
              actions: ['musicUrl'],
              qualitys: ['128k']
            }
          }
        });
        """

        let imported = try MusicSourceParser.importSource(
            script: script,
            fileName: "example.js",
            existingID: "existing-source-id",
            importedAt: Date(timeIntervalSince1970: 1_234)
        )

        XCTAssertEqual(imported.id, "existing-source-id")
        XCTAssertEqual(imported.name, "Example Source")
        XCTAssertEqual(imported.description, "Parsed from unit test")
        XCTAssertEqual(imported.author, "Codex")
        XCTAssertEqual(imported.homepage, "http://example.com/source")
        XCTAssertEqual(imported.version, "1.0.0")
        XCTAssertEqual(imported.importedAt, Date(timeIntervalSince1970: 1_234))
        XCTAssertNil(imported.parseErrorMessage)
        XCTAssertEqual(imported.capabilities.map(\.source), ["kw", "local"])

        let kwCapability = try XCTUnwrap(imported.capabilities.first(where: { $0.source == "kw" }))
        XCTAssertEqual(kwCapability.type, .music)
        XCTAssertEqual(kwCapability.actions, [.musicUrl])
        XCTAssertEqual(kwCapability.qualitys, ["320k", "flac"])

        let localCapability = try XCTUnwrap(imported.capabilities.first(where: { $0.source == "local" }))
        XCTAssertEqual(localCapability.actions, [.musicUrl, .lyric, .pic])
        XCTAssertEqual(localCapability.qualitys, [])
    }

    @MainActor
    func testImportSourceStoresParseErrorWithoutThrowing() throws {
        let script = """
        /*
         * @name Broken Source
         */
        const nothingToInit = true;
        """

        let imported = try MusicSourceParser.importSource(script: script)

        XCTAssertTrue(imported.capabilities.isEmpty)
        XCTAssertEqual(imported.parseErrorMessage, MusicSourceParseError.missingInitInfo.localizedDescription)
        XCTAssertTrue(imported.hasRuntimeParseError)
    }

    @MainActor
    func testImportSourceTruncatesMetadataToDisplayLimits() throws {
        let longName = String(repeating: "N", count: 30)
        let longDescription = String(repeating: "D", count: 40)
        let longAuthor = String(repeating: "A", count: 60)
        let longVersion = String(repeating: "V", count: 40)
        let script = """
        /*
         * @name \(longName)
         * @description \(longDescription)
         * @author \(longAuthor)
         * @version \(longVersion)
         */
        lx.send(lx.EVENT_NAMES.inited, { sources: {} });
        """

        let imported = try MusicSourceParser.importSource(script: script)

        XCTAssertEqual(imported.name, String(repeating: "N", count: 24) + "...")
        XCTAssertEqual(imported.description, String(repeating: "D", count: 36) + "...")
        XCTAssertEqual(imported.author, String(repeating: "A", count: 56) + "...")
        XCTAssertEqual(imported.version, String(repeating: "V", count: 36) + "...")
    }

    @MainActor
    func testReadScriptRecognizesUTF16EncodedData() throws {
        let text = "/*\n * @name 编码测试\n */"
        let data = try XCTUnwrap(text.data(using: .utf16LittleEndian))

        let decoded = try MusicSourceParser.readScript(from: data)

        XCTAssertEqual(decoded, text)
    }
}
