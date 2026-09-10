import XCTest
@testable import PandaCore

final class ClaudeIdentityTests: XCTestCase {
    func withRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
    func record(_ root: URL, desktop: String, fields: [String: Any]) throws -> URL {
        let folder = root.appendingPathComponent("account/org")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var object = fields; object["sessionId"] = desktop
        let file = folder.appendingPathComponent(desktop + ".json")
        try JSONSerialization.data(withJSONObject: object).write(to: file)
        return file
    }
    func testParallProfileDiscoveryFindsExactTaskAndRevalidatesRemoval() throws {
        try withRoot { support in
            let id = UUID().uuidString, desktop = "local_" + UUID().uuidString
            let root = support.appendingPathComponent("Parall/Claude Second/claude-code-sessions")
            let file = try record(root, desktop: desktop, fields: ["cliSessionId": id])
            let roots = ClaudeDesktopIndex.roots(applicationSupport: support)
            XCTAssertEqual(roots.count, 2)
            XCTAssertEqual(ClaudeDesktopIndex.load(roots: roots)[id], desktop)
            let s = Session(nativeID: id, profile: Profile(provider: .claude, label: "Test", root: "/tmp/test"), machineID: "mac", machine: "Mac")
            XCTAssertEqual(ThreadLink.revalidated(session: s, localMachineID: "mac", desktopRoot: root).url?.absoluteString, "claude://claude.ai/epitaxy/" + desktop)
            try FileManager.default.removeItem(at: file)
            XCTAssertNil(ClaudeDesktopIndex.load(roots: roots)[id])
            XCTAssertNil(ThreadLink.revalidated(session: s, localMachineID: "mac", desktopRoot: root).url)
        }
    }
    func testAmbiguousMappingAcrossStandardAndParallProfilesIsRejected() throws {
        try withRoot { support in
            let id = UUID().uuidString
            for directory in ["Claude", "Parall/Claude Second"] {
                _ = try record(support.appendingPathComponent(directory + "/claude-code-sessions"), desktop: "local_" + UUID().uuidString, fields: ["cliSessionId": id])
            }
            XCTAssertNil(ClaudeDesktopIndex.load(roots: ClaudeDesktopIndex.roots(applicationSupport: support))[id])
        }
    }
    func testPriorSessionIDsRemainLinkedWithoutUsingTitlesOrBridgeGuesses() throws {
        try withRoot { root in
            let old = UUID().uuidString, desktop = "local_" + UUID().uuidString
            _ = try record(root, desktop: desktop, fields: ["cliSessionId": UUID().uuidString, "priorCliSessionIds": [old, "invalid?prompt=x"], "title": "Example"])
            let index = ClaudeDesktopIndex.load(root: root)
            XCTAssertEqual(index[old], desktop)
            XCTAssertNil(index["invalid?prompt=x"])
            XCTAssertNil(index["Example"])
        }
    }
    func testForkUsesOwnIDAndDoesNotMergeWithParentOrInheritItsBridge() throws {
        try withRoot { root in
            let parent = UUID().uuidString, fork = UUID().uuidString
            let profile = Profile(provider: .claude, label: "Test", root: root.path)
            let folder = root.appendingPathComponent("projects/example")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let now = Date().timeIntervalSince1970
            let inherited: [[String: Any]] = [
                ["type": "custom-title", "sessionId": parent, "customTitle": "Parent"],
                ["type": "user", "sessionId": parent, "timestamp": now, "bridgeSessionId": "cse_parent", "cwd": "/tmp/parent", "message": ["content": "Parent prompt"]]
            ]
            let own: [[String: Any]] = [
                ["type": "custom-title", "sessionId": fork, "customTitle": "Fork"],
                ["type": "system", "subtype": "turn_duration", "sessionId": fork, "timestamp": now + 1, "cwd": "/tmp/fork"]
            ]
            func write(_ records: [[String: Any]], id: String) throws {
                var data = Data()
                for record in records { data.append(try JSONSerialization.data(withJSONObject: record)); data.append(10) }
                try data.write(to: folder.appendingPathComponent(id + ".jsonl"))
            }
            try write(inherited, id: parent); try write(inherited + own, id: fork)
            let collector = try Collector(root: root.appendingPathComponent("panda"))
            let sessions = collector.snapshot(profiles: [profile]).sessions
            XCTAssertEqual(sessions.count, 2)
            let child = try XCTUnwrap(sessions.first { $0.nativeID == fork })
            XCTAssertEqual(child.title, "Fork"); XCTAssertNil(child.bridgeSessionID)
            XCTAssertEqual(child.activity, .finished); XCTAssertEqual(child.cwd, "/tmp/fork")
            let original = try XCTUnwrap(sessions.first { $0.nativeID == parent })
            XCTAssertEqual(original.title, "Parent"); XCTAssertEqual(original.bridgeSessionID, "cse_parent")
            XCTAssertNotEqual(child.id, original.id)
            XCTAssertEqual(collector.snapshot(profiles: [profile]).sessions.count, 2)
        }
    }
}
