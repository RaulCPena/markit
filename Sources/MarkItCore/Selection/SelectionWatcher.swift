import Cocoa
import ApplicationServices

final class SelectionWatcher {
    /// Mirrors `AppSettings.isAutoCopyEnabled`.
    var isAutoCopyEnabled = true
    private let exclusions: ExclusionList
    private let ownBundleID: String
    var onCopy: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var dragStart: CGPoint?
    private var dragDistance: CGFloat = 0
    private var mouseClickCount = 1
    private var pendingCopyWorkItem: DispatchWorkItem?
    private var pendingAllowsCommandCFallback = false
    private var copyGeneration = 0

    init(exclusions: ExclusionList, ownBundleID: String = Bundle.main.bundleIdentifier ?? "com.raulpena.markit") {
        self.exclusions = exclusions
        self.ownBundleID = ownBundleID
    }

    /// Installs monitors/tap if missing, then re-arms after Accessibility is granted.
    func start() {
        installMonitorsIfNeeded()
        installTapIfNeeded()
        MarkItLog.line("start trusted=\(AccessibilityPermissionManager.isTrusted) tap=\(eventTap != nil) monitor=\(globalMonitor != nil) enabled=\(isAutoCopyEnabled)")
    }

    private func installMonitorsIfNeeded() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .keyDown, .keyUp]) { [weak self] event in
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
            | (1 << CGEventType.keyDown.rawValue)
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
            if event.modifierFlags.contains(.command) {
                resetDrag()
                return
            }
            finishDrag(clickCount: event.clickCount)
        case .keyDown:
            cancelPendingCopyIfPasteChord(keyCode: Int64(event.keyCode), commandDown: event.modifierFlags.contains(.command))
        case .keyUp:
            let flags = event.modifierFlags
            let keyCode = event.keyCode
            let isArrow = (123...126).contains(keyCode)
            let isCmdA = flags.contains(.command) && keyCode == 0
            if (flags.contains(.shift) && isArrow) || isCmdA {
                scheduleCopy(allowCommandCFallback: true)
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
            if event.flags.contains(.maskCommand) {
                resetDrag()
                return
            }
            finishDrag(clickCount: Int(event.getIntegerValueField(.mouseEventClickState)))
        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            cancelPendingCopyIfPasteChord(keyCode: keyCode, commandDown: event.flags.contains(.maskCommand))
        case .keyUp:
            let flags = event.flags
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let isArrow = (123...126).contains(keyCode) // 123-126 = Left/Right/Down/Up arrows.
            let isCmdA = flags.contains(.maskCommand) && keyCode == 0 // virtual key 0 = 'A'.
            if (flags.contains(.maskShift) && isArrow) || isCmdA {
                scheduleCopy(allowCommandCFallback: true)
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
            scheduleCopy(allowCommandCFallback: false)
        } else {
            MarkItLog.line("skip click clicks=\(clicks) dist=\(Int(dragDistance))")
        }
        resetDrag()
    }

    private func resetDrag() {
        dragStart = nil
        dragDistance = 0
        mouseClickCount = 1
    }

    private func cancelPendingCopyIfPasteChord(keyCode: Int64, commandDown: Bool) {
        guard CopyCommitPolicy.shouldCancelPendingCopy(keyCode: keyCode, commandDown: commandDown) else { return }
        pendingCopyWorkItem?.cancel()
        pendingCopyWorkItem = nil
        copyGeneration += 1
        MarkItLog.line("cancel pending copy for ⌘ chord \(keyCode)")
    }

    private func scheduleCopy(allowCommandCFallback: Bool) {
        pendingAllowsCommandCFallback = allowCommandCFallback
        MarkItLog.line("selection gesture fallback=\(allowCommandCFallback)")
        pendingCopyWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.performCopyIfAllowed() }
        pendingCopyWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + CopyCommitPolicy.pasteGraceInterval, execute: workItem)
    }

    private func performCopyIfAllowed() {
        guard AccessibilityPermissionManager.isTrusted else {
            MarkItLog.line("skip copy: process is not trusted")
            return
        }
        let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let gateAllows = SelectionGate.shouldCopy(
            enabled: isAutoCopyEnabled,
            frontmostBundleID: frontmostBundleID,
            exclusions: exclusions,
            ownBundleID: ownBundleID
        )
        switch CopyPlanner.action(
            gateAllows: gateAllows,
            axSelectedText: axSelectedText(),
            pasteboardString: NSPasteboard.general.string(forType: .string),
            allowCommandCFallback: pendingAllowsCommandCFallback
        ) {
        case .none:
            MarkItLog.line("skipped copy enabled=\(isAutoCopyEnabled) frontmost=\(frontmostBundleID ?? "nil")")
        case .writeToPasteboard(let text):
            MarkItLog.line("write \(text.count) chars from AX")
            PasteboardActions.putText(text)
            onCopy?()
        case .simulateCommandC:
            MarkItLog.line("fallback ⌘C frontmost=\(frontmostBundleID ?? "nil")")
            copyGeneration += 1
            let generation = copyGeneration
            let changeCountBefore = NSPasteboard.general.changeCount
            PasteboardActions.copyToFrontmostApp()
            // Poll for the pasteboard to catch up: 25 attempts x 20ms = ~500ms max wait.
            waitForPasteboardChange(from: changeCountBefore, attemptsRemaining: 25, generation: generation)
        }
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

    /// `nil` means AX didn't expose a string (mouse path skips; keyboard may ⌘C).
    private func axSelectedText() -> String? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard focusResult == .success, let focused = focusedElement,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = unsafeBitCast(focused, to: AXUIElement.self)
        var selectedText: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText)
        guard textResult == .success else { return nil }
        return selectedText as? String
    }
}
