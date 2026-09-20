import Foundation

public final class ExclusionList {
    public static let defaultPasswordManagers: [String] = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.apple.keychainaccess",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
        "com.lastpass.LastPass",
        "com.dashlane.dashlanephonefinal"
    ]

    private let defaults: UserDefaults
    private let key = "excludedBundleIDs"
    private let seededKey = "didSeedDefaultExclusions"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        seedDefaultsIfNeeded()
    }

    public var bundleIDs: Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    public func contains(_ bundleID: String) -> Bool {
        bundleIDs.contains(bundleID)
    }

    public func add(_ bundleID: String) {
        var current = bundleIDs
        current.insert(bundleID)
        defaults.set(Array(current), forKey: key)
    }

    public func remove(_ bundleID: String) {
        var current = bundleIDs
        current.remove(bundleID)
        defaults.set(Array(current), forKey: key)
    }

    private func seedDefaultsIfNeeded() {
        guard !defaults.bool(forKey: seededKey) else { return }
        var current = bundleIDs
        for bundleID in Self.defaultPasswordManagers {
            current.insert(bundleID)
        }
        defaults.set(Array(current), forKey: key)
        defaults.set(true, forKey: seededKey)
    }
}
