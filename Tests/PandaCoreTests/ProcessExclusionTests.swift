import XCTest
@testable import PandaCore

final class ProcessExclusionTests: XCTestCase {
    private func session(originator: String?, source: Any? = nil, provider: Provider = .codex) -> Session {
        var reducer = SessionReducer(Session(nativeID: UUID().uuidString, profile: Profile(provider: provider, label: "Sample", root: "/sample"), machineID: "machine", machine: "Sample"))
        var payload: [String: Any] = [:]
        payload["originator"] = originator; payload["source"] = source
        reducer.apply(["type": "session_meta", "payload": payload])
        return reducer.session
    }
    func testExplicitClaudeLauncherAndExecHaveIndependentFilters() {
        let managed = session(originator: "Claude Code", source: "vscode")
        let exec = session(originator: "codex_exec", source: "exec")
        XCTAssertEqual(managed.originator, "Claude Code")
        XCTAssertEqual(managed.processExclusion, .claudeManagedCodex)
        XCTAssertEqual(exec.processExclusion, .codexExec)
        var preferences = Preferences()
        XCTAssertFalse(preferences.isSessionHidden(managed))
        preferences.excludedProcessKinds = [ProcessExclusion.claudeManagedCodex.rawValue]
        XCTAssertTrue(preferences.isSessionHidden(managed))
        XCTAssertFalse(preferences.isSessionHidden(exec))
        preferences.excludedProcessKinds = [ProcessExclusion.codexExec.rawValue]
        XCTAssertFalse(preferences.isSessionHidden(managed))
        XCTAssertTrue(preferences.isSessionHidden(exec))
    }
    func testUnknownDesktopInteractiveAndClaudeSessionsAreNotGuessedAsDelegated() throws {
        var preferences = Preferences()
        preferences.excludedProcessKinds = Set(ProcessExclusion.allCases.map(\.rawValue))
        for s in [session(originator: nil), session(originator: "codex_work_desktop", source: "vscode"), session(originator: "codex_cli_rs", source: "cli"), session(originator: "Claude Code", provider: .claude)] {
            XCTAssertFalse(preferences.isSessionHidden(s))
        }
        let old = session(originator: nil)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        json.removeValue(forKey: "originator"); json.removeValue(forKey: "launchSource")
        let decoded = try JSONDecoder().decode(Session.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.processExclusion)
        XCTAssertFalse(preferences.isSessionHidden(decoded))
        XCTAssertTrue(session(originator: "codex_work_desktop", source: ["subagent": ["thread_spawn": ["parent_thread_id": "parent"]]]).sidechain)
    }
}
