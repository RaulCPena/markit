import XCTest
@testable import MarkItCore

final class SelectionDragIntentTests: XCTestCase {
    func test_tinyMovement_isNotASelection() {
        XCTAssertFalse(SelectionDragIntent.isTextDrag(distance: 2, clickCount: 1))
        XCTAssertFalse(SelectionDragIntent.isTextDrag(distance: 9, clickCount: 1))
    }

    func test_realDrag_isASelection() {
        XCTAssertTrue(SelectionDragIntent.isTextDrag(distance: 10, clickCount: 1))
        XCTAssertTrue(SelectionDragIntent.isTextDrag(distance: 40, clickCount: 1))
    }

    func test_doubleClick_isAWordSelection() {
        XCTAssertTrue(SelectionDragIntent.isTextDrag(distance: 0, clickCount: 2))
        XCTAssertTrue(SelectionDragIntent.isTextDrag(distance: 3, clickCount: 3))
    }

    func test_distanceBetweenPoints() {
        XCTAssertEqual(SelectionDragIntent.distance(from: .zero, to: CGPoint(x: 3, y: 4)), 5)
    }
}
