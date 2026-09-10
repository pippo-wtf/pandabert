import XCTest
@testable import PandaCore

final class ObservationPipelineTests: XCTestCase {
    func testLocalUpdatesContinueWhileRemoteAndGitHubAreBlocked() {
        let remoteStarted = expectation(description: "SSH blocked")
        let githubStarted = expectation(description: "GitHub blocked")
        let localChanged = expectation(description: "Second local scan published before external results")
        let merged = expectation(description: "External result preserves newest local status")
        let remoteGate = DispatchSemaphore(value: 0), githubGate = DispatchSemaphore(value: 0)
        defer { remoteGate.signal(); githubGate.signal() }
        let profile = Profile(provider: .codex, label: "Test", root: "/tmp/isolated-profile")
        var prefs = Preferences(); prefs.profiles = [profile]; prefs.githubEnabled = true
        prefs.remotes = [RemoteMachine(label: "Test remote", sshHost: "test.invalid")]
        var reads = 0 // Accessed only by the single local worker.
        var pipeline: ObservationPipeline!
        var sawChange = false, sawMerge = false
        pipeline = ObservationPipeline(root: URL(fileURLWithPath: "/tmp/unused"), local: { _ in
            reads += 1
            var s = Session(nativeID: "local-task", profile: profile, machineID: "local", machine: "Local")
            s.activity = reads == 1 ? .working : .question
            s.lastActivityEvent = Date(); s.lastEvent = s.lastActivityEvent
            s.pullRequest = PullRequest(url: "https://github.com/example/project/pull/1")
            return Snapshot(machineID: "local", machine: "Local", sessions: [s], coverage: [])
        }, remote: { _ in
            remoteStarted.fulfill(); _ = remoteGate.wait(timeout: .now() + 10)
            return Snapshot(machineID: "remote", machine: "Remote", sessions: [], coverage: [])
        }, github: { pr in
            githubStarted.fulfill(); _ = githubGate.wait(timeout: .now() + 10)
            var result = pr; result.review = "APPROVED"; result.checkedAt = Date(); return result
        }, onUpdate: { update in
            if let s = update.sessions.first, s.activity == .question {
                if s.pullRequest?.review != "APPROVED" && !sawChange { sawChange = true; localChanged.fulfill() }
                if s.pullRequest?.review == "APPROVED" && !sawMerge { sawMerge = true; merged.fulfill() }
            }
        })
        pipeline.refresh(preferences: prefs, pins: [])
        wait(for: [remoteStarted, githubStarted], timeout: 3)
        pipeline.refresh(preferences: prefs, pins: [], force: true)
        wait(for: [localChanged], timeout: 3)
        remoteGate.signal(); githubGate.signal()
        wait(for: [merged], timeout: 3)
        withExtendedLifetime(pipeline) {}
    }

    func testRemovedRemoteCannotReappearAfterInFlightRead() {
        let started = expectation(description: "remote started")
        let returned = expectation(description: "remote returned")
        let gate = DispatchSemaphore(value: 0)
        defer { gate.signal() }
        var prefs = Preferences(); prefs.profiles = []
        prefs.remotes = [RemoteMachine(label: "Removed", sshHost: "test.invalid")]
        var latest: ObservationUpdate?
        let pipeline = ObservationPipeline(root: URL(fileURLWithPath: "/tmp/unused"), local: { _ in
            Snapshot(machineID: "local", machine: "Local", sessions: [], coverage: [])
        }, remote: { _ in
            started.fulfill(); _ = gate.wait(timeout: .now() + 10)
            let p = Profile(provider: .claude, label: "Remote", root: "/tmp/test")
            let s = Session(nativeID: "remote-task", profile: p, machineID: "remote", machine: "Remote")
            DispatchQueue.main.async { returned.fulfill() }
            return Snapshot(machineID: "remote", machine: "Remote", sessions: [s], coverage: [])
        }, onUpdate: { latest = $0 })
        pipeline.refresh(preferences: prefs, pins: [])
        wait(for: [started], timeout: 3)
        prefs.remotes = []; pipeline.refresh(preferences: prefs, pins: [])
        gate.signal(); wait(for: [returned], timeout: 3)
        // Drain the main queue after the remote result delivery.
        let drained = expectation(description: "result drained")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { drained.fulfill() }
        wait(for: [drained], timeout: 3)
        XCTAssertTrue(latest?.sessions.isEmpty == true)
        withExtendedLifetime(pipeline) {}
    }
}
