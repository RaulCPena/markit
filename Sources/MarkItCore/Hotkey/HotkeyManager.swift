import Carbon
import Cocoa

public final class HotkeyManager {
    public var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private static var registry: [UInt32: HotkeyManager] = [:]
    private static var nextID: UInt32 = 1
    private var assignedID: UInt32 = 0

    public init() {}

    public func register(keyCode: UInt32 = UInt32(kVK_ANSI_V), modifiers: UInt32 = UInt32(cmdKey | shiftKey)) -> Bool {
        assignedID = Self.nextID
        Self.nextID += 1
        Self.registry[assignedID] = self

        let hotKeyID = EventHotKeyID(signature: OSType(0x4D4B4954), id: assignedID)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if let manager = HotkeyManager.registry[hkID.id] {
                DispatchQueue.main.async { manager.onTrigger?() }
            }
            return noErr
        }, 1, &eventType, nil, &eventHandler)

        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        return status == noErr
    }

    public func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        Self.registry[assignedID] = nil
    }
}
