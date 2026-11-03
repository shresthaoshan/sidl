import ServiceManagement
import XCTest
@testable import Touchyy

/// Stands in for SMAppService, so tests never add a real login item.
private final class FakeLoginItem: LoginItemService {
    var status = SMAppService.Status.notRegistered
    var statusAfterRegister = SMAppService.Status.enabled
    var failure: Error?

    func register() throws {
        if let failure { throw failure }
        status = statusAfterRegister
    }

    func unregister() throws {
        if let failure { throw failure }
        status = .notRegistered
    }
}

final class LaunchAtLoginTests: XCTestCase {
    func testEnableAndDisable() {
        let fake = FakeLoginItem()
        let model = LaunchAtLogin(service: fake)
        XCTAssertFalse(model.isEnabled)

        model.setEnabled(true)
        XCTAssertTrue(model.isEnabled)
        XCTAssertEqual(model.status, .enabled)

        model.setEnabled(false)
        XCTAssertFalse(model.isEnabled)
        XCTAssertNil(model.error)
    }

    func testRequiresApprovalCountsAsEnabled() {
        let fake = FakeLoginItem()
        fake.statusAfterRegister = .requiresApproval
        let model = LaunchAtLogin(service: fake)
        model.setEnabled(true)
        XCTAssertEqual(model.status, .requiresApproval)
        XCTAssertTrue(model.isEnabled)
    }

    func testFailureShowsErrorAndKeepsState() {
        let fake = FakeLoginItem()
        fake.failure = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Operation not permitted"])
        let model = LaunchAtLogin(service: fake)
        model.setEnabled(true)
        XCTAssertFalse(model.isEnabled)
        XCTAssertEqual(model.error, "Operation not permitted")

        fake.failure = nil
        model.setEnabled(true)
        XCTAssertNil(model.error, "a later success clears the error")
    }

    func testRefreshReadsChangesMadeElsewhere() {
        let fake = FakeLoginItem()
        let model = LaunchAtLogin(service: fake)
        fake.status = .enabled  // e.g. turned on in System Settings
        model.refresh()
        XCTAssertTrue(model.isEnabled)
    }
}
