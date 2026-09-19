import Cocoa

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var demoHotkey: HotkeyManager?
    private var demoPopup: HistoryPopupController?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "MarkIt")
        statusItem.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // TEMPORARY demo wiring to manually verify the hotkey + history popup
        // end-to-end. Task 6 replaces this with the real integration.
        let demoStore = ClipboardHistoryStore(fileURL: ClipboardHistoryStore.defaultFileURL())
        demoStore.add(text: "First demo item")
        demoStore.add(text: "Second demo item")
        let demoPopup = HistoryPopupController(store: demoStore)
        let demoHotkey = HotkeyManager()
        demoHotkey.onTrigger = { demoPopup.toggle() }
        _ = demoHotkey.register()
        self.demoHotkey = demoHotkey // retain
        self.demoPopup = demoPopup   // retain
    }
}
