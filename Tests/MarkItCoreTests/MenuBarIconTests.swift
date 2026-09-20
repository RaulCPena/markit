import XCTest
@testable import MarkItCore

final class MenuBarIconTests: XCTestCase {
    func test_usesClipboardTemplate() {
        XCTAssertEqual(MenuBarIcon.systemSymbolName, "doc.on.clipboard.fill")
        let image = MenuBarIcon.makeImage()
        XCTAssertTrue(image.isTemplate)
        XCTAssertGreaterThan(image.size.width, 0)
    }
}

final class CopyFeedbackTests: XCTestCase {
    func test_usesSystemSoundsAndSilentDefault() {
        XCTAssertTrue(AppSettings.systemSoundNames.contains("Purr"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: CopyFeedback.fallbackPath))
    }
}

final class CopyToastCopyTests: XCTestCase {
    func test_previewCollapsesAndTruncates() {
        XCTAssertEqual(CopyToastCopy.preview(from: "  hello\nworld  ", maxLength: 20), "hello world")
        XCTAssertEqual(CopyToastCopy.preview(from: String(repeating: "a", count: 60), maxLength: 8), "aaaaaaaa…")
    }
}

final class AccessibilityPermissionManagerTests: XCTestCase {
    func test_settingsURLsTargetAccessibilityPane() {
        XCTAssertEqual(
            AccessibilityPermissionManager.settingsURLStrings.first,
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        )
        XCTAssertTrue(AccessibilityPermissionManager.settingsURLStrings.contains(
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ))
    }
}
