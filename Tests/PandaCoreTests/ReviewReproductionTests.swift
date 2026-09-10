import XCTest
@testable import PandaCore

final class ReviewReproductionTests: XCTestCase {
    let now = Date()
    func event(_ type: String, _ turn: String, _ offset: Double) -> [String: Any] {
        ["type": "event_msg", "timestamp": now.addingTimeInterval(offset).timeIntervalSince1970,
         "payload": ["type": type, "turn_id": turn]]
    }
    func fixture(completed: Bool) throws -> (URL, URL, Profile) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folder = root.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("sample.jsonl")
        var data = Data()
        func append(_ value: [String: Any]) throws { data.append(try JSONSerialization.data(withJSONObject: value)); data.append(10) }
        try append(["type": "session_meta", "payload": ["id": "sample", "git": ["repository_url": "https://github.com/example/sample.git"]]])
        try append(event("task_started", "old-turn", -100))
        try append(event("task_complete", "old-turn", -90))
        let filler: [String: Any] = ["type": "response_item", "payload": ["type": "function_call_output", "output": String(repeating: "x", count: 8192)]]
        for _ in 0..<16 { try append(filler) }
        try append(event("task_started", "current-turn", -30))
        for _ in 0..<300 { try append(filler) }
        try append(["type": "response_item", "timestamp": now.timeIntervalSince1970,
                    "payload": ["type": "function_call", "name": "exec_command", "arguments": "{}"]])
        if completed { try append(event("task_complete", "current-turn", 1)) }
        try data.write(to: file)
        return (root, file, Profile(provider: .codex, label: "Fixture", root: root.path))
    }
    func testTruncatedLogActiveTurnIsNotReportedAsFinished() throws {
        let (root, file, profile) = try fixture(completed: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let collector = try Collector(root: root.appendingPathComponent("pulse"))
        var control = SessionReducer(Session(nativeID: "sample", profile: profile, machineID: "test", machine: "Test"))
        for record in try Collector.readRecords(file, limit: 10 * 1024 * 1024) { control.apply(record) }
        XCTAssertEqual(control.session.activity, .working, "Full-log control establishes a running current turn")
        let bounded = try XCTUnwrap(collector.snapshot(profiles: [profile], now: now).sessions.first)
        XCTAssertNotEqual(bounded.activity, .finished, "An omitted turn start must not leave the old finished turn authoritative")
    }
    func testTruncatedLogAcceptsNewCompletion() throws {
        let (root, file, profile) = try fixture(completed: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let collector = try Collector(root: root.appendingPathComponent("pulse"))
        var control = SessionReducer(Session(nativeID: "sample", profile: profile, machineID: "test", machine: "Test"))
        for record in try Collector.readRecords(file, limit: 10 * 1024 * 1024) { control.apply(record) }
        XCTAssertEqual(control.session.turnID, "current-turn")
        let bounded = try XCTUnwrap(collector.snapshot(profiles: [profile], now: now).sessions.first)
        XCTAssertEqual(bounded.turnID, "current-turn", "The retained completion is discarded against an obsolete turn ID")
        XCTAssertEqual(bounded.completionKey, control.session.completionKey)
    }
}
