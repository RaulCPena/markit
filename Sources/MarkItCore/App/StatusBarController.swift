import Cocoa

public final class StatusBarController: NSObject {
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
        super.init()
        configureIcon()
        buildMenu()
        updateTrustState()
    }

    private func configureIcon() {
        guard let button = statusItem.button else { return }
        button.image = MenuBarIcon.makeImage()
        button.toolTip = "MarkIt"
        button.imagePosition = .imageOnly
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

        let excludedItem = NSMenuItem(title: "Excluded Apps…", action: #selector(showExcludedApps), keyEquivalent: "")
        excludedItem.target = self
        menu.addItem(excludedItem)

        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LoginItemManager.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "About MarkIt", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit MarkIt", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleAutoCopy(_ sender: NSMenuItem) {
        isAutoCopyEnabled.toggle()
        sender.state = isAutoCopyEnabled ? .on : .off
    }

    @objc private func showHistory() {
        historyPopup.toggle()
    }

    @objc private func showExcludedApps() {
        ExcludedAppsWindowController.shared.show(exclusions: exclusions)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        LoginItemManager.setEnabled(!LoginItemManager.isEnabled)
        sender.state = LoginItemManager.isEnabled ? .on : .off
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func updateTrustState() {
        statusItem.button?.appearsDisabled = !AccessibilityPermissionManager.isTrusted
    }
}
