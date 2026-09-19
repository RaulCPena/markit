import XCTest
@testable import MarkItCore

final class MenuBarIconTests: XCTestCase {
    func test_usesHighlighterSymbolAsTemplate() {
        XCTAssertEqual(MenuBarIcon.systemSymbolName, "highlighter")
        let image = MenuBarIcon.makeImage()
        XCTAssertNotNil(image)
        XCTAssertTrue(image?.isTemplate ?? false)
    }
}

final class CopyFeedbackTests: XCTestCase {
    func test_usesTinkSystemSound() {
        XCTAssertEqual(CopyFeedback.soundName, "Tink")
        XCTAssertNotNil(NSSound(named: NSSound.Name(CopyFeedback.soundName)))
    }
}
