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

    /// Opens System Settings to Accessibility. Does not use `kAXTrustedCheckOptionPrompt`
    /// — that lock dialog can appear even when a stale MarkIt row is already On, and it
    /// never binds this process. The user must remove/re-add the correct binary.
    static func openAccessibilitySettings() {
        for string in settingsURLStrings {
            guard let url = URL(string: string) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
    }
}
