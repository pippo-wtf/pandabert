import XCTest
@testable import PandaCore

final class PreferencesFileTests: XCTestCase {
    func testOnlyAbsentPreferencesPermitDefaults() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("preferences.json")
        XCTAssertNil(try PreferencesFile.load(root: root))
        var prefs = Preferences(); prefs.profiles = []; prefs.remotes = []
        try PandaPaths.save(prefs, to: path)
        XCTAssertEqual(try PreferencesFile.load(root: root)?.profiles.count, 0)
        let corrupt = Data("{broken".utf8); try corrupt.write(to: path)
        XCTAssertThrowsError(try PreferencesFile.load(root: root))
        XCTAssertEqual(try Data(contentsOf: path), corrupt)
        try Data("{}".utf8).write(to: path)
        XCTAssertThrowsError(try PreferencesFile.load(root: root))
        try FileManager.default.removeItem(at: path)
        try FileManager.default.createSymbolicLink(at: path, withDestinationURL: root.appendingPathComponent("missing"))
        XCTAssertThrowsError(try PreferencesFile.load(root: root), "A dangling preferences link is not a first launch")
        try FileManager.default.removeItem(at: path)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
        XCTAssertThrowsError(try PreferencesFile.load(root: root))
    }
}
