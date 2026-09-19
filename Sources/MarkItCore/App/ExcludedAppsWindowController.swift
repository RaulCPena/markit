import Cocoa
import SwiftUI

final class ExcludedAppsWindowController {
    static let shared = ExcludedAppsWindowController()
    private var window: NSWindow?

    func show(exclusions: ExclusionList) {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let model = ExcludedAppsModel(exclusions: exclusions)
        let hosting = NSHostingController(rootView: ExcludedAppsView(model: model))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Excluded Apps"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        NotificationCenter.default.addObserver(self, selector: #selector(windowClosed), name: NSWindow.willCloseNotification, object: window)
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func windowClosed() {
        window = nil
        NotificationCenter.default.removeObserver(self)
    }
}
