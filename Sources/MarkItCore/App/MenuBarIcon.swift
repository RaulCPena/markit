import Cocoa

enum MenuBarIcon {
    static let systemSymbolName = "highlighter"

    static func makeImage() -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: "MarkIt")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }
}
