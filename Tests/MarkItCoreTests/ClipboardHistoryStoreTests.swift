import XCTest
@testable import MarkItCore

final class ClipboardHistoryStoreTests: XCTestCase {
    var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func test_add_appendsNewItemAtFront() {
        let store = ClipboardHistoryStore(fileURL: tempURL)
        store.add(text: "hello")
        store.add(text: "world")
        XCTAssertEqual(store.items.map { $0.text }, ["world", "hello"])
    }

    func test_add_skipsDuplicateWithinDedupeWindow() {
        let store = ClipboardHistoryStore(dedupeWindow: 10, fileURL: tempURL)
        store.add(text: "hello")
        store.add(text: "hello")
        XCTAssertEqual(store.items.count, 1)
    }

    func test_add_capsAtMaxItems() {
        let store = ClipboardHistoryStore(maxItems: 3, dedupeWindow: 0, fileURL: tempURL)
        store.add(text: "a")
        store.add(text: "b")
        store.add(text: "c")
        store.add(text: "d")
        XCTAssertEqual(store.items.map { $0.text }, ["d", "c", "b"])
    }

    func test_persistAndReload_roundTrips() {
        let store1 = ClipboardHistoryStore(fileURL: tempURL)
        store1.add(text: "persisted")

        let store2 = ClipboardHistoryStore(fileURL: tempURL)
        XCTAssertEqual(store2.items.map { $0.text }, ["persisted"])
    }

    func test_clear_emptiesItems() {
        let store = ClipboardHistoryStore(fileURL: tempURL)
        store.add(text: "hello")
        store.clear()
        XCTAssertEqual(store.items.count, 0)
    }

    func test_remove_deletesOneItemByID() {
        let store = ClipboardHistoryStore(fileURL: tempURL)
        store.add(text: "keep")
        store.add(text: "drop")
        let drop = store.items.first(where: { $0.text == "drop" })!
        store.remove(id: drop.id)
        XCTAssertEqual(store.items.map(\.text), ["keep"])
    }

    func test_remove_unknownID_isNoOp() {
        let store = ClipboardHistoryStore(fileURL: tempURL)
        store.add(text: "keep")
        store.remove(id: UUID())
        XCTAssertEqual(store.items.map(\.text), ["keep"])
    }

    func test_togglePin_andDisplayed_putsPinnedFirst() {
        let store = ClipboardHistoryStore(fileURL: tempURL)
        store.add(text: "one")
        store.add(text: "two")
        store.add(text: "three")
        let one = store.items.first(where: { $0.text == "one" })!
        store.togglePin(id: one.id)
        XCTAssertEqual(store.displayed(matching: "").map(\.text), ["one", "three", "two"])
        XCTAssertEqual(store.displayed(matching: "t").map(\.text), ["three", "two"])
    }

    func test_cap_doesNotEvictPinned() {
        let store = ClipboardHistoryStore(maxItems: 2, dedupeWindow: 0, fileURL: tempURL)
        store.add(text: "keep")
        store.togglePin(id: store.items[0].id)
        store.add(text: "b")
        store.add(text: "c")
        XCTAssertTrue(store.items.contains(where: { $0.text == "keep" && $0.isPinned }))
        XCTAssertEqual(store.items.count, 2)
    }

    func test_load_legacyJSON_withoutPinned_isUnpinned() {
        let legacy = [
            "id": UUID().uuidString,
            "text": "legacy",
            "timestamp": Date().timeIntervalSinceReferenceDate
        ] as [String: Any]
        let data = try! JSONSerialization.data(withJSONObject: [legacy])
        try! data.write(to: tempURL)
        let store = ClipboardHistoryStore(fileURL: tempURL)
        XCTAssertEqual(store.items.first?.text, "legacy")
        XCTAssertEqual(store.items.first?.isPinned, false)
    }

    func test_load_corruptFile_startsEmpty() {
        try? "not valid json".data(using: .utf8)!.write(to: tempURL)
        let store = ClipboardHistoryStore(fileURL: tempURL)
        XCTAssertEqual(store.items.count, 0)
    }
}
