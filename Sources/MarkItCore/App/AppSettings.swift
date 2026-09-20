import Foundation

final class AppSettings {
    private let defaults: UserDefaults
    private let autoCopyKey = "isAutoCopyEnabled"
    private let soundKey = "isCopySoundEnabled"
    private let soundNameKey = "copySoundName"

    static let systemSoundNames = ["Purr", "Pop", "Blow", "Tink", "Glass", "Funk"]

    init(defaults: UserDefaults = .standard) {
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
        get { defaults.bool(forKey: soundKey) }
        set { defaults.set(newValue, forKey: soundKey) }
    }

    var copySoundName: String {
        get {
            let name = defaults.string(forKey: soundNameKey) ?? "Purr"
            return Self.systemSoundNames.contains(name) ? name : "Purr"
        }
        set { defaults.set(newValue, forKey: soundNameKey) }
    }
}
