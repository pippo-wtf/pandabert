import XCTest
@testable import PandaCore

final class RenameCompatibilityTests: XCTestCase {
    let home = URL(fileURLWithPath: "/tmp/panda-test-home")
    func testRenameRetainsExistingDataLocation() {
        XCTAssertEqual(PandaPaths.data(environment: [:], home: home).path, "/tmp/panda-test-home/Library/Application Support/Pulse")
    }
    func testLegacyStateOverrideStillWorks() {
        XCTAssertEqual(PandaPaths.data(environment: ["PULSE_HOME": "/tmp/legacy-state"], home: home).path, "/tmp/legacy-state")
    }
    func testPandaOverrideTakesPrecedence() {
        XCTAssertEqual(PandaPaths.data(environment: ["PANDA_HOME": "/tmp/panda-state", "PULSE_HOME": "/tmp/legacy-state"], home: home).path, "/tmp/panda-state")
    }
}
