import Cocoa

enum MenuBarIcon {
    /// Fallback if the custom template asset is missing from the app bundle.
    static let fallbackSystemSymbolName = "highlighter"

    static func makeImage() -> NSImage {
        if let custom = loadBundledTemplate() {
            return custom
        }
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = NSImage(systemSymbolName: fallbackSystemSymbolName, accessibilityDescription: "MarkIt")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image ?? NSImage()
    }

    /// Logo silhouette (highlighter + stroke). Copied into MarkIt.app/Contents/Resources by the packager scripts.
    private static func loadBundledTemplate() -> NSImage? {
        let bundle = Bundle.main
        let candidates: [URL?] = [
            bundle.url(forResource: "MenuBarIcon", withExtension: "pdf"),
            bundle.url(forResource: "MenuBarIcon", withExtension: "png"),
        ]
        for case let url? in candidates {
            guard let image = NSImage(contentsOf: url) else { continue }
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        return nil
    }
}
