import Cocoa
import SwiftUI

final class HistoryPopupController: NSObject {
    private let store: ClipboardHistoryStore
    private var panel: NSPanel?
    private var model: HistoryPopupModel?

    init(store: ClipboardHistoryStore) {
        self.store = store
        super.init()
    }

    func toggle() {
        if panel != nil { close() } else { show() }
    }

    func show() {
        if panel != nil { close() }

        let model = HistoryPopupModel(store: store)
        self.model = model
        let view = HistoryPopupView(
            model: model,
            onPaste: { [weak self] item in
                self?.paste(item)
            },
            onPin: { [weak self] item in
                self?.store.togglePin(id: item.id)
                self?.model?.reload()
            }
        )
        let hosting = NSHostingController(rootView: view)
        let panel = NSPanel(contentViewController: hosting)
        panel.styleMask = [.nonactivatingPanel, .titled, .closable, .resizable]
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.setContentSize(NSSize(width: 380, height: 420))

        let mouseLocation = NSEvent.mouseLocation
        panel.setFrameOrigin(NSPoint(x: mouseLocation.x, y: mouseLocation.y - 240))
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        NotificationCenter.default.addObserver(self, selector: #selector(panelResigned), name: NSWindow.didResignKeyNotification, object: panel)
    }

    @objc private func panelResigned() {
        close()
    }

    func close() {
        panel?.close()
        panel = nil
        model = nil
        NotificationCenter.default.removeObserver(self)
    }

    func clearHistory() {
        store.clear()
    }

    private func paste(_ item: ClipboardItem) {
        PasteboardActions.putText(item.text)
        close()
        CopyFeedback.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            PasteboardActions.pasteToFrontmostApp()
        }
    }
}
