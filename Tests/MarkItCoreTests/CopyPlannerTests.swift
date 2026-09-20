import XCTest
@testable import MarkItCore

final class CopyPlannerTests: XCTestCase {
    func test_gateClosed_skips() {
        XCTAssertEqual(CopyPlanner.action(gateAllows: false, axSelectedText: "hello"), .none)
    }

    func test_nonEmptyAXText_writesDirectly() {
        XCTAssertEqual(
            CopyPlanner.action(gateAllows: true, axSelectedText: "hello"),
            .writeToPasteboard("hello")
        )
    }

    func test_unknownOrEmptyAXText_fallsBackToCommandC() {
        XCTAssertEqual(CopyPlanner.action(gateAllows: true, axSelectedText: nil), .simulateCommandC)
        XCTAssertEqual(CopyPlanner.action(gateAllows: true, axSelectedText: ""), .simulateCommandC)
    }
}
