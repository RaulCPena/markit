import XCTest
@testable import MarkItCore

final class AppSettingsTests: XCTestCase {
    var defaults: UserDefaults!
    let suiteName = "com.raulpena.markit.tests.appsettings"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_autoCopyDefaultsOnAndPersists() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.isAutoCopyEnabled)
        settings.isAutoCopyEnabled = false
        XCTAssertFalse(AppSettings(defaults: defaults).isAutoCopyEnabled)
    }

    func test_soundDefaultsOnAndPersists() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.isCopySoundEnabled)
        settings.isCopySoundEnabled = false
        XCTAssertFalse(AppSettings(defaults: defaults).isCopySoundEnabled)
    }
}

final class PasteboardPrivacyTests: XCTestCase {
    func test_concealedTypeIsDetected() {
        XCTAssertTrue(PasteboardPrivacy.isConcealed(types: [PasteboardPrivacy.concealedType]))
        XCTAssertFalse(PasteboardPrivacy.isConcealed(types: [.string]))
        XCTAssertFalse(PasteboardPrivacy.isConcealed(types: nil))
    }
}
