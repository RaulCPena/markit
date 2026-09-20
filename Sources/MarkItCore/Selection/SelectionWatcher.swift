import Cocoa
import ApplicationServices

public final class SelectionWatcher {
    public var isEnabled = true
    let exclusions: ExclusionList
    let ownBundleID: String
    public var onCopy: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var dragStart: CGPoint?
    private var dragDistance: CGFloat = 0
    private var mouseClickCount = 1
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
        start()
    }

    public func start() {
        installMonitorsIfNeeded()
        installTapIfNeeded()
        MarkItLog.line("start trusted=\(AccessibilityPermissionManager.isTrusted) tap=\(eventTap != nil) monitor=\(globalMonitor != nil) enabled=\(isEnabled)")
    }

    private func installMonitorsIfNeeded() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .keyUp]) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleNSEvent(event)
            }
        }
        if globalMonitor == nil {
            MarkItLog.line("NSEvent global monitor was not installed")
        }
    }

    private func installTapIfNeeded() {
        guard eventTap == nil else { return }
        let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let watcher = Unmanaged<SelectionWatcher>.fromOpaque(refcon).takeUnretainedValue()
            watcher.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        // HID first: session listen-only taps often never see other-apps' mouse drags.
        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: userInfo
        ) ?? CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: userInfo
        )

        guard let tap = tap else {
            MarkItLog.line("could not create CGEventTap")
            return
        }
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        MarkItLog.line("CGEventTap is running")
    }

    private func handleNSEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            beginDrag(clickCount: event.clickCount)
        case .leftMouseDragged:
            updateDrag()
        case .leftMouseUp:
            finishDrag(clickCount: event.clickCount)
        case .keyUp:
            let flags = event.modifierFlags
            let keyCode = event.keyCode
            let isArrow = (123...126).contains(keyCode)
            let isCmdA = flags.contains(.command) && keyCode == 0
            if (flags.contains(.shift) && isArrow) || isCmdA {
                scheduleCopy()
            }
        default:
            break
        }
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .leftMouseDown:
            if globalMonitor != nil { return }
            beginDrag(clickCount: Int(event.getIntegerValueField(.mouseEventClickState)))
        case .leftMouseDragged:
            if globalMonitor != nil { return }
            updateDrag()
        case .leftMouseUp:
            if globalMonitor != nil { return }
            finishDrag(clickCount: Int(event.getIntegerValueField(.mouseEventClickState)))
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

    private func beginDrag(clickCount: Int) {
        dragStart = NSEvent.mouseLocation
        dragDistance = 0
        mouseClickCount = max(clickCount, 1)
    }

    private func updateDrag() {
        guard let start = dragStart else { return }
        dragDistance = max(dragDistance, SelectionDragIntent.distance(from: start, to: NSEvent.mouseLocation))
    }

    private func finishDrag(clickCount: Int) {
        updateDrag()
        let clicks = max(mouseClickCount, max(clickCount, 1))
        if SelectionDragIntent.isTextDrag(distance: dragDistance, clickCount: clicks) {
            scheduleCopy()
        } else {
            MarkItLog.line("skip click clicks=\(clicks) dist=\(Int(dragDistance))")
        }
        dragStart = nil
        dragDistance = 0
        mouseClickCount = 1
    }

    private func scheduleCopy() {
        MarkItLog.line("selection gesture")
        pendingCopyWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.performCopyIfAllowed() }
        pendingCopyWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    private func performCopyIfAllowed() {
        guard AccessibilityPermissionManager.isTrusted else {
            MarkItLog.line("skip copy: process is not trusted")
            return
        }
        let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let gateAllows = SelectionGate.shouldCopy(
            enabled: isEnabled,
            frontmostBundleID: frontmostBundleID,
            exclusions: exclusions,
            ownBundleID: ownBundleID
        )
        switch CopyPlanner.action(gateAllows: gateAllows, axSelectedText: axSelectedText()) {
        case .none:
            MarkItLog.line("skipped copy enabled=\(isEnabled) frontmost=\(frontmostBundleID ?? "nil")")
        case .writeToPasteboard(let text):
            MarkItLog.line("write \(text.count) chars from AX")
            writeToPasteboard(text)
            onCopy?()
        case .simulateCommandC:
            MarkItLog.line("fallback ⌘C frontmost=\(frontmostBundleID ?? "nil")")
            copyGeneration += 1
            let generation = copyGeneration
            let changeCountBefore = NSPasteboard.general.changeCount
            simulateCommandC()
            // Poll for the pasteboard to catch up: 25 attempts x 20ms = ~500ms max wait.
            waitForPasteboardChange(from: changeCountBefore, attemptsRemaining: 25, generation: generation)
        }
    }

    private func writeToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func waitForPasteboardChange(from previousChangeCount: Int, attemptsRemaining: Int, generation: Int) {
        guard generation == copyGeneration else { return }
        if NSPasteboard.general.changeCount != previousChangeCount {
            onCopy?()
            return
        }
        guard attemptsRemaining > 0 else {
            MarkItLog.line("simulated ⌘C did not change the pasteboard")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            self?.waitForPasteboardChange(from: previousChangeCount, attemptsRemaining: attemptsRemaining - 1, generation: generation)
        }
    }

    /// `nil` means AX didn't expose a string (caller falls back to ⌘C).
    private func axSelectedText() -> String? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard focusResult == .success, let focused = focusedElement,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        var selectedText: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText)
        guard textResult == .success else { return nil }
        return selectedText as? String
    }

    private func simulateCommandC() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        source.localEventsSuppressionInterval = 0
        // 0x37 = Command, 0x08 = C. Post a full key chord at the HID tap so the
        // frontmost app sees it as a real copy, not a flag-only C key.
        let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        let tap = CGEventTapLocation.cghidEventTap
        commandDown?.post(tap: tap)
        keyDown?.post(tap: tap)
        keyUp?.post(tap: tap)
        commandUp?.post(tap: tap)
    }
}
