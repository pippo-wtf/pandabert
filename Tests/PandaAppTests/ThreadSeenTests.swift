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
}
