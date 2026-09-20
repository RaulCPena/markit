import Cocoa

enum PasteboardPrivacy {
    static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    static func isConcealed(types: [NSPasteboard.PasteboardType]?) -> Bool {
        types?.contains(concealedType) == true
    }
}

enum PasteboardActions {
    /// HID virtual key codes (same as Carbon / USB HID Usage Tables for these keys).
    private enum KeyCode {
        static let command: CGKeyCode = 0x37
        static let c: CGKeyCode = 0x08
        static let v: CGKeyCode = 0x09
    }

    static func putText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func copyToFrontmostApp() {
        postCommandKey(KeyCode.c)
    }

    static func pasteToFrontmostApp() {
        postCommandKey(KeyCode.v)
    }

    private static func postCommandKey(_ key: CGKeyCode) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        source.localEventsSuppressionInterval = 0
        let commandDown = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.command, keyDown: true)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        let commandUp = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.command, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        let tap = CGEventTapLocation.cghidEventTap
        commandDown?.post(tap: tap)
        keyDown?.post(tap: tap)
        keyUp?.post(tap: tap)
        commandUp?.post(tap: tap)
    }
}
