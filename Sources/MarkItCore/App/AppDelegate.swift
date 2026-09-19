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
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            OnboardingWindowController.shared.showIfNeeded()
            self?.statusBarController.updateTrustState()
            // Re-arm the event tap here: on first launch tapCreate fails until Accessibility
            // is granted, and returning to MarkIt after granting is the realistic path back.
            // (A background poll would also be needed to cover granting it with no MarkIt
            // interaction afterwards — deliberately out of scope for v1.)
            self?.selectionWatcher.startIfNeeded()
        }
    }
}
