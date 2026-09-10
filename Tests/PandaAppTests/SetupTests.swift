import XCTest
import PandaCore
@testable import Panda

final class SetupTests: XCTestCase {
    func testFirstLaunchWaitsForSetupAndClosingDoesNotSaveOrCollect() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PandaStore(root: root)
        XCTAssertTrue(store.needsSetup); XCTAssertTrue(store.showSetup)
        store.showSetup = false; store.save(); store.refresh(force: true)
        XCTAssertNil(try PreferencesFile.load(root: root))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("machine-id").path))
        XCTAssertTrue(PandaStore(root: root).showSetup)
        try store.completeSetup(profiles: [], remotes: [], githubEnabled: false)
        XCTAssertFalse(store.needsSetup)
        XCTAssertEqual(try PreferencesFile.load(root: root)?.profiles.count, 0)
        XCTAssertFalse(PandaStore(root: root).needsSetup)
    }
    func testRerunningSetupPreservesPinsReviewHistoryAndUnrelatedSettings() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var prefs = Preferences(); prefs.profiles = []; prefs.pins = ["pinned"]
        prefs.reviewed = ["task": "turn"]; prefs.projectAliases = ["repo": "Friendly name"]
        prefs.waits = ["task": "Teammate"]; prefs.alwaysOnTop = false
        try PandaPaths.save(prefs, to: root.appendingPathComponent("preferences.json"))
        let store = PandaStore(root: root)
        XCTAssertFalse(store.showSetup)
        try store.completeSetup(profiles: [], remotes: [], githubEnabled: true)
        let saved = try XCTUnwrap(PreferencesFile.load(root: root))
        XCTAssertEqual(saved.pins, prefs.pins); XCTAssertEqual(saved.reviewed, prefs.reviewed)
        XCTAssertEqual(saved.projectAliases, prefs.projectAliases); XCTAssertEqual(saved.waits, prefs.waits)
        XCTAssertFalse(saved.alwaysOnTop); XCTAssertTrue(saved.githubEnabled)
    }
    func testFailedSetupSaveLeavesFirstLaunchPending() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PandaStore(root: root)
        try Data("blocked".utf8).write(to: root)
        XCTAssertThrowsError(try store.completeSetup(profiles: [], remotes: [], githubEnabled: false))
        XCTAssertTrue(store.needsSetup)
        XCTAssertEqual(try Data(contentsOf: root), Data("blocked".utf8))
    }
    func testSetupCannotOverwriteUnreadableSettingsOrAcceptInvalidRemote() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let path = root.appendingPathComponent("preferences.json")
        let broken = Data("{bad".utf8); try broken.write(to: path)
        let store = PandaStore(root: root)
        XCTAssertThrowsError(try store.completeSetup(profiles: [], remotes: [], githubEnabled: false))
        XCTAssertEqual(try Data(contentsOf: path), broken)
        try FileManager.default.removeItem(at: path)
        let fresh = PandaStore(root: root)
        XCTAssertThrowsError(try fresh.completeSetup(profiles: [], remotes: [RemoteMachine(label: "Test", sshHost: "-flag")], githubEnabled: false))
        XCTAssertNil(try PreferencesFile.load(root: root))
    }
}
