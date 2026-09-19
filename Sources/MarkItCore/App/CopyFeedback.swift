import Cocoa

enum CopyFeedback {
    static let soundName = "Tink"

    static func play() {
        NSSound(named: NSSound.Name(soundName))?.play()
    }
}
