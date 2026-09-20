import Cocoa
import SwiftUI

final class CopyToastController {
    static let shared = CopyToastController()
    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    private init() {}

    func show(text: String) {
        hideWorkItem?.cancel()
        panel?.close()

        let preview = CopyToastCopy.preview(from: text)
        let hosting = NSHostingController(rootView: CopyToastView(preview: preview))
        hosting.view.frame = NSRect(x: 0, y: 0, width: 280, height: 64)
        let panel = NSPanel(contentRect: hosting.view.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        position(panel)
        panel.orderFrontRegardless()
        self.panel = panel

        let hide = DispatchWorkItem { [weak self] in
            self?.panel?.close()
            self?.panel = nil
        }
        hideWorkItem = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: hide)
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.minY + 72
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
