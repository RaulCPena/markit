import Cocoa
import SwiftUI

final class OnboardingWindowController {
    static let shared = OnboardingWindowController()
    private var window: NSWindow?

    func showIfNeeded() {
        guard !AccessibilityPermissionManager.isTrusted else {
            window?.close()
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
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
