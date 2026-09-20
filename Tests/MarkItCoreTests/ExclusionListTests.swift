import XCTest
@testable import MarkItCore

final class ExclusionListTests: XCTestCase {
    var defaults: UserDefaults!
    let suiteName = "com.raulpena.markit.tests.exclusionlist"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_add_thenContains_isTrue() {
        let list = ExclusionList(defaults: defaults)
        list.add("com.apple.Terminal")
        XCTAssertTrue(list.contains("com.apple.Terminal"))
    }

    func test_remove_thenContains_isFalse() {
        let list = ExclusionList(defaults: defaults)
        list.add("com.apple.Terminal")
        list.remove("com.apple.Terminal")
        XCTAssertFalse(list.contains("com.apple.Terminal"))
    }

    func test_contains_unknownBundleID_isFalse() {
        let list = ExclusionList(defaults: defaults)
        XCTAssertFalse(list.contains("com.unknown.app"))
    }

    func test_seedsPasswordManagersOnFirstLaunch() {
        let list = ExclusionList(defaults: defaults)
        XCTAssertTrue(list.contains("com.1password.1password"))
        XCTAssertTrue(list.contains("com.apple.keychainaccess"))
    }

    func test_persistsAcrossInstances() {
        let list1 = ExclusionList(defaults: defaults)
        list1.add("com.apple.Terminal")

        let list2 = ExclusionList(defaults: defaults)
        XCTAssertTrue(list2.contains("com.apple.Terminal"))
    }
}
