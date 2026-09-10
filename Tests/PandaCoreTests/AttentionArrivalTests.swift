import XCTest
@testable import PandaCore

final class AttentionArrivalTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var prefs: Preferences { var p = Preferences(); p.attentionSince = now.addingTimeInterval(-100); return p }
    func task(_ name: String = "a", activity: Activity = .working, offset: Double = 0) -> Session {
        var s = Session(nativeID: name, profile: Profile(provider: .codex, label: "Test", root: "/tmp/test"), machineID: "test", machine: "Test")
        s.activity = activity; s.turnID = "turn-1"; s.lastActivityEvent = now.addingTimeInterval(offset); s.lastEvent = s.lastActivityEvent
        return s
    }
    func testLaterSourceBaselineDoesNotGlowButItsNextUpdateDoes() {
        var tracker = AttentionArrivalTracker()
        _ = tracker.observe([], preferences: prefs, now: now)
        var s = task(activity: .question)
        tracker.establishBaseline([s], preferences: prefs, now: now)
        XCTAssertNil(tracker.observe([s], preferences: prefs, now: now))
        s.turnID = "next-turn"; s.lastActivityEvent = now.addingTimeInterval(1)
        XCTAssertNotNil(tracker.observe([s], preferences: prefs, now: now.addingTimeInterval(2)))
    }
    func testStartupBacklogAndRepeatedPollsDoNotGlow() {
        var tracker = AttentionArrivalTracker(); var s = task(activity: .question)
        XCTAssertNil(tracker.observe([s], preferences: prefs, now: now))
        s.excerpt = "Updated context"; s.lastEvent = now.addingTimeInterval(3)
        XCTAssertNil(tracker.observe([s], preferences: prefs, now: now.addingTimeInterval(5)))
    }
    func testCompletionGlowsOnceAndNextTurnCanNotifyAgain() {
        var tracker = AttentionArrivalTracker(); var s = task()
        XCTAssertNil(tracker.observe([s], preferences: prefs, now: now))
        s.activity = .finished; s.lastActivityEvent = now.addingTimeInterval(1)
        let arrival = tracker.observe([s], preferences: prefs, now: now.addingTimeInterval(5))
        XCTAssertEqual(arrival?.sessionID, s.id); XCTAssertEqual(arrival?.startedAt, now.addingTimeInterval(5))
        XCTAssertNil(tracker.observe([s], preferences: prefs, now: now.addingTimeInterval(10)))
        s.turnID = "turn-2"; s.lastActivityEvent = now.addingTimeInterval(15)
        XCTAssertNotNil(tracker.observe([s], preferences: prefs, now: now.addingTimeInterval(20)))
    }
    func testOnlyNewestArrivalWinsIncludingPinnedTasks() {
        var tracker = AttentionArrivalTracker(); _ = tracker.observe([], preferences: prefs, now: now)
        let a = task("a", activity: .question, offset: 1), b = task("b", activity: .question, offset: 2)
        var preferences = prefs; preferences.pins = [b.id]
        XCTAssertEqual(tracker.observe([b, a], preferences: preferences, now: now.addingTimeInterval(5))?.sessionID, b.id)
    }
    func testReconnectAndReappearanceDoNotReplayNotification() {
        var tracker = AttentionArrivalTracker(); var s = task(activity: .question)
        _ = tracker.observe([s], preferences: prefs, now: now)
        s.sourceOnline = false
        XCTAssertNil(tracker.observe([s], preferences: prefs, now: now))
        _ = tracker.observe([], preferences: prefs, now: now)
        s.sourceOnline = true
        XCTAssertNil(tracker.observe([s], preferences: prefs, now: now))
    }
    func testLinkedPRWithoutGitHubEvidenceDoesNotSuppressQuestion() {
        var tracker = AttentionArrivalTracker(); var s = task()
        s.pullRequest = PullRequest(url: "https://github.com/example/project/pull/1")
        _ = tracker.observe([s], preferences: prefs, now: now)
        s.activity = .question; s.pendingCallID = "question-1"
        XCTAssertEqual(tracker.observe([s], preferences: prefs, now: now)?.sessionID, s.id)
    }
    func testPRRefreshAndTemporaryFailureDoNotRestartGlow() {
        var tracker = AttentionArrivalTracker(); var s = task(activity: .finished)
        var pr = PullRequest(url: "https://github.com/example/project/pull/1")
        pr.checkedAt = now; pr.state = "OPEN"; s.pullRequest = pr
        _ = tracker.observe([s], preferences: prefs, now: now)
        pr.review = "CHANGES_REQUESTED"; s.pullRequest = pr
        XCTAssertNotNil(tracker.observe([s], preferences: prefs, now: now))
        pr.checkedAt = now.addingTimeInterval(5); s.pullRequest = pr
        XCTAssertNil(tracker.observe([s], preferences: prefs, now: now.addingTimeInterval(5)))
        pr.error = "Offline"; s.pullRequest = pr
        XCTAssertNil(tracker.observe([s], preferences: prefs, now: now.addingTimeInterval(10)))
        pr.error = nil; s.pullRequest = pr
        XCTAssertNil(tracker.observe([s], preferences: prefs, now: now.addingTimeInterval(15)))
    }
    func testReviewedAndWaitingCompletionsDoNotGlow() {
        var tracker = AttentionArrivalTracker(); _ = tracker.observe([], preferences: prefs, now: now)
        let a = task("a", activity: .finished), b = task("b", activity: .finished)
        var preferences = prefs; preferences.reviewed[a.id] = a.completionKey; preferences.waits[b.id] = "Teammate"
        XCTAssertNil(tracker.observe([a, b], preferences: preferences, now: now))
    }
}
