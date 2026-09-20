import Foundation

enum SelectionGate {
    static let implicitlyExcludedBundleIDs: Set<String> = [
        "com.apple.dock",
        "com.apple.systemuiserver",
        "com.apple.WindowManager",
        "com.apple.finder"
    ]

    static func shouldCopy(
        enabled: Bool,
        frontmostBundleID: String?,
        exclusions: ExclusionList,
        ownBundleID: String
    ) -> Bool {
        guard enabled else { return false }
        guard let bundleID = frontmostBundleID else { return true }
        if bundleID == ownBundleID { return false }
        if implicitlyExcludedBundleIDs.contains(bundleID) { return false }
        if exclusions.contains(bundleID) { return false }
        return true
    }
}
