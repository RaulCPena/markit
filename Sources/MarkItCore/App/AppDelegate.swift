import Cocoa
import os.log

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var selectionWatcher: SelectionWatcher!
    private var hotkeyManager: HotkeyManager!
    private var historyPopup: HistoryPopupController!
    private let exclusions = ExclusionList()
    private let historyStore = ClipboardHistoryStore(fileURL: ClipboardHistoryStore.defaultFileURL())

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        selectionWatcher = SelectionWatcher(exclusions: exclusions)
        selectionWatcher.onCopy = { [weak self] in
            guard let text = NSPasteboard.general.string(forType: .string) else { return }
            self?.historyStore.add(text: text)
            CopyFeedback.play()
        }
        selectionWatcher.start()

        historyPopup = HistoryPopupController(store: historyStore)

        hotkeyManager = HotkeyManager()
        hotkeyManager.onTrigger = { [weak self] in self?.historyPopup.toggle() }
        if !hotkeyManager.register() {
            os_log("MarkIt: failed to register global hotkey — Clipboard History popup will not be available via ⌘⇧V this session")
        }

        statusBarController = StatusBarController(
            selectionWatcher: selectionWatcher,
            historyPopup: historyPopup,
            hotkeyManager: hotkeyManager,
            exclusions: exclusions
        )

        OnboardingWindowController.shared.showIfNeeded()
        let syncTrust: (Notification) -> Void = { [weak self] _ in
            OnboardingWindowController.shared.showIfNeeded()
            self?.statusBarController.updateTrustState()
            self?.selectionWatcher.startIfNeeded()
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main, using: syncTrust)
        // Debug builds used to miss the grant until the next click; onboarding now polls and
        // posts this when AXIsProcessTrusted() flips while System Settings is still frontmost.
        NotificationCenter.default.addObserver(forName: .markItAccessibilityTrusted, object: nil, queue: .main, using: syncTrust)
    }
}
