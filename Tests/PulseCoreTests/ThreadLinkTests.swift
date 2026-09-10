import XCTest
@testable import PulseCore

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
    func testVerifiedLocalConversationPreferredAndBridgeUsedRemotely() {
        var s = session(.claude); s.bridgeSessionID = "cse_123ABC"; s.desktopSessionID = "local_" + id
        XCTAssertEqual(ThreadLink(session: s, localMachineID: s.machineID).url?.absoluteString, "claude://claude.ai/epitaxy/local_" + id)
        XCTAssertEqual(ThreadLink(session: s, localMachineID: "another-machine").url?.absoluteString, "claude://claude.ai/code/session_123ABC")
    }
    func testDesktopAliasIsExplicitAndTerminalIsNotImported() {
        var s = session(.claude)
        XCTAssertNil(ThreadLink(session: s, localMachineID: s.machineID).url)
        s.desktopSessionID = "local_" + id
        XCTAssertEqual(ThreadLink(session: s, localMachineID: s.machineID).url?.absoluteString, "claude://claude.ai/epitaxy/local_" + id)
        XCTAssertNil(ThreadLink(session: s, localMachineID: "remote").url)
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
