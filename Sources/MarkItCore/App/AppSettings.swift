import Foundation

public final class AppSettings {
    private let defaults: UserDefaults
    private let autoCopyKey = "isAutoCopyEnabled"
    private let soundKey = "isCopySoundEnabled"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isAutoCopyEnabled: Bool {
        get {
            if defaults.object(forKey: autoCopyKey) == nil { return true }
            return defaults.bool(forKey: autoCopyKey)
        }
        set { defaults.set(newValue, forKey: autoCopyKey) }
    }

    var isCopySoundEnabled: Bool {
        get {
            if defaults.object(forKey: soundKey) == nil { return true }
            return defaults.bool(forKey: soundKey)
        }
        set { defaults.set(newValue, forKey: soundKey) }
    }
}
