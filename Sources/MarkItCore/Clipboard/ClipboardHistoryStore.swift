import Foundation

final class ClipboardHistoryStore {
    private(set) var items: [ClipboardItem] = []
    private let maxItems: Int
    private let dedupeWindow: Int
    private let fileURL: URL

    init(maxItems: Int = 200, dedupeWindow: Int = 10, fileURL: URL) {
        self.maxItems = maxItems
        self.dedupeWindow = dedupeWindow
        self.fileURL = fileURL
        load()
    }

    func add(text: String) {
        guard !text.isEmpty else { return }
        let recent = items.prefix(dedupeWindow)
        if recent.contains(where: { $0.text == text }) { return }
        items.insert(ClipboardItem(text: text), at: 0)
        evictIfNeeded()
        save()
    }

    func togglePin(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
        save()
    }

    func clear() {
        items = []
        save()
    }

    func displayed(matching query: String) -> [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered: [ClipboardItem]
        if trimmed.isEmpty {
            filtered = items
        } else {
            filtered = items.filter { $0.text.localizedCaseInsensitiveContains(trimmed) }
        }
        return filtered.filter(\.isPinned) + filtered.filter { !$0.isPinned }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func evictIfNeeded() {
        while items.count > maxItems {
            guard let index = items.lastIndex(where: { !$0.isPinned }) else { break }
            items.remove(at: index)
        }
    }

    static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("MarkIt", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }
}
