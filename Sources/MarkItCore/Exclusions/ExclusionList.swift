import Foundation

final class ExclusionList {
    static let defaultPasswordManagers: [String] = [
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        seedDefaultsIfNeeded()
    }

    var bundleIDs: Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    func contains(_ bundleID: String) -> Bool {
        bundleIDs.contains(bundleID)
    }

    func add(_ bundleID: String) {
        var current = bundleIDs
        current.insert(bundleID)
        defaults.set(Array(current), forKey: key)
    }

    func remove(_ bundleID: String) {
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
