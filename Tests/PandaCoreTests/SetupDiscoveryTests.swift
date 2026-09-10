import XCTest
@testable import PandaCore

final class SetupDiscoveryTests: XCTestCase {
    func testDiscoveryOnlyFindsProviderLogRootsAndDeduplicatesAliases() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        for path in [".claude/projects", ".codex-work/sessions", ".claude-invalid/sessions", "unrelated/projects"] {
            try FileManager.default.createDirectory(at: home.appendingPathComponent(path), withIntermediateDirectories: true)
        }
        let alias = home.appendingPathComponent(".codex-alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: home.appendingPathComponent(".codex-work"))
        let saved = Profile(provider: .codex, label: "My work account", root: alias.path)
        let found = SetupDiscovery.profiles(existing: [saved], home: home)
        XCTAssertEqual(found.count, 3) // configured alias, standard Claude and absent standard Codex
        XCTAssertEqual(found.first?.label, "My work account")
        XCTAssertEqual(found.filter(SetupDiscovery.isAvailable).count, 2)
        XCTAssertFalse(found.contains { $0.root.contains("invalid") || $0.root.contains("unrelated") })
    }
    func testAFileNamedSessionsIsNotAUsableLogDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data().write(to: root.appendingPathComponent("sessions"))
        XCTAssertFalse(SetupDiscovery.isAvailable(Profile(provider: .codex, label: "Test", root: root.path)))
    }
}
