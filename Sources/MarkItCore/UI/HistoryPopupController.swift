import Cocoa
import SwiftUI

public final class HistoryPopupController {
    let store: ClipboardHistoryStore
    private var panel: NSPanel?

    public init(store: ClipboardHistoryStore) {
        self.store = store
    }

    public func toggle() {
        if panel != nil { close() } else { show() }
    }

    public func show() {
        let view = HistoryPopupView(items: store.items) { [weak self] item in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.text, forType: .string)
            self?.close()
        }
        let hosting = NSHostingController(rootView: view)
        let panel = NSPanel(contentViewController: hosting)
        panel.styleMask = [.nonactivatingPanel, .titled, .closable]
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        let mouseLocation = NSEvent.mouseLocation
        panel.setFrameOrigin(NSPoint(x: mouseLocation.x, y: mouseLocation.y - 200))
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
        NotificationCenter.default.removeObserver(self)
    }
}
