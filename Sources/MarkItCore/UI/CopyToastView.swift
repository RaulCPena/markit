import SwiftUI

struct CopyToastView: View {
    let preview: String

    var body: some View {
        VStack(spacing: 4) {
            Text("Copied")
                .font(.headline)
            if !preview.isEmpty {
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }
}
