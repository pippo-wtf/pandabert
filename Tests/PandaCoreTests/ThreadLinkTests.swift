import XCTest
@testable import PandaCore

final class ThreadLinkTests: XCTestCase {
    let id = "12345678-1234-4234-8234-123456789abc"
    func session(_ provider: Provider) -> Session { Session(nativeID: id, profile: Profile(provider: provider, label: "Test", root: "/tmp/profile"), machineID: "local-machine", machine: "Test Mac") }
    func testCodexLinkTargetsExactThreadAndNeverStartsATurn() {
        let link = ThreadLink(session: session(.codex), localMachineID: "local-machine")
        XCTAssertEqual(link.url?.absoluteString, "codex://threads/" + id)
        XCTAssertNil(link.url?.query); XCTAssertEqual(link.bundleID, "com.openai.codex")
    }
    func testRemoteCodexDoesNotOpenAnUnrelatedLocalThread() {
        XCTAssertNil(ThreadLink(session: session(.codex), localMachineID: "another-machine").url)
    }
    func testMalformedIDsCannotInjectCommandsOrNavigation() {
        var s = session(.codex); s.nativeID = "new?prompt=doSomething"
        XCTAssertNil(ThreadLink(session: s, localMachineID: s.machineID).url)
        s = session(.claude); s.bridgeSessionID = "cse_abc?prompt=doSomething"; s.desktopSessionID = "local_new&prompt=doSomething"
        XCTAssertNil(ThreadLink(session: s, localMachineID: s.machineID).url)
    }
    func testLocalDesktopMappingNeverOpensOnAnotherMachine() {
        var s = session(.claude); s.bridgeSessionID = "cse_123ABC"; s.desktopSessionID = "local_" + id
        XCTAssertEqual(ThreadLink(session: s, localMachineID: s.machineID).url?.absoluteString, "claude://claude.ai/epitaxy/local_" + id)
        XCTAssertNil(ThreadLink(session: s, localMachineID: "another-machine").url)
    }
    func testDesktopAliasIsExplicitAndTerminalIsNotImported() {
        var s = session(.claude)
        XCTAssertNil(ThreadLink(session: s, localMachineID: s.machineID).url)
        s.desktopSessionID = "local_" + id
        XCTAssertEqual(ThreadLink(session: s, localMachineID: s.machineID).url?.absoluteString, "claude://claude.ai/epitaxy/local_" + id)
        XCTAssertNil(ThreadLink(session: s, localMachineID: "remote").url)
    }
    func testBridgeIDsAloneNeverEnableDesktopNavigation() {
        for bridge in ["cse_123ABC", "session_123ABC"] {
            var s = session(.claude); s.bridgeSessionID = bridge
            XCTAssertNil(ThreadLink(session: s, localMachineID: s.machineID).url)
            XCTAssertNil(ThreadLink(session: s, localMachineID: "remote").url)
        }
    }
    func testExplicitTerminalProvenanceSurvivesBridgeOnlyRecords() {
        var r = SessionReducer(session(.claude))
        r.apply(["type": "user", "sessionId": id, "entrypoint": "cli", "bridgeSessionId": "cse_example"])
        r.apply(["type": "assistant", "sessionId": id, "bridgeSessionId": "cse_example"])
        let link = ThreadLink(session: r.session, localMachineID: r.session.machineID)
        XCTAssertTrue(link.isTerminalSession)
        XCTAssertNil(link.url)
        XCTAssertTrue(link.explanation.contains("Test Mac"))
        // An explicit desktop mapping still makes this existing conversation navigable.
        var mapped = r.session; mapped.desktopSessionID = "local_" + id
        XCTAssertNotNil(ThreadLink(session: mapped, localMachineID: mapped.machineID).url)
    }
    func testMissingDesktopMappingIsNotEvidenceOfTerminalOrigin() {
        var r = SessionReducer(session(.claude))
        XCTAssertFalse(ThreadLink(session: r.session, localMachineID: r.session.machineID).isTerminalSession)
        r.apply(["type": "user", "entrypoint": "claude-desktop", "bridgeSessionId": "cse_example"])
        let link = ThreadLink(session: r.session, localMachineID: r.session.machineID)
        XCTAssertNil(link.url)
        XCTAssertFalse(link.isTerminalSession)
    }
    func testParentOriginDoesNotMislabelForkAndExplicitOriginCanChange() {
        var r = SessionReducer(session(.claude))
        r.apply(["type": "user", "sessionId": UUID().uuidString, "entrypoint": "cli"])
        XCTAssertEqual(r.session.entrypoint, "Local session")
        r.apply(["type": "user", "sessionId": id, "entrypoint": "cli"])
        r.apply(["type": "user", "sessionId": id, "entrypoint": "claude-desktop"])
        XCTAssertEqual(r.session.entrypoint, "Desktop Code")
    }
    func testClickRevalidatesDeletedAndChangedDesktopRecords() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("account/org")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var s = session(.claude); s.desktopSessionID = "local_" + id; s.bridgeSessionID = "cse_123ABC"
        // An old pinned snapshot must not be enough to open a deleted conversation.
        XCTAssertNil(ThreadLink.revalidated(session: s, localMachineID: s.machineID, desktopRoot: root).url)
        let desktop = "local_" + UUID().uuidString
        let file = folder.appendingPathComponent(desktop + ".json")
        try JSONSerialization.data(withJSONObject: ["sessionId": desktop, "cliSessionId": id]).write(to: file)
        XCTAssertEqual(ThreadLink.revalidated(session: s, localMachineID: s.machineID, desktopRoot: root).url?.absoluteString, "claude://claude.ai/epitaxy/" + desktop)
        try FileManager.default.removeItem(at: file)
        XCTAssertNil(ThreadLink.revalidated(session: s, localMachineID: s.machineID, desktopRoot: root).url)
    }
    func testAmbiguousDesktopRecordsDoNotEnableNavigation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("account/org")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for _ in 0..<2 {
            let desktop = "local_" + UUID().uuidString
            try JSONSerialization.data(withJSONObject: ["sessionId": desktop, "cliSessionId": id]).write(to: folder.appendingPathComponent(desktop + ".json"))
        }
        XCTAssertNil(ThreadLink.revalidated(session: session(.claude), localMachineID: "local-machine", desktopRoot: root).url)
    }
    func testBridgeMetadataAndOldSnapshotCompatibility() throws {
        var r = SessionReducer(session(.claude)); r.apply(["type": "user", "bridgeSessionId": "cse_123ABC"])
        XCTAssertEqual(r.session.bridgeSessionID, "cse_123ABC")
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(r.session)) as! [String: Any]
        object.removeValue(forKey: "bridgeSessionID"); object.removeValue(forKey: "desktopSessionID")
        let old = try JSONDecoder().decode(Session.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(old.bridgeSessionID); XCTAssertNil(old.desktopSessionID)
    }
    func testDesktopIndexMatchesCLIIDRatherThanGuessingLocalID() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("account/org"); try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let desktop = "local_" + UUID().uuidString
        let data = try JSONSerialization.data(withJSONObject: ["sessionId": desktop, "cliSessionId": id])
        try data.write(to: folder.appendingPathComponent(desktop + ".json"))
        XCTAssertEqual(ClaudeDesktopIndex.load(root: root)[id], desktop)
    }
}
