import Cocoa

public final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let selectionWatcher: SelectionWatcher
    private let historyPopup: HistoryPopupController
    private let hotkeyManager: HotkeyManager
    let exclusions: ExclusionList
    private let settings: AppSettings

    public init(selectionWatcher: SelectionWatcher, historyPopup: HistoryPopupController, hotkeyManager: HotkeyManager, exclusions: ExclusionList, settings: AppSettings = AppSettings()) {
        self.selectionWatcher = selectionWatcher
        self.historyPopup = historyPopup
        self.hotkeyManager = hotkeyManager
        self.exclusions = exclusions
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        selectionWatcher.isEnabled = settings.isAutoCopyEnabled
        configureIcon()
        buildMenu()
        updateTrustState()
    }

    private func configureIcon() {
        guard let button = statusItem.button else { return }
        button.image = MenuBarIcon.makeImage()
        button.toolTip = "MarkIt"
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
    }

    private func buildMenu() {
        let menu = NSMenu()
        let trusted = AccessibilityPermissionManager.isTrusted

        if !trusted {
            let grantItem = NSMenuItem(title: "Turn On Accessibility…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
            grantItem.target = self
            menu.addItem(grantItem)
            let revealItem = NSMenuItem(title: "Show MarkIt in Finder", action: #selector(revealAppInFinder), keyEquivalent: "")
            revealItem.target = self
            menu.addItem(revealItem)
            menu.addItem(.separator())
        }

        let toggleItem = NSMenuItem(title: "Auto-copy on Select", action: #selector(toggleAutoCopy), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = settings.isAutoCopyEnabled ? .on : .off
        toggleItem.isEnabled = trusted
        menu.addItem(toggleItem)

        let soundRoot = NSMenuItem(title: "Copy Sound", action: nil, keyEquivalent: "")
        let soundMenu = NSMenu()
        let offItem = NSMenuItem(title: "Off", action: #selector(disableCopySound), keyEquivalent: "")
        offItem.target = self
        offItem.state = settings.isCopySoundEnabled ? .off : .on
        soundMenu.addItem(offItem)
        for name in AppSettings.systemSoundNames {
            let item = NSMenuItem(title: name, action: #selector(chooseCopySound(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = name
            item.state = (settings.isCopySoundEnabled && settings.copySoundName == name) ? .on : .off
            soundMenu.addItem(item)
        }
        soundRoot.submenu = soundMenu
        menu.addItem(soundRoot)

        let historyItem = NSMenuItem(title: "Clipboard History", action: #selector(showHistory), keyEquivalent: "")
        historyItem.target = self
        menu.addItem(historyItem)

        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

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
        settings.isAutoCopyEnabled.toggle()
        selectionWatcher.isEnabled = settings.isAutoCopyEnabled
        sender.state = settings.isAutoCopyEnabled ? .on : .off
    }

    @objc private func disableCopySound(_ sender: NSMenuItem) {
        settings.isCopySoundEnabled = false
        buildMenu()
    }

    @objc private func chooseCopySound(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        settings.copySoundName = name
        settings.isCopySoundEnabled = true
        CopyFeedback.play(settings: settings)
        buildMenu()
    }

    @objc private func showHistory() {
        historyPopup.toggle()
    }

    @objc private func clearHistory() {
        historyPopup.store.clear()
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

    @objc private func openAccessibilitySettings() {
        AccessibilityPermissionManager.requestPermission()
    }

    @objc private func revealAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    func updateTrustState() {
        statusItem.button?.appearsDisabled = false
        buildMenu()
    }
}
