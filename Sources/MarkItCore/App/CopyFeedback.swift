import Cocoa

enum CopyFeedback {
    static let soundName = "copy-whoosh"
    static let fallbackPath = "/System/Library/Sounds/Blow.aiff"
    /// Keep the whoosh in the room, not in your ear.
    static let playbackVolume: Float = 0.42
    private static var currentSound: NSSound?

    static func play(settings: AppSettings = AppSettings()) {
        guard settings.isCopySoundEnabled else { return }
        if let url = Bundle.main.url(forResource: soundName, withExtension: "aiff"),
           let sound = NSSound(contentsOf: url, byReference: true) {
            currentSound = sound
            sound.volume = playbackVolume
            sound.play()
            return
        }
        let fallback = NSSound(contentsOfFile: fallbackPath, byReference: true)
        currentSound = fallback
        fallback?.volume = playbackVolume
        fallback?.play()
    }
}
