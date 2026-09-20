import Cocoa

enum CopyFeedback {
    static let fallbackPath = "/System/Library/Sounds/Blow.aiff"
    private static var currentSound: NSSound?

    static func play(settings: AppSettings = AppSettings()) {
        guard settings.isCopySoundEnabled else { return }
        let name = settings.copySoundName
        if let sound = NSSound(named: name) {
            currentSound = sound
            sound.volume = 0.5
            sound.play()
            return
        }
        let fallback = NSSound(contentsOfFile: fallbackPath, byReference: true)
        currentSound = fallback
        fallback?.volume = 0.5
        fallback?.play()
    }
}