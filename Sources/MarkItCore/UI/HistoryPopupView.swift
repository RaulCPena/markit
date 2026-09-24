import SwiftUI
import Combine

struct HistoryPopupView: View {
    @ObservedObject var model: HistoryPopupModel
    var onPaste: (ClipboardItem) -> Void
    var onPin: (ClipboardItem) -> Void
    var onDelete: (ClipboardItem) -> Void
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Search history", text: $model.query)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .onSubmit { pasteFirst() }
                .padding(8)

            if model.visible.isEmpty {
                Text(model.query.isEmpty ? "No clipboard history yet" : "No matches")
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(model.visible) { item in
                        HStack(spacing: 8) {
                            Button {
                                onPin(item)
                            } label: {
                                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                                    .foregroundStyle(item.isPinned ? Color.accentColor : Color.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(item.isPinned ? "Unpin" : "Pin")

                            Button {
                                onPaste(item)
                            } label: {
                                Text(item.text)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { offsets in
                        let snapshot = model.visible
                        for index in offsets {
                            guard snapshot.indices.contains(index) else { continue }
                            onDelete(snapshot[index])
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 380, height: 420)
        .onAppear { searchFocused = true }
    }

    private func pasteFirst() {
        guard let first = model.visible.first else { return }
        onPaste(first)
    }
}

final class HistoryPopupModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var items: [ClipboardItem]
    private let store: ClipboardHistoryStore

    init(store: ClipboardHistoryStore) {
        self.store = store
        self.items = store.items
    }

    var visible: [ClipboardItem] {
        store.displayed(matching: query)
    }

    func reload() {
        items = store.items
    }
}
