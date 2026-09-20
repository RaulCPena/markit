import Foundation

enum CopyAction: Equatable {
    case none
    case writeToPasteboard(String)
    case simulateCommandC
}

enum CopyPlanner {
    /// Mouse gestures only copy when Accessibility exposes selected text.
    /// ⌘C-on-empty-AX copies Finder files, leftover highlights, and the
    /// destination of a paste-over. Keyboard extend-selection can still fall back.
    static func action(
        gateAllows: Bool,
        axSelectedText: String?,
        pasteboardString: String?,
        allowCommandCFallback: Bool
    ) -> CopyAction {
        guard gateAllows else { return .none }
        if let axSelectedText, !axSelectedText.isEmpty {
            if axSelectedText == pasteboardString { return .none }
            return .writeToPasteboard(axSelectedText)
        }
        if allowCommandCFallback { return .simulateCommandC }
        return .none
    }
}
