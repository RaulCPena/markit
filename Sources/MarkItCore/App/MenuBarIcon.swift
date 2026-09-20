import Cocoa

enum MenuBarIcon {
    static let systemSymbolName = "doc.on.clipboard.fill"

    static func makeImage() -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: "MarkIt")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image ?? NSImage()
    }
}
