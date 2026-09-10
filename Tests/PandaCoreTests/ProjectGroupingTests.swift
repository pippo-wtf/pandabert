import XCTest
@testable import PandaCore

final class ProjectGroupingTests: XCTestCase {
    private func session(_ id: String, cwd: String, repository: String = "", machine: String = "local") -> Session {
        var s = Session(nativeID: id, profile: Profile(provider: .codex, label: "Sample", root: "/sample/logs"), machineID: machine, machine: "Sample Mac")
        s.cwd = cwd; s.repository = repository
        return s
    }

    func testSharesOnlyUnambiguousLogMetadataForSameMachineAndFolder() {
        let path = "/Users/sample/Desktop/Project"
        let missing = session("missing", cwd: path)
        let known = session("known", cwd: path, repository: "https://user:secret@github.com/team/project.git")
        let remote = session("remote", cwd: path, machine: "another-machine")
        let grouped = Collector.groupProjects([missing, known, remote])
        XCTAssertEqual(grouped[0].projectKey, "github.com/team/project")
        XCTAssertEqual(grouped[0].repository, grouped[1].repository)
        XCTAssertFalse(grouped[1].repository.contains("secret"))
        XCTAssertTrue(grouped[2].repository.isEmpty)
        XCTAssertEqual(grouped[2].project, "Project")

        let conflict = session("conflict", cwd: path, repository: "https://github.com/other/project.git")
        let ambiguous = Collector.groupProjects([missing, known, conflict])
        XCTAssertTrue(ambiguous[0].repository.isEmpty)
        XCTAssertEqual(ambiguous[0].projectKey, "local:" + path)
        XCTAssertNotEqual(ambiguous[1].projectKey, ambiguous[2].projectKey)
    }

    func testCollectorDoesNotReadGitRepositoryFromRecordedWorkingFolder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        // This Desktop is entirely inside the disposable fixture, not the user's Desktop.
        let project = root.appendingPathComponent("Desktop/Project")
        let git = project.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: git.appendingPathComponent("objects"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: git.appendingPathComponent("refs"), withIntermediateDirectories: true)
        try "ref: refs/heads/main\n".write(to: git.appendingPathComponent("HEAD"), atomically: true, encoding: .utf8)
        let origin = "https://github.com/disk-only/must-not-be-read.git"
        try "[core]\nrepositoryformatversion = 0\nbare = false\n[remote \"origin\"]\nurl = \(origin)\n".write(to: git.appendingPathComponent("config"), atomically: true, encoding: .utf8)
        XCTAssertEqual(String(decoding: try Command.run("/usr/bin/git", ["-C", project.path, "config", "--get", "remote.origin.url"]), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines), origin)
        let profile = Profile(provider: .codex, label: "Fixture", root: root.appendingPathComponent("profile").path)
        let logs = URL(fileURLWithPath: profile.root).appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let meta: [String: Any] = ["type": "session_meta", "payload": ["id": "sample", "cwd": project.path]]
        var data = try JSONSerialization.data(withJSONObject: meta); data.append(10)
        try data.write(to: logs.appendingPathComponent("sample.jsonl"))
        let collector = try Collector(root: root.appendingPathComponent("state"))
        let result = try XCTUnwrap(collector.snapshot(profiles: [profile]).sessions.first)
        XCTAssertTrue(result.repository.isEmpty)
        XCTAssertEqual(result.project, "Project")
        XCTAssertEqual(result.projectKey, collector.machineID + ":" + project.path)
    }
}
