import XCTest
@testable import MarkItCore

final class CopyPlannerTests: XCTestCase {
    func test_gateClosed_skips() {
        XCTAssertEqual(
            CopyPlanner.action(gateAllows: false, axSelectedText: "hello", pasteboardString: nil, allowCommandCFallback: true),
            .none
        )
    }

    func test_nonEmptyAXText_writesDirectly() {
        XCTAssertEqual(
            CopyPlanner.action(gateAllows: true, axSelectedText: "hello", pasteboardString: "other", allowCommandCFallback: false),
            .writeToPasteboard("hello")
        )
    }

    func test_sameTextAlreadyOnPasteboard_skips() {
        XCTAssertEqual(
            CopyPlanner.action(gateAllows: true, axSelectedText: "hello", pasteboardString: "hello", allowCommandCFallback: true),
            .none
        )
    }

    func test_mouseWithNoAXText_doesNotFakeCopy() {
        XCTAssertEqual(
            CopyPlanner.action(gateAllows: true, axSelectedText: nil, pasteboardString: "kept", allowCommandCFallback: false),
            .none
        )
        XCTAssertEqual(
            CopyPlanner.action(gateAllows: true, axSelectedText: "", pasteboardString: "kept", allowCommandCFallback: false),
            .none
        )
    }

    func test_keyboardWithNoAXText_fallsBackToCommandC() {
        XCTAssertEqual(
            CopyPlanner.action(gateAllows: true, axSelectedText: nil, pasteboardString: nil, allowCommandCFallback: true),
            .simulateCommandC
        )
    }
}
