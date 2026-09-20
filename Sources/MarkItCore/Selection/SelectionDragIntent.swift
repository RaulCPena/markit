import CoreGraphics

/// Distinguishes a text selection from a click that jiggled a few pixels.
/// Double/triple-click still counts (word/paragraph select). Finder file
/// opens are blocked separately via `SelectionGate`'s implicit exclusions.
enum SelectionDragIntent {
    /// Clicks jitter a few points; a real text drag is longer than this.
    static let minimumDistance: CGFloat = 10

    static func distance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        hypot(end.x - start.x, end.y - start.y)
    }

    static func isTextDrag(distance: CGFloat, clickCount: Int, minimumDistance: CGFloat = minimumDistance) -> Bool {
        if clickCount >= 2 { return true }
        return distance >= minimumDistance
    }
}
