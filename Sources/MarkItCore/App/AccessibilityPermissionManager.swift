import ApplicationServices
import Cocoa

enum AccessibilityPermissionManager {
    /// Ventura+ Privacy & Security extension first; legacy Security pane as fallback.
    static let settingsURLStrings = [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    ]

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestPermission() {
        // Do not use kAXTrustedCheckOptionPrompt. That lock dialog appears even
        // when a stale MarkIt row is already On in Settings, and it never binds
        // this process. Send the user to the list so they can remove/re-add.
        openAccessibilitySettings()
    }

    static func openAccessibilitySettings() {
        for string in settingsURLStrings {
            guard let url = URL(string: string) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
    }
}
