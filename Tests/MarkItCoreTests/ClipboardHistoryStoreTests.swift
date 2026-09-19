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

    func test_load_corruptFile_startsEmpty() {
        try? "not valid json".data(using: .utf8)!.write(to: tempURL)
        let store = ClipboardHistoryStore(fileURL: tempURL)
        XCTAssertEqual(store.items.count, 0)
    }
}
