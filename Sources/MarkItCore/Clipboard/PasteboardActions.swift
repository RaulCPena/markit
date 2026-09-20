import Cocoa

enum PasteboardPrivacy {
    static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    static func isConcealed(types: [NSPasteboard.PasteboardType]?) -> Bool {
        types?.contains(concealedType) == true
    }
}

enum PasteboardActions {
    static func putText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func pasteToFrontmostApp() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        source.localEventsSuppressionInterval = 0
        let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        let tap = CGEventTapLocation.cghidEventTap
        commandDown?.post(tap: tap)
        keyDown?.post(tap: tap)
        keyUp?.post(tap: tap)
        commandUp?.post(tap: tap)
    }
}
