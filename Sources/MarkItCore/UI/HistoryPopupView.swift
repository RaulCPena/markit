import SwiftUI

struct HistoryPopupView: View {
    let items: [ClipboardItem]
    let onSelect: (ClipboardItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if items.isEmpty {
                Text("No clipboard history yet")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(items) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        Text(item.text.prefix(80))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 320)
        .padding(.vertical, 6)
    }
}
