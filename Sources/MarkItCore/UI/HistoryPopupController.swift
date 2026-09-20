import Cocoa
import SwiftUI

public final class HistoryPopupController: NSObject {
    let store: ClipboardHistoryStore
    private var panel: NSPanel?
    private var model: HistoryPopupModel?

    public init(store: ClipboardHistoryStore) {
        self.store = store
        super.init()
    }

    public func toggle() {
        if panel != nil { close() } else { show() }
    }

    public func show() {
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

    public func close() {
        panel?.close()
        panel = nil
        model = nil
        NotificationCenter.default.removeObserver(self)
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
