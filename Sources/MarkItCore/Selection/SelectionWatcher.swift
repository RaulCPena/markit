import Cocoa
import ApplicationServices
import os.log

public final class SelectionWatcher {
    public var isEnabled = true
    let exclusions: ExclusionList
    let ownBundleID: String
    public var onCopy: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var mouseDidDrag = false
    private var pendingCopyWorkItem: DispatchWorkItem?
    // 60ms: collapses rapid repeated triggers (e.g. held Shift+Arrow) into a single copy.
    private let debounceInterval: TimeInterval = 0.06
    private var copyGeneration = 0

    public init(exclusions: ExclusionList, ownBundleID: String = Bundle.main.bundleIdentifier ?? "com.raulpena.markit") {
        self.exclusions = exclusions
        self.ownBundleID = ownBundleID
    }

    /// Starts the event tap only if one is not already running, so it can be re-armed
    /// after the user grants Accessibility permission without stacking duplicate taps.
    public func startIfNeeded() {
        guard eventTap == nil else { return }
        start()
    }

    public func start() {
        let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let watcher = Unmanaged<SelectionWatcher>.fromOpaque(refcon).takeUnretainedValue()
                watcher.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = tap else {
            // Expected on first launch: tap creation fails until Accessibility is granted.
            os_log("MarkIt: could not create the selection event tap (Accessibility permission not yet granted?)")
            return
        }
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .leftMouseDown:
            mouseDidDrag = false
        case .leftMouseDragged:
            mouseDidDrag = true
        case .leftMouseUp:
            if mouseDidDrag { scheduleCopy() }
            mouseDidDrag = false
        case .keyUp:
            let flags = event.flags
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let isArrow = (123...126).contains(keyCode) // 123-126 = Left/Right/Down/Up arrows.
            let isCmdA = flags.contains(.maskCommand) && keyCode == 0 // virtual key 0 = 'A'.
            if (flags.contains(.maskShift) && isArrow) || isCmdA {
                scheduleCopy()
            }
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
        default:
            break
        }
    }

    private func scheduleCopy() {
        pendingCopyWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.performCopyIfAllowed() }
        pendingCopyWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    private func performCopyIfAllowed() {
        let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard SelectionGate.shouldCopy(enabled: isEnabled, frontmostBundleID: frontmostBundleID, exclusions: exclusions, ownBundleID: ownBundleID) else { return }
        guard hasNonEmptySelection() else { return }
        copyGeneration += 1
        let generation = copyGeneration
        let changeCountBefore = NSPasteboard.general.changeCount
        simulateCommandC()
        // Poll for the pasteboard to catch up: 15 attempts x 20ms = ~300ms max wait.
        waitForPasteboardChange(from: changeCountBefore, attemptsRemaining: 15, generation: generation)
    }

    private func waitForPasteboardChange(from previousChangeCount: Int, attemptsRemaining: Int, generation: Int) {
        guard generation == copyGeneration else { return }
        if NSPasteboard.general.changeCount != previousChangeCount {
            onCopy?()
            return
        }
        guard attemptsRemaining > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            self?.waitForPasteboardChange(from: previousChangeCount, attemptsRemaining: attemptsRemaining - 1, generation: generation)
        }
    }

    private func hasNonEmptySelection() -> Bool {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        // Type-check before the cast: Swift can't conditionally downcast to a CF type, and an
        // unguarded `as!` here would trap the whole process on an unexpected AX return value.
        guard focusResult == .success, let focused = focusedElement,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else { return true }
        let element = focused as! AXUIElement
        var selectedText: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText)
        guard textResult == .success, let text = selectedText as? String else { return true }
        return !text.isEmpty
    }

    private func simulateCommandC() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        // Virtual key 0x08 = 'C'; paired with the Command flag this is ⌘C.
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
    }
}
