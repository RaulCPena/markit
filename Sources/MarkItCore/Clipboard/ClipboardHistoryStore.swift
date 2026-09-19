import Foundation

public final class ClipboardHistoryStore {
    public private(set) var items: [ClipboardItem] = []
    private let maxItems: Int
    private let dedupeWindow: Int
    private let fileURL: URL

    public init(maxItems: Int = 50, dedupeWindow: Int = 10, fileURL: URL) {
        self.maxItems = maxItems
        self.dedupeWindow = dedupeWindow
        self.fileURL = fileURL
        load()
    }

    public func add(text: String) {
        guard !text.isEmpty else { return }
        let recent = items.prefix(dedupeWindow)
        if recent.contains(where: { $0.text == text }) { return }
        items.insert(ClipboardItem(id: UUID(), text: text, timestamp: Date()), at: 0)
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
        save()
    }

    public func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    public func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

extension ClipboardHistoryStore {
    public static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("MarkIt", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }
}
