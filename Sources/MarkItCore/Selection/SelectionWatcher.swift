import Cocoa
import ApplicationServices

public final class SelectionWatcher {
    public var isEnabled = true
    let exclusions: ExclusionList
    let ownBundleID: String
    public var onCopy: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var mouseDidDrag = false
    private var pendingCopyWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.06

    public init(exclusions: ExclusionList, ownBundleID: String = Bundle.main.bundleIdentifier ?? "com.raulpena.markit") {
        self.exclusions = exclusions
        self.ownBundleID = ownBundleID
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
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let watcher = Unmanaged<SelectionWatcher>.fromOpaque(refcon).takeUnretainedValue()
                watcher.handle(type: type, event: event)
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = tap else { return }
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
            let isArrow = (123...126).contains(keyCode)
            let isCmdA = flags.contains(.maskCommand) && keyCode == 0
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
        simulateCommandC()
        onCopy?()
    }

    private func hasNonEmptySelection() -> Bool {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard focusResult == .success, let element = focusedElement else { return true }
        var selectedText: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText)
        guard textResult == .success, let text = selectedText as? String else { return true }
        return !text.isEmpty
    }

    private func simulateCommandC() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
    }
}
