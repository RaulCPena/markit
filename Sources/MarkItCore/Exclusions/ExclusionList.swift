import Foundation

public final class ExclusionList {
    private let defaults: UserDefaults
    private let key = "excludedBundleIDs"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
}
