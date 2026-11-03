import XCTest
@testable import Sidl

final class ActionsTests: XCTestCase {
    /// Play/Pause must not depend on a synthesized media key, which macOS drops without Accessibility permission.
    func testMediaRemoteCommandSenderLoads() {
        XCTAssertNotNil(Actions.sendMediaCommand)
    }
}
