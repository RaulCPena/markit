import Foundation

enum CopyCommitPolicy {
    /// Wait long enough that ⌘V to paste-over can cancel the copy first.
    static let pasteGraceInterval: TimeInterval = 0.45

    static func shouldCancelPendingCopy(keyCode: Int64, commandDown: Bool) -> Bool {
        guard commandDown else { return false }
        // 7 = X, 9 = V. Not C: our own simulated ⌘C would cancel itself.
        return keyCode == 7 || keyCode == 9
    }
}
