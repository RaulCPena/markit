import XCTest
@testable import MarkItCore

final class SelectionGateTests: XCTestCase {
    var defaults: UserDefaults!
    let suiteName = "com.raulpena.markit.tests.selectiongate"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_disabled_neverCopies() {
        let exclusions = ExclusionList(defaults: defaults)
        XCTAssertFalse(SelectionGate.shouldCopy(enabled: false, frontmostBundleID: "com.apple.TextEdit", exclusions: exclusions, ownBundleID: "com.raulpena.markit"))
    }

    func test_enabled_unexcludedApp_copies() {
        let exclusions = ExclusionList(defaults: defaults)
        XCTAssertTrue(SelectionGate.shouldCopy(enabled: true, frontmostBundleID: "com.apple.TextEdit", exclusions: exclusions, ownBundleID: "com.raulpena.markit"))
    }

    func test_excludedApp_doesNotCopy() {
        let exclusions = ExclusionList(defaults: defaults)
        exclusions.add("com.apple.Terminal")
        XCTAssertFalse(SelectionGate.shouldCopy(enabled: true, frontmostBundleID: "com.apple.Terminal", exclusions: exclusions, ownBundleID: "com.raulpena.markit"))
    }

    func test_ownBundleID_neverCopies() {
        let exclusions = ExclusionList(defaults: defaults)
        XCTAssertFalse(SelectionGate.shouldCopy(enabled: true, frontmostBundleID: "com.raulpena.markit", exclusions: exclusions, ownBundleID: "com.raulpena.markit"))
    }

    func test_implicitlyExcludedSystemProcess_doesNotCopy() {
        let exclusions = ExclusionList(defaults: defaults)
        XCTAssertFalse(SelectionGate.shouldCopy(enabled: true, frontmostBundleID: "com.apple.dock", exclusions: exclusions, ownBundleID: "com.raulpena.markit"))
    }
}
