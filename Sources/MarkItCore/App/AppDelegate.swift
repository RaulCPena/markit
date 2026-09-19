import Cocoa

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
        _ = hotkeyManager.register()

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
        }
    }
}
