import XCTest
@testable import MarkItCore

final class CopyCommitPolicyTests: XCTestCase {
    func test_commandV_cancelsPendingCopy() {
        XCTAssertTrue(CopyCommitPolicy.shouldCancelPendingCopy(keyCode: 9, commandDown: true))
    }

    func test_commandX_cancelsPendingCopy() {
        XCTAssertTrue(CopyCommitPolicy.shouldCancelPendingCopy(keyCode: 7, commandDown: true))
    }

    func test_plainV_doesNotCancel() {
        XCTAssertFalse(CopyCommitPolicy.shouldCancelPendingCopy(keyCode: 9, commandDown: false))
    }

    func test_commandA_doesNotCancel() {
        XCTAssertFalse(CopyCommitPolicy.shouldCancelPendingCopy(keyCode: 0, commandDown: true))
    }
}
