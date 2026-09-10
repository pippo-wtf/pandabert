import XCTest
@testable import PandaCore

final class PandaCoreTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func reducer(_ provider: Provider = .codex) -> SessionReducer {
        SessionReducer(Session(nativeID: "session-1", profile: Profile(provider: provider, label: "Test", root: "/tmp/test-profile"), machineID: "machine-1", machine: "Test Mac"))
    }
    func event(_ name: String, at: Double = 0, turn: String = "turn-1") -> [String: Any] {
        ["type": "event_msg", "timestamp": now.addingTimeInterval(at).timeIntervalSince1970, "payload": ["type": name, "turn_id": turn]]
    }
    func testLateCompletionCannotFinishNewTurn() {
        var r = reducer(); r.apply(event("task_started")); r.apply(event("task_started", at: 10, turn: "turn-2")); r.apply(event("task_complete", at: 11))
        XCTAssertEqual(r.session.activity, .working); XCTAssertEqual(r.session.turnID, "turn-2")
        r.apply(event("task_complete", at: 12, turn: "turn-2")); XCTAssertEqual(r.session.activity, .finished)
    }
    func testToolFailureIsNotRunFailureAndSilenceIsUncertain() {
        var r = reducer(); r.apply(event("task_started"))
        r.apply(["type": "response_item", "timestamp": now.timeIntervalSince1970 + 5, "payload": ["type": "function_call_output", "output": "Process failed: error permission denied"]])
        XCTAssertEqual(r.session.activity, .working)
        XCTAssertEqual(r.session.displayActivity(now: now.addingTimeInterval(181)), .unknown)
    }
    func testQuestionClearsOnlyWhenItsOwnToolReturns() {
        var r = reducer(.claude)
        r.apply(["type": "assistant", "timestamp": now.timeIntervalSince1970, "message": ["content": [["type": "tool_use", "name": "AskUserQuestion", "id": "q1", "input": ["questions": [["question": "Which colour?"]]]]]]])
        XCTAssertEqual(r.session.activity, .question); XCTAssertEqual(r.session.excerpt, "Which colour?")
        r.apply(["type": "user", "timestamp": now.timeIntervalSince1970 + 1, "message": ["content": [["type": "tool_result", "tool_use_id": "unrelated"]]]])
        XCTAssertEqual(r.session.activity, .question)
        r.apply(["type": "user", "timestamp": now.timeIntervalSince1970 + 2, "message": ["content": [["type": "tool_result", "tool_use_id": "q1"]]]])
        XCTAssertEqual(r.session.activity, .working)
    }
    func testReviewAcknowledgementIsPerTurnAndPinsPersist() throws {
        var r = reducer(); r.apply(event("task_started")); r.apply(event("task_complete", at: 1))
        var p = Preferences(); p.togglePin(r.session.id); p.reviewed[r.session.id] = r.session.completionKey
        XCTAssertFalse(p.needsAttention(r.session, now: now))
        r.apply(event("task_started", at: 2, turn: "turn-2")); r.apply(event("task_complete", at: 3, turn: "turn-2"))
        XCTAssertTrue(p.needsAttention(r.session, now: now))
        let saved = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(saved.pins, [r.session.id]); XCTAssertEqual(saved.reviewed, p.reviewed)
    }
    func testOfflineQuestionDoesNotPretendToBeCurrent() {
        var s = reducer().session; s.activity = .question; s.sourceOnline = false
        XCTAssertFalse(Preferences().needsAttention(s)); XCTAssertEqual(s.displayActivity(), .unknown)
    }
    func testFirstLaunchDoesNotCreateHistoricalReviewBacklog() {
        var p = Preferences(); p.attentionSince = now
        var r = reducer(); r.apply(event("task_complete", at: -100))
        XCTAssertFalse(p.needsAttention(r.session, now: now))
        r.apply(event("task_started", at: 1, turn: "new")); r.apply(event("task_complete", at: 2, turn: "new"))
        XCTAssertTrue(p.needsAttention(r.session, now: now.addingTimeInterval(3)))
    }
    func testRepoGroupingAcrossClonesAndForkSeparation() {
        let a = Collector.projectKey(repository: "git@github.com:team/product.git", cwd: "/a", machine: "a")
        let b = Collector.projectKey(repository: "https://github.com/team/product.git", cwd: "/b", machine: "b")
        XCTAssertEqual(a, b); XCTAssertEqual(a, "github.com/team/product")
        XCTAssertEqual(a, Collector.projectKey(repository: "https://user:secret@github.com/team/product.git", cwd: "/b", machine: "b"))
        XCTAssertNotEqual(a, Collector.projectKey(repository: "https://github.com/fork/product.git", cwd: "/a", machine: "a"))
    }
    func testIncompleteRecordIsNotAppliedAndRotationIsRead() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); defer { try? FileManager.default.removeItem(at: root) }
        let profile = Profile(provider: .codex, label: "Fixture", root: root.path)
        let folder = root.appendingPathComponent("sessions"); try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let log = folder.appendingPathComponent("sample.jsonl")
        let meta: [String: Any] = ["type": "session_meta", "payload": ["id": "native", "cwd": "/tmp", "git": ["repository_url": "https://github.com/team/project.git"]]]
        func line(_ o: [String: Any]) throws -> Data { var d = try JSONSerialization.data(withJSONObject: o); d.append(10); return d }
        var data = try line(meta); data.append(try line(event("task_started"))); data.append(Data("{\"type\":".utf8)); try data.write(to: log)
        let collector = try Collector(root: root.appendingPathComponent("own-data"))
        let first = collector.snapshot(profiles: [profile]); XCTAssertEqual(first.sessions.count, 1); XCTAssertEqual(first.sessions.first?.activity, .working)
        var rotated = try line(meta); rotated.append(try line(event("task_complete", at: 2))); try rotated.write(to: log, options: .atomic)
        let second = collector.snapshot(profiles: [profile]); XCTAssertEqual(second.sessions.first?.activity, .finished); XCTAssertEqual(first.sessions.first?.id, second.sessions.first?.id)
    }
    func testRemoteValidationRejectsStaleAndSpoofedIdentity() throws {
        let s = reducer().session
        var snapshot = Snapshot(machineID: "machine-1", machine: "Mac", generatedAt: now, sessions: [s], coverage: [])
        XCTAssertNoThrow(try RemoteReader.decode(JSONEncoder().encode(snapshot), now: now))
        snapshot.generatedAt = now.addingTimeInterval(-300)
        XCTAssertThrowsError(try RemoteReader.decode(JSONEncoder().encode(snapshot), now: now))
        snapshot.generatedAt = now; snapshot.machineID = "spoofed"
        XCTAssertThrowsError(try RemoteReader.decode(JSONEncoder().encode(snapshot), now: now))
        XCTAssertFalse(RemoteMachine(label: "Bad", sshHost: "-oProxyCommand=evil").isValid)
        XCTAssertFalse(RemoteMachine(label: "Bad", sshHost: "host; echo x").isValid)
        XCTAssertTrue(RemoteMachine(label: "Good", sshHost: "user@home-mac").isValid)
    }
    func testGitHubReviewWaitAndCheckFailures() throws {
        let data = Data(#"{"state":"OPEN","title":"Fix","reviewDecision":"REVIEW_REQUIRED","reviewRequests":[{"login":"reviewer"}],"statusCheckRollup":[{"conclusion":"FAILURE"}]}"#.utf8)
        let pr = try GitHub.parse(data, url: "https://github.com/team/repo/pull/1", now: now)
        XCTAssertTrue(pr.isWaiting); XCTAssertTrue(pr.checksFailed)
        var s = reducer().session; s.activity = .finished; s.pullRequest = pr
        XCTAssertTrue(Preferences().needsAttention(s, now: now))
        s.pullRequest?.checksFailed = false; XCTAssertFalse(Preferences().needsAttention(s, now: now))
    }
    func testCommandTimeoutIsBounded() throws {
        let start = Date()
        XCTAssertThrowsError(try Command.run("/bin/sleep", ["10"], timeout: 0.1))
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
        XCTAssertEqual(String(decoding: try Command.run("/bin/echo", ["safe ; literal"]), as: UTF8.self), "safe ; literal\n")
    }
}
