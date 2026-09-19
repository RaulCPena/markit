import Cocoa

public final class StatusBarController {
    private let statusItem: NSStatusItem
    private let selectionWatcher: SelectionWatcher
    private let historyPopup: HistoryPopupController
    private let hotkeyManager: HotkeyManager
    let exclusions: ExclusionList
    private var isAutoCopyEnabled = true {
        didSet { selectionWatcher.isEnabled = isAutoCopyEnabled }
    }

    public init(selectionWatcher: SelectionWatcher, historyPopup: HistoryPopupController, hotkeyManager: HotkeyManager, exclusions: ExclusionList) {
        self.selectionWatcher = selectionWatcher
        self.historyPopup = historyPopup
        self.hotkeyManager = hotkeyManager
        self.exclusions = exclusions
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureIcon()
        buildMenu()
    }

    private func configureIcon() {
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "MarkIt")
        statusItem.button?.image?.isTemplate = true
    }

    private func buildMenu() {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Auto-copy on Select", action: #selector(toggleAutoCopy), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = isAutoCopyEnabled ? .on : .off
        menu.addItem(toggleItem)

        let historyItem = NSMenuItem(title: "Clipboard History", action: #selector(showHistory), keyEquivalent: "")
        historyItem.target = self
        menu.addItem(historyItem)

        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LoginItemManager.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "About MarkIt", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func toggleAutoCopy(_ sender: NSMenuItem) {
        isAutoCopyEnabled.toggle()
        sender.state = isAutoCopyEnabled ? .on : .off
    }

    @objc private func showHistory() {
        historyPopup.toggle()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        LoginItemManager.setEnabled(!LoginItemManager.isEnabled)
        sender.state = LoginItemManager.isEnabled ? .on : .off
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
