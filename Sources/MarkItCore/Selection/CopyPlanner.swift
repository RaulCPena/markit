import Foundation

enum CopyAction: Equatable {
    case none
    case writeToPasteboard(String)
    case simulateCommandC
}

enum CopyPlanner {
    /// Prefer writing AX selected text (synthetic ⌘C is often ignored).
    /// Empty/missing AX text falls back to ⌘C per the design spec.
    static func action(gateAllows: Bool, axSelectedText: String?) -> CopyAction {
        guard gateAllows else { return .none }
        if let axSelectedText, !axSelectedText.isEmpty {
            return .writeToPasteboard(axSelectedText)
        }
        return .simulateCommandC
    }
}
