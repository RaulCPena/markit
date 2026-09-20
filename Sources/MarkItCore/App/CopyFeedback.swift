import Cocoa

enum CopyFeedback {
    static let soundName = "copy-whoosh"
    static let fallbackPath = "/System/Library/Sounds/Blow.aiff"

    static func play(settings: AppSettings = AppSettings()) {
        guard settings.isCopySoundEnabled else { return }
        if let url = Bundle.main.url(forResource: soundName, withExtension: "aiff"),
           let sound = NSSound(contentsOf: url, byReference: true) {
            sound.play()
            return
        }
        NSSound(contentsOfFile: fallbackPath, byReference: true)?.play()
    }
}
