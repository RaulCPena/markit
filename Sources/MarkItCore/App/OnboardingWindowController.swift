import Cocoa
import SwiftUI

final class OnboardingWindowController {
    static let shared = OnboardingWindowController()
    private var window: NSWindow?

    func showIfNeeded() {
        guard !AccessibilityPermissionManager.isTrusted else {
            window?.close()
            window = nil
            return
        }
        guard window == nil else { return }
        let view = OnboardingView {
            AccessibilityPermissionManager.requestPermission()
            AccessibilityPermissionManager.openAccessibilitySettings()
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Welcome to MarkIt"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        // Clear the reference on a user-initiated close too, otherwise `showIfNeeded()` would
        // no-op forever for a still-untrusted user who dismissed the window manually.
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
