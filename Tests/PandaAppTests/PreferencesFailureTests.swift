import XCTest
@testable import Panda

final class PreferencesFailureTests: XCTestCase {
    func testUnreadablePreferencesStopAppCollectionAndPreserveFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("preferences.json")
        let data = Data("{invalid".utf8); try data.write(to: path)
        let store = PandaStore(root: root)
        store.refresh(force: true); store.save()
        let drained = expectation(description: "No collection queued")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { drained.fulfill() }
        wait(for: [drained], timeout: 2)
        XCTAssertTrue(store.sessions.isEmpty); XCTAssertTrue(store.preferences.profiles.isEmpty)
        XCTAssertFalse(store.loading); XCTAssertFalse(store.issues.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("machine-id").path))
        XCTAssertEqual(try Data(contentsOf: path), data)
    }
}
