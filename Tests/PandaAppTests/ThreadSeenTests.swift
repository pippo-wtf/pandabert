import XCTest
import PandaCore
@testable import Panda

final class ThreadSeenTests: XCTestCase {
    private func makeStore(open: @escaping ThreadOpenAction) throws -> PandaStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        var prefs = Preferences(); prefs.profiles = []
        try PandaPaths.save(prefs, to: root.appendingPathComponent("preferences.json"))
        let store = PandaStore(root: root, openConversation: open)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !store.loading }, object: nil)
        wait(for: [ready], timeout: 3)
        return store
    }
    private func task(_ store: PandaStore, activity: Activity = .finished) -> Session {
        var s = Session(nativeID: UUID().uuidString, profile: Profile(provider: .codex, label: "Test", root: "/tmp/test"), machineID: store.localMachineID, machine: "Test Mac")
        s.activity = activity; s.turnID = "first"; s.lastActivityEvent = Date(); s.lastEvent = s.lastActivityEvent
        return s
    }
    private func drainCallback() {
        let done = expectation(description: "Navigation callback handled")
        DispatchQueue.main.async { done.fulfill() }
        wait(for: [done], timeout: 2)
    }
    func testSuccessfulOpenPersistsSeenForOnlyThatCompletionAndKeepsPin() throws {
        var completion: ((Result<Void, Error>) -> Void)?
        var opened: URL?
        let store = try makeStore { url, bundle, callback in
            opened = url; XCTAssertEqual(bundle, "com.openai.codex"); completion = callback
        }
        let s = task(store); store.sessions = [s]; store.preferences.pins = [s.id]
        store.openThread(s)
        XCTAssertEqual(opened?.absoluteString, "codex://threads/" + s.nativeID)
        XCTAssertNil(store.preferences.reviewed[s.id])
        try XCTUnwrap(completion)(.success(())); drainCallback()
        XCTAssertEqual(try PreferencesFile.load(root: store.root)?.reviewed[s.id], s.completionKey)
        XCTAssertFalse(store.preferences.needsAttention(s)); XCTAssertEqual(store.preferences.pins, [s.id])
        var next = s; next.turnID = "second"; next.lastActivityEvent.addTimeInterval(1)
        XCTAssertTrue(store.preferences.needsAttention(next))
    }
    func testFailedOrInvalidOpenDoesNotMarkSeen() throws {
        var completion: ((Result<Void, Error>) -> Void)?
        var calls = 0
        let store = try makeStore { _, _, callback in calls += 1; completion = callback }
        let s = task(store); store.sessions = [s]
        store.openThread(s)
        try XCTUnwrap(completion)(.failure(PandaError.message("Could not open"))); drainCallback()
        XCTAssertNil(store.preferences.reviewed[s.id]); XCTAssertNotNil(store.navigationError)
        var invalid = s; invalid.nativeID = "invalid-id"
        store.openThread(invalid)
        XCTAssertEqual(calls, 1); XCTAssertNil(store.preferences.reviewed[s.id])
    }
    func testDelayedOpenCannotAcknowledgeNewResponseOrOverwriteItsSeenState() throws {
        var completion: ((Result<Void, Error>) -> Void)?
        let store = try makeStore { _, _, callback in completion = callback }
        let old = task(store); store.sessions = [old]; store.openThread(old)
        var next = old; next.turnID = "new"; next.lastActivityEvent.addTimeInterval(1)
        store.sessions = [next]
        try XCTUnwrap(completion)(.success(())); drainCallback()
        XCTAssertNil(store.preferences.reviewed[old.id]); XCTAssertTrue(store.preferences.needsAttention(next))
        store.reviewed(next)
        try XCTUnwrap(completion)(.success(())); drainCallback()
        XCTAssertEqual(store.preferences.reviewed[next.id], next.completionKey)
    }
    func testOpeningQuestionDoesNotDismissItOrACompletionArrivingDuringNavigation() throws {
        var completion: ((Result<Void, Error>) -> Void)?
        let store = try makeStore { _, _, callback in completion = callback }
        let question = task(store, activity: .question); store.sessions = [question]
        store.openThread(question)
        try XCTUnwrap(completion)(.success(())); drainCallback()
        XCTAssertTrue(store.preferences.needsAttention(question)); XCTAssertNil(store.preferences.reviewed[question.id])
        var finished = question; finished.activity = .finished; finished.lastActivityEvent.addTimeInterval(1)
        store.sessions = [finished]
        try XCTUnwrap(completion)(.success(())); drainCallback()
        XCTAssertTrue(store.preferences.needsAttention(finished)); XCTAssertNil(store.preferences.reviewed[finished.id])
    }
    func testUnpinKeepsSeenCardInPlaceUntilExplicitAcknowledgement() throws {
        let store = try makeStore { _, _, _ in }
        let first = task(store), second = task(store)
        store.sessions = [first, second]
        // Seed both cached cards together: this isolated store has no transcript sources.
        store.preferences.pins = [first.id, second.id]; store.save()
        store.reviewed(first)
        XCTAssertEqual(store.keptCards.map(\.id), [first.id, second.id])
        XCTAssertEqual(store.cardPresses[first.id], 1)
        store.pin(first)
        XCTAssertEqual(store.preferences.pins, [second.id])
        XCTAssertEqual(store.keptCards.map(\.id), [first.id, second.id])
        XCTAssertFalse(store.background.contains { $0.id == first.id })
        XCTAssertEqual(try PreferencesFile.load(root: store.root)?.keptCardIDs, [first.id, second.id])
        store.reviewed(first)
        XCTAssertEqual(store.keptCards.map(\.id), [second.id])
        XCTAssertEqual(store.preferences.reviewed[first.id], first.completionKey)
        XCTAssertEqual(store.preferences.pins, [second.id])
    }

    func testOpenOfAlreadySeenUnpinnedCardReleasesOnlyOnSuccess() throws {
        var completion: ((Result<Void, Error>) -> Void)?
        let store = try makeStore { _, _, callback in completion = callback }
        let s = task(store); store.sessions = [s]
        store.pin(s); store.reviewed(s); store.pin(s)
        store.openThread(s)
        try XCTUnwrap(completion)(.failure(PandaError.message("Unavailable"))); drainCallback()
        XCTAssertTrue(store.preferences.keptCardIDs.contains(s.id))
        store.openThread(s)
        try XCTUnwrap(completion)(.success(())); drainCallback()
        XCTAssertFalse(store.preferences.keptCardIDs.contains(s.id))
        XCTAssertEqual(store.preferences.reviewed[s.id], s.completionKey)
    }

    func testExistingPreferencesRetainPinsWithoutNewOrderField() throws {
        var preferences = Preferences(); preferences.pins = ["existing"]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as? [String: Any])
        json.removeValue(forKey: "keptCardOrder")
        var decoded = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.keptCardIDs, ["existing"])
        decoded.togglePin("existing")
        XCTAssertTrue(decoded.pins.isEmpty)
        XCTAssertEqual(decoded.keptCardIDs, ["existing"])
    }

    private func observeFinishedTask(_ store: PandaStore) throws -> Session {
        let root = store.root.appendingPathComponent("sample-profile")
        let logs = root.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let events: [[String: Any]] = [
            ["type": "session_meta", "timestamp": timestamp, "payload": ["id": id, "cwd": "/Sample/Website", "originator": "desktop"]],
            ["type": "event_msg", "timestamp": timestamp, "payload": ["type": "user_message", "message": "Sample task"]],
            ["type": "event_msg", "timestamp": timestamp, "payload": ["type": "task_started", "turn_id": "sample-turn"]],
            ["type": "event_msg", "timestamp": timestamp, "payload": ["type": "task_complete", "turn_id": "sample-turn", "last_agent_message": "Ready for review"]]
        ]
        let lines = try events.map { String(decoding: try JSONSerialization.data(withJSONObject: $0), as: UTF8.self) }.joined(separator: "\n") + "\n"
        try lines.write(to: logs.appendingPathComponent(id + ".jsonl"), atomically: true, encoding: .utf8)
        store.preferences.attentionSince = .distantPast
        try store.completeSetup(profiles: [Profile(provider: .codex, label: "Sample", root: root.path)], remotes: [], githubEnabled: false)
        let observed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            store.sessions.contains { $0.nativeID == id && $0.sourceOnline && $0.activity == .finished }
        }, object: nil)
        wait(for: [observed], timeout: 3)
        return try XCTUnwrap(store.sessions.first { $0.nativeID == id })
    }

    private func waitForUnpinPause() {
        let settled = expectation(description: "Unpin pause elapsed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
    }

    func testUnseenUnpinWaitsThenReturnsToAttentionWithoutAcknowledging() throws {
        let store = try makeStore { _, _, _ in }
        let s = try observeFinishedTask(store)
        store.pin(s); store.pin(s)
        XCTAssertTrue(store.preferences.keptCardIDs.contains(s.id))
        XCTAssertTrue(store.attention.isEmpty)
        waitForUnpinPause()
        XCTAssertFalse(store.preferences.keptCardIDs.contains(s.id))
        XCTAssertNil(store.preferences.reviewed[s.id])
        XCTAssertFalse(try XCTUnwrap(PreferencesFile.load(root: store.root)).keptCardIDs.contains(s.id))
        XCTAssertEqual(store.attention.map(\.id), [s.id])
    }

    func testRepinningOrSeeingDuringPausePreventsReturnToAttention() throws {
        let store = try makeStore { _, _, _ in }
        let s = try observeFinishedTask(store)
        store.pin(s); store.pin(s)
        store.pin(s)
        waitForUnpinPause()
        XCTAssertTrue(store.preferences.pins.contains(s.id))
        XCTAssertTrue(store.preferences.keptCardIDs.contains(s.id))
        store.pin(s)
        // A newer acknowledgement must also be respected when the delayed move runs.
        store.preferences.reviewed[s.id] = s.completionKey
        waitForUnpinPause()
        XCTAssertTrue(store.preferences.keptCardIDs.contains(s.id))
        XCTAssertTrue(store.attention.isEmpty)
    }

    func testDeletePersistsAcrossRefreshAndRestartWithoutChangingTranscript() throws {
        let store = try makeStore { _, _, _ in }
        let s = try observeFinishedTask(store)
        let source = URL(fileURLWithPath: s.sourcePath)
        let bytes = try Data(contentsOf: source)
        store.pin(s)
        try store.deleteCard(s)
        XCTAssertFalse(store.sessions.contains { $0.id == s.id })
        XCTAssertFalse(store.preferences.pins.contains(s.id))
        XCTAssertFalse(store.preferences.keptCardIDs.contains(s.id))
        XCTAssertTrue(try XCTUnwrap(PreferencesFile.load(root: store.root)).isCardDeleted(s.id))
        store.refresh(force: true); waitForUnpinPause()
        XCTAssertFalse(store.sessions.contains { $0.id == s.id })
        let restarted = PandaStore(root: store.root, openConversation: { _, _, _ in })
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !restarted.loading }, object: nil)
        wait(for: [ready], timeout: 3)
        XCTAssertFalse(restarted.sessions.contains { $0.id == s.id })
        XCTAssertEqual(try Data(contentsOf: source), bytes)
        try restarted.restoreDeletedCards()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in restarted.sessions.contains { $0.id == s.id } }, object: nil)
        wait(for: [restored], timeout: 3)
        XCTAssertFalse(restarted.preferences.pins.contains(s.id))
    }

    func testFailedDeleteDoesNotRemoveCardOrPin() throws {
        let store = try makeStore { _, _, _ in }
        let s = try observeFinishedTask(store); store.pin(s)
        let preferencesFile = store.root.appendingPathComponent("preferences.json")
        try FileManager.default.removeItem(at: preferencesFile)
        try FileManager.default.createDirectory(at: preferencesFile, withIntermediateDirectories: false)
        XCTAssertThrowsError(try store.deleteCard(s))
        XCTAssertTrue(store.sessions.contains { $0.id == s.id })
        XCTAssertTrue(store.preferences.pins.contains(s.id))
        XCTAssertFalse(store.preferences.isCardDeleted(s.id))
    }

    func testDeleteDuringPendingUnpinAndOpenCannotResurrectCard() throws {
        var callback: ((Result<Void, Error>) -> Void)?
        let store = try makeStore { _, _, completion in callback = completion }
        let s = try observeFinishedTask(store)
        store.pin(s); store.pin(s); store.openThread(s)
        try store.deleteCard(s)
        try XCTUnwrap(callback)(.success(())); drainCallback()
        waitForUnpinPause()
        XCTAssertFalse(store.sessions.contains { $0.id == s.id })
        XCTAssertFalse(store.preferences.keptCardIDs.contains(s.id))
        XCTAssertNil(store.preferences.reviewed[s.id])
    }

}
