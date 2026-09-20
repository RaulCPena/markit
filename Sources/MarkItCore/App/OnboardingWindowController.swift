import Cocoa
import SwiftUI

extension Notification.Name {
    static let markItAccessibilityTrusted = Notification.Name("MarkItAccessibilityTrusted")
}

final class OnboardingWindowController: NSObject {
    static let shared = OnboardingWindowController()
    private var window: NSWindow?
    private var pollTimer: Timer?

    private override init() {
        super.init()
    }

    func showIfNeeded() {
        if AccessibilityPermissionManager.isTrusted {
            dismiss()
            return
        }
        if window != nil {
            return
        }
        let view = OnboardingView {
            AccessibilityPermissionManager.openAccessibilitySettings()
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Welcome to MarkIt"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        NotificationCenter.default.addObserver(self, selector: #selector(windowClosed), name: NSWindow.willCloseNotification, object: window)
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        startPollingForTrust()
    }

    private func startPollingForTrust() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard AccessibilityPermissionManager.isTrusted else { return }
            self?.dismiss()
            NotificationCenter.default.post(name: .markItAccessibilityTrusted, object: nil)
        }
    }

    private func dismiss() {
        pollTimer?.invalidate()
        pollTimer = nil
        if let window = window {
            self.window = nil
            window.close()
        }
    }

    @objc private func windowClosed() {
        pollTimer?.invalidate()
        pollTimer = nil
        window = nil
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
    }
}
