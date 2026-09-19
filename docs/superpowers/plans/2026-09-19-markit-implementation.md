# MarkIt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build MarkIt, a macOS menu bar app that copies selected text to the clipboard automatically (no ⌘C needed) so it can be pasted anywhere via right-click, plus a small clipboard history and per-app exclusions.

**Architecture:** Native Swift + AppKit/SwiftUI menu bar app (agent/accessory app, no Dock icon, no App Sandbox), built as a Swift Package (no Xcode GUI project — see Ruling below) and packaged into a real `.app` bundle by a shell script for running/testing/distribution. A `CGEventTap`-based `SelectionWatcher` detects selection gestures and simulates ⌘C; a `ClipboardHistoryStore` and `ExclusionList` are pure, unit-testable models; a `StatusBarController` wires everything into an `NSStatusItem` menu.

**Tech Stack:** Swift Package Manager, AppKit, SwiftUI, Carbon (global hotkey), ApplicationServices (Accessibility API), ServiceManagement (login item), XCTest. No third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-09-19-markit-design.md`

**Ruling (pre-flight, recorded before Task 1 dispatch):** The spec's "Repo layout" section and this plan's original Task 1/9 assumed creating `MarkIt.xcodeproj` via Xcode's New Project GUI wizard. That's not executable by an autonomous subagent (no GUI automation available). Restructured as a Swift Package instead — `swift build`/`swift test` replace all `xcodebuild` commands, and a `.app` bundle is assembled by a script (`scripts/build-debug-app.sh` for development, `scripts/release.sh` for signed/notarized releases) rather than via `xcodebuild archive`/`-exportArchive`. This changes build tooling only; every runtime component, behavior, and requirement from the spec is unchanged. Cost if wrong: Raul prefers a real `.xcodeproj` for day-to-day Xcode editing — recoverable later by running `swift package generate-xcodeproj`-equivalent (opening `Package.swift` directly in Xcode also works natively without any conversion, since Xcode opens Swift Packages directly).

## Global Constraints

- Minimum macOS version: 13.0 (Ventura) — required for `SMAppService`.
- No App Sandbox — `CGEventTap` and cross-process `AXUIElement` reads are incompatible with it. MarkIt is not Mac-App-Store-distributable; it ships as a direct Developer-ID-signed download.
- Text-only clipboard content in v1 — no images, files, or RTF.
- Global hotkey is fixed at ⌘⇧V in v1 — not user-remappable.
- Clipboard history: capped at 50 items, deduped against the most recent 10.
- Exclude list starts empty by default, persisted via `UserDefaults`.
- No third-party dependencies (no CocoaPods/SPM packages) — Carbon's hotkey API is used directly.
- No auto-update mechanism in v1.
- Bundle identifier: `com.raulpena.markit`.
- Package structure: a `MarkItCore` library target holds all logic/UI; a thin `MarkIt` executable target holds only `main.swift`, so `MarkItCore` stays `@testable`-importable (an executable target with top-level code in `main.swift` cannot itself be `@testable`-imported).
- Plain conventional commit messages. No AI attribution of any kind, in any commit, including subagent commits.
- Never push to a remote or open a PR without Raul's explicit, same-turn approval.
- **Manual UI verification** (drag-selecting text, clicking menu items, granting/revoking Accessibility permission, pressing the hotkey) requires a live, interactive GUI session and must be performed by Raul. An executing (sub)agent implements the code and runs every automated check it can (`swift build`, `swift test`), then explicitly hands off the manual checklist items rather than claiming them done.
- **Accessibility permission during development:** macOS ties Accessibility grants to the on-disk app bundle. Grant permission once to `.build/debug-app/MarkIt.app` (System Settings → Privacy & Security → Accessibility); if it silently stops working after a clean rebuild, re-add it there.
- **Login item testing caveat:** `SMAppService.mainApp` is most reliable for an app installed in `/Applications`. Testing "Launch at Login" against the raw debug build in the repo may behave inconsistently — treat the release build as the authoritative test for that feature.

---

### Task 1: Swift Package scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/MarkIt/main.swift`
- Create: `Sources/MarkItCore/App/AppDelegate.swift`
- Create: `Resources/Info.plist`
- Create: `scripts/build-debug-app.sh`

**Interfaces:**
- Consumes: nothing (first task)
- Produces: a buildable, runnable menu-bar-only app shell that later tasks extend. `public final class AppDelegate: NSObject, NSApplicationDelegate` (in `MarkItCore`), instantiated by `Sources/MarkIt/main.swift`.

- [ ] **Step 1: Create the package manifest**

Create `Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MarkIt",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "MarkItCore",
            path: "Sources/MarkItCore"
        ),
        .executableTarget(
            name: "MarkIt",
            dependencies: ["MarkItCore"],
            path: "Sources/MarkIt"
        ),
        .testTarget(
            name: "MarkItCoreTests",
            dependencies: ["MarkItCore"],
            path: "Tests/MarkItCoreTests"
        )
    ]
)
```

- [ ] **Step 2: Implement the menu-bar skeleton in `MarkItCore`**

Create `Sources/MarkItCore/App/AppDelegate.swift`:

```swift
import Cocoa

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "MarkIt")
        statusItem.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
}
```

- [ ] **Step 3: Implement the executable entry point**

Create `Sources/MarkIt/main.swift`:

```swift
import Cocoa
import MarkItCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

`setActivationPolicy(.accessory)` is the code-level guarantee of menu-bar-only behavior (no Dock icon); `Resources/Info.plist`'s `LSUIElement` (Step 4) is the bundle-level counterpart used once packaged.

- [ ] **Step 4: Create the Info.plist template used for packaging**

Create `Resources/Info.plist` (not an SPM resource — copied into the `.app` bundle by the build scripts in Steps 5 and Task 9):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MarkIt</string>
    <key>CFBundleIdentifier</key>
    <string>com.raulpena.markit</string>
    <key>CFBundleName</key>
    <string>MarkIt</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Raul Pena.</string>
</dict>
</plist>
```

- [ ] **Step 5: Write the debug packaging script**

Create `scripts/build-debug-app.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

swift build

APP_DIR=".build/debug-app/MarkIt.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp .build/debug/MarkIt "$APP_DIR/Contents/MacOS/MarkIt"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"

echo "Built: $APP_DIR (run: open $APP_DIR)"
```

```bash
chmod +x scripts/build-debug-app.sh
```

- [ ] **Step 6: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 7: Manual verification (Raul)**

Run: `./scripts/build-debug-app.sh && open .build/debug-app/MarkIt.app`
Confirm a clipboard icon appears in the menu bar (no Dock icon), and clicking it → Quit terminates the app.

- [ ] **Step 8: Commit**

```bash
git checkout -b feat/markit-app
git add Package.swift Sources/MarkIt/main.swift Sources/MarkItCore/App/AppDelegate.swift Resources/Info.plist scripts/build-debug-app.sh
git commit -m "feat: scaffold menu bar app as a Swift package"
```

---

### Task 2: Clipboard history store (TDD)

**Files:**
- Create: `Sources/MarkItCore/Clipboard/ClipboardItem.swift`
- Create: `Sources/MarkItCore/Clipboard/ClipboardHistoryStore.swift`
- Test: `Tests/MarkItCoreTests/ClipboardHistoryStoreTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces: `public struct ClipboardItem { id: UUID, text: String, timestamp: Date }`; `public final class ClipboardHistoryStore(maxItems: Int = 50, dedupeWindow: Int = 10, fileURL: URL)` with `.items: [ClipboardItem]` (newest first), `.add(text: String)`, `.load()`, `.save()`, and static `ClipboardHistoryStore.defaultFileURL() -> URL`. Used by `SelectionWatcher` (Task 4) and `HistoryPopupController` (Task 5).

- [ ] **Step 1: Write the failing tests**

Create `Tests/MarkItCoreTests/ClipboardHistoryStoreTests.swift`:

```swift
import XCTest
@testable import MarkItCore

final class ClipboardHistoryStoreTests: XCTestCase {
    var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func test_add_appendsNewItemAtFront() {
        let store = ClipboardHistoryStore(fileURL: tempURL)
        store.add(text: "hello")
        store.add(text: "world")
        XCTAssertEqual(store.items.map { $0.text }, ["world", "hello"])
    }

    func test_add_skipsDuplicateWithinDedupeWindow() {
        let store = ClipboardHistoryStore(dedupeWindow: 10, fileURL: tempURL)
        store.add(text: "hello")
        store.add(text: "hello")
        XCTAssertEqual(store.items.count, 1)
    }

    func test_add_capsAtMaxItems() {
        let store = ClipboardHistoryStore(maxItems: 3, dedupeWindow: 0, fileURL: tempURL)
        store.add(text: "a")
        store.add(text: "b")
        store.add(text: "c")
        store.add(text: "d")
        XCTAssertEqual(store.items.map { $0.text }, ["d", "c", "b"])
    }

    func test_persistAndReload_roundTrips() {
        let store1 = ClipboardHistoryStore(fileURL: tempURL)
        store1.add(text: "persisted")

        let store2 = ClipboardHistoryStore(fileURL: tempURL)
        XCTAssertEqual(store2.items.map { $0.text }, ["persisted"])
    }

    func test_load_corruptFile_startsEmpty() {
        try? "not valid json".data(using: .utf8)!.write(to: tempURL)
        let store = ClipboardHistoryStore(fileURL: tempURL)
        XCTAssertEqual(store.items.count, 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ClipboardHistoryStoreTests`
Expected: FAIL — `ClipboardItem`/`ClipboardHistoryStore` not found.

- [ ] **Step 3: Implement**

Create `Sources/MarkItCore/Clipboard/ClipboardItem.swift`:

```swift
import Foundation

public struct ClipboardItem: Codable, Equatable, Identifiable {
    public let id: UUID
    public let text: String
    public let timestamp: Date
}
```

Create `Sources/MarkItCore/Clipboard/ClipboardHistoryStore.swift`:

```swift
import Foundation

public final class ClipboardHistoryStore {
    public private(set) var items: [ClipboardItem] = []
    private let maxItems: Int
    private let dedupeWindow: Int
    private let fileURL: URL

    public init(maxItems: Int = 50, dedupeWindow: Int = 10, fileURL: URL) {
        self.maxItems = maxItems
        self.dedupeWindow = dedupeWindow
        self.fileURL = fileURL
        load()
    }

    public func add(text: String) {
        guard !text.isEmpty else { return }
        let recent = items.prefix(dedupeWindow)
        if recent.contains(where: { $0.text == text }) { return }
        items.insert(ClipboardItem(id: UUID(), text: text, timestamp: Date()), at: 0)
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
        save()
    }

    public func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    public func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

extension ClipboardHistoryStore {
    public static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("MarkIt", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ClipboardHistoryStoreTests`
Expected: all 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MarkItCore/Clipboard Tests/MarkItCoreTests/ClipboardHistoryStoreTests.swift
git commit -m "feat: add clipboard history store"
```

---

### Task 3: Exclusion list (TDD)

**Files:**
- Create: `Sources/MarkItCore/Exclusions/ExclusionList.swift`
- Test: `Tests/MarkItCoreTests/ExclusionListTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces: `public final class ExclusionList(defaults: UserDefaults = .standard)` with `.bundleIDs: Set<String>`, `.contains(_ bundleID: String) -> Bool`, `.add(_ bundleID: String)`, `.remove(_ bundleID: String)`. Used by `SelectionGate`/`SelectionWatcher` (Task 4) and `ExcludedAppsModel` (Task 7).

- [ ] **Step 1: Write the failing tests**

Create `Tests/MarkItCoreTests/ExclusionListTests.swift`:

```swift
import XCTest
@testable import MarkItCore

final class ExclusionListTests: XCTestCase {
    var defaults: UserDefaults!
    let suiteName = "com.raulpena.markit.tests.exclusionlist"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_add_thenContains_isTrue() {
        let list = ExclusionList(defaults: defaults)
        list.add("com.apple.Terminal")
        XCTAssertTrue(list.contains("com.apple.Terminal"))
    }

    func test_remove_thenContains_isFalse() {
        let list = ExclusionList(defaults: defaults)
        list.add("com.apple.Terminal")
        list.remove("com.apple.Terminal")
        XCTAssertFalse(list.contains("com.apple.Terminal"))
    }

    func test_contains_unknownBundleID_isFalse() {
        let list = ExclusionList(defaults: defaults)
        XCTAssertFalse(list.contains("com.unknown.app"))
    }

    func test_persistsAcrossInstances() {
        let list1 = ExclusionList(defaults: defaults)
        list1.add("com.apple.Terminal")

        let list2 = ExclusionList(defaults: defaults)
        XCTAssertTrue(list2.contains("com.apple.Terminal"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ExclusionListTests`
Expected: FAIL — `ExclusionList` not found.

- [ ] **Step 3: Implement**

Create `Sources/MarkItCore/Exclusions/ExclusionList.swift`:

```swift
import Foundation

public final class ExclusionList {
    private let defaults: UserDefaults
    private let key = "excludedBundleIDs"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var bundleIDs: Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    public func contains(_ bundleID: String) -> Bool {
        bundleIDs.contains(bundleID)
    }

    public func add(_ bundleID: String) {
        var current = bundleIDs
        current.insert(bundleID)
        defaults.set(Array(current), forKey: key)
    }

    public func remove(_ bundleID: String) {
        var current = bundleIDs
        current.remove(bundleID)
        defaults.set(Array(current), forKey: key)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ExclusionListTests`
Expected: all 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MarkItCore/Exclusions Tests/MarkItCoreTests/ExclusionListTests.swift
git commit -m "feat: add per-app exclusion list"
```

---

### Task 4: Selection detection

**Files:**
- Create: `Sources/MarkItCore/Selection/SelectionGate.swift`
- Create: `Sources/MarkItCore/Selection/SelectionWatcher.swift`
- Test: `Tests/MarkItCoreTests/SelectionGateTests.swift`

**Interfaces:**
- Consumes: `ExclusionList.contains(_:)` (Task 3)
- Produces: `public enum SelectionGate` with `static func shouldCopy(enabled:frontmostBundleID:exclusions:ownBundleID:) -> Bool`; `public final class SelectionWatcher(exclusions: ExclusionList, ownBundleID: String = Bundle.main.bundleIdentifier ?? "com.raulpena.markit")` with `.isEnabled: Bool`, `.onCopy: (() -> Void)?`, `.start()`. Used by `AppDelegate` (Task 6).

- [ ] **Step 1: Write the failing tests for the pure decision logic**

Create `Tests/MarkItCoreTests/SelectionGateTests.swift`:

```swift
import XCTest
@testable import MarkItCore

final class SelectionGateTests: XCTestCase {
    var defaults: UserDefaults!
    let suiteName = "com.raulpena.markit.tests.selectiongate"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_disabled_neverCopies() {
        let exclusions = ExclusionList(defaults: defaults)
        XCTAssertFalse(SelectionGate.shouldCopy(enabled: false, frontmostBundleID: "com.apple.TextEdit", exclusions: exclusions, ownBundleID: "com.raulpena.markit"))
    }

    func test_enabled_unexcludedApp_copies() {
        let exclusions = ExclusionList(defaults: defaults)
        XCTAssertTrue(SelectionGate.shouldCopy(enabled: true, frontmostBundleID: "com.apple.TextEdit", exclusions: exclusions, ownBundleID: "com.raulpena.markit"))
    }

    func test_excludedApp_doesNotCopy() {
        let exclusions = ExclusionList(defaults: defaults)
        exclusions.add("com.apple.Terminal")
        XCTAssertFalse(SelectionGate.shouldCopy(enabled: true, frontmostBundleID: "com.apple.Terminal", exclusions: exclusions, ownBundleID: "com.raulpena.markit"))
    }

    func test_ownBundleID_neverCopies() {
        let exclusions = ExclusionList(defaults: defaults)
        XCTAssertFalse(SelectionGate.shouldCopy(enabled: true, frontmostBundleID: "com.raulpena.markit", exclusions: exclusions, ownBundleID: "com.raulpena.markit"))
    }

    func test_implicitlyExcludedSystemProcess_doesNotCopy() {
        let exclusions = ExclusionList(defaults: defaults)
        XCTAssertFalse(SelectionGate.shouldCopy(enabled: true, frontmostBundleID: "com.apple.dock", exclusions: exclusions, ownBundleID: "com.raulpena.markit"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SelectionGateTests`
Expected: FAIL — `SelectionGate` not found.

- [ ] **Step 3: Implement `SelectionGate`**

Create `Sources/MarkItCore/Selection/SelectionGate.swift`:

```swift
import Foundation

public enum SelectionGate {
    static let implicitlyExcludedBundleIDs: Set<String> = [
        "com.apple.dock",
        "com.apple.systemuiserver",
        "com.apple.WindowManager"
    ]

    public static func shouldCopy(
        enabled: Bool,
        frontmostBundleID: String?,
        exclusions: ExclusionList,
        ownBundleID: String
    ) -> Bool {
        guard enabled else { return false }
        guard let bundleID = frontmostBundleID else { return true }
        if bundleID == ownBundleID { return false }
        if implicitlyExcludedBundleIDs.contains(bundleID) { return false }
        if exclusions.contains(bundleID) { return false }
        return true
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SelectionGateTests`
Expected: all 5 tests PASS.

- [ ] **Step 5: Implement `SelectionWatcher` (CGEventTap + Accessibility wiring — not unit-testable, see Global Constraints)**

Create `Sources/MarkItCore/Selection/SelectionWatcher.swift`:

```swift
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
```

- [ ] **Step 6: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 7: Manual verification (Raul) — flag, don't claim done**

This can't be exercised until Task 6 wires it into `AppDelegate`. Note in the handoff that end-to-end verification (grant Accessibility permission, drag-select text, confirm clipboard updates) happens at Task 6's manual step, not here.

- [ ] **Step 8: Commit**

```bash
git add Sources/MarkItCore/Selection Tests/MarkItCoreTests/SelectionGateTests.swift
git commit -m "feat: add selection detection and copy gate"
```

---

### Task 5: Global hotkey and history popup

**Files:**
- Create: `Sources/MarkItCore/Hotkey/HotkeyManager.swift`
- Create: `Sources/MarkItCore/UI/HistoryPopupView.swift`
- Create: `Sources/MarkItCore/UI/HistoryPopupController.swift`
- Modify: `Sources/MarkItCore/App/AppDelegate.swift` (temporary demo wiring, replaced in Task 6)

**Interfaces:**
- Consumes: `ClipboardHistoryStore.items` (Task 2)
- Produces: `public final class HotkeyManager` with `.register(keyCode: UInt32 = UInt32(kVK_ANSI_V), modifiers: UInt32 = UInt32(cmdKey | shiftKey)) -> Bool`, `.onTrigger: (() -> Void)?`, `.unregister()`; `public final class HistoryPopupController(store: ClipboardHistoryStore)` with `.toggle()`, `.show()`, `.close()`. Used by `AppDelegate` (Task 6).

- [ ] **Step 1: Implement `HotkeyManager`**

Create `Sources/MarkItCore/Hotkey/HotkeyManager.swift`:

```swift
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
```

- [ ] **Step 2: Implement `HistoryPopupView`**

Create `Sources/MarkItCore/UI/HistoryPopupView.swift`:

```swift
import SwiftUI

struct HistoryPopupView: View {
    let items: [ClipboardItem]
    let onSelect: (ClipboardItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if items.isEmpty {
                Text("No clipboard history yet")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(items) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        Text(item.text.prefix(80))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 320)
        .padding(.vertical, 6)
    }
}
```

- [ ] **Step 3: Implement `HistoryPopupController`**

Create `Sources/MarkItCore/UI/HistoryPopupController.swift`:

```swift
import Cocoa
import SwiftUI

public final class HistoryPopupController {
    let store: ClipboardHistoryStore
    private var panel: NSPanel?

    public init(store: ClipboardHistoryStore) {
        self.store = store
    }

    public func toggle() {
        if panel != nil { close() } else { show() }
    }

    public func show() {
        let view = HistoryPopupView(items: store.items) { [weak self] item in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.text, forType: .string)
            self?.close()
        }
        let hosting = NSHostingController(rootView: view)
        let panel = NSPanel(contentViewController: hosting)
        panel.styleMask = [.nonactivatingPanel, .titled, .closable]
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        let mouseLocation = NSEvent.mouseLocation
        panel.setFrameOrigin(NSPoint(x: mouseLocation.x, y: mouseLocation.y - 200))
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        NotificationCenter.default.addObserver(self, selector: #selector(panelResigned), name: NSWindow.didResignKeyNotification, object: panel)
    }

    @objc private func panelResigned() {
        close()
    }

    public func close() {
        panel?.close()
        panel = nil
        NotificationCenter.default.removeObserver(self)
    }
}
```

- [ ] **Step 4: Temporary demo wiring to verify the popup end-to-end**

Modify `Sources/MarkItCore/App/AppDelegate.swift` — add to `applicationDidFinishLaunching`, after the existing status item setup:

```swift
let demoStore = ClipboardHistoryStore(fileURL: ClipboardHistoryStore.defaultFileURL())
demoStore.add(text: "First demo item")
demoStore.add(text: "Second demo item")
let demoPopup = HistoryPopupController(store: demoStore)
let demoHotkey = HotkeyManager()
demoHotkey.onTrigger = { demoPopup.toggle() }
_ = demoHotkey.register()
self.demoHotkey = demoHotkey // retain
self.demoPopup = demoPopup   // retain
```

Add the two retaining properties to the class: `private var demoHotkey: HotkeyManager?` and `private var demoPopup: HistoryPopupController?`. This demo code is temporary — Task 6 replaces it with the real wiring.

- [ ] **Step 5: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 6: Manual verification (Raul)**

Run: `./scripts/build-debug-app.sh && open .build/debug-app/MarkIt.app`, press ⌘⇧V, confirm the popup appears near the cursor showing "Second demo item" and "First demo item". Click one, then paste (right-click → Paste) into TextEdit — confirm the clicked text pastes.

- [ ] **Step 7: Commit**

```bash
git add Sources/MarkItCore/Hotkey Sources/MarkItCore/UI/HistoryPopupView.swift Sources/MarkItCore/UI/HistoryPopupController.swift Sources/MarkItCore/App/AppDelegate.swift
git commit -m "feat: add global hotkey and clipboard history popup"
```

---

### Task 6: Wire selection watcher, history, and hotkey into the real app

**Files:**
- Create: `Sources/MarkItCore/App/StatusBarController.swift`
- Create: `Sources/MarkItCore/App/LoginItemManager.swift`
- Modify: `Sources/MarkItCore/App/AppDelegate.swift` (replace Task 5's temporary demo wiring)

**Interfaces:**
- Consumes: `SelectionWatcher` (Task 4), `HotkeyManager`, `HistoryPopupController` (Task 5), `ExclusionList` (Task 3)
- Produces: `public final class StatusBarController(selectionWatcher:historyPopup:hotkeyManager:exclusions:)`; `public enum LoginItemManager` with `.isEnabled: Bool`, `.setEnabled(_ enabled: Bool)`. Used/extended by Tasks 7 and 8.

- [ ] **Step 1: Implement `LoginItemManager`**

Create `Sources/MarkItCore/App/LoginItemManager.swift`:

```swift
import ServiceManagement
import os.log

public enum LoginItemManager {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            os_log("MarkIt: failed to set login item enabled=%{public}@: %{public}@", "\(enabled)", "\(error)")
        }
    }
}
```

- [ ] **Step 2: Implement `StatusBarController`**

Create `Sources/MarkItCore/App/StatusBarController.swift`:

```swift
import Cocoa

public final class StatusBarController {
    private let statusItem: NSStatusItem
    private let selectionWatcher: SelectionWatcher
    private let historyPopup: HistoryPopupController
    private let hotkeyManager: HotkeyManager
    let exclusions: ExclusionList
    private var isAutoCopyEnabled = true {
        didSet { selectionWatcher.isEnabled = isAutoCopyEnabled }
    }

    public init(selectionWatcher: SelectionWatcher, historyPopup: HistoryPopupController, hotkeyManager: HotkeyManager, exclusions: ExclusionList) {
        self.selectionWatcher = selectionWatcher
        self.historyPopup = historyPopup
        self.hotkeyManager = hotkeyManager
        self.exclusions = exclusions
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureIcon()
        buildMenu()
    }

    private func configureIcon() {
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "MarkIt")
        statusItem.button?.image?.isTemplate = true
    }

    private func buildMenu() {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Auto-copy on Select", action: #selector(toggleAutoCopy), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = isAutoCopyEnabled ? .on : .off
        menu.addItem(toggleItem)

        let historyItem = NSMenuItem(title: "Clipboard History", action: #selector(showHistory), keyEquivalent: "")
        historyItem.target = self
        menu.addItem(historyItem)

        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LoginItemManager.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "About MarkIt", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func toggleAutoCopy(_ sender: NSMenuItem) {
        isAutoCopyEnabled.toggle()
        sender.state = isAutoCopyEnabled ? .on : .off
    }

    @objc private func showHistory() {
        historyPopup.toggle()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        LoginItemManager.setEnabled(!LoginItemManager.isEnabled)
        sender.state = LoginItemManager.isEnabled ? .on : .off
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
```

- [ ] **Step 3: Replace `AppDelegate`'s temporary demo wiring with the real app**

Replace the full contents of `Sources/MarkItCore/App/AppDelegate.swift`:

```swift
import Cocoa

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var selectionWatcher: SelectionWatcher!
    private var hotkeyManager: HotkeyManager!
    private var historyPopup: HistoryPopupController!
    private let exclusions = ExclusionList()
    private let historyStore = ClipboardHistoryStore(fileURL: ClipboardHistoryStore.defaultFileURL())

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        selectionWatcher = SelectionWatcher(exclusions: exclusions)
        selectionWatcher.onCopy = { [weak self] in
            guard let text = NSPasteboard.general.string(forType: .string) else { return }
            self?.historyStore.add(text: text)
        }
        selectionWatcher.start()

        historyPopup = HistoryPopupController(store: historyStore)

        hotkeyManager = HotkeyManager()
        hotkeyManager.onTrigger = { [weak self] in self?.historyPopup.toggle() }
        _ = hotkeyManager.register()

        statusBarController = StatusBarController(
            selectionWatcher: selectionWatcher,
            historyPopup: historyPopup,
            hotkeyManager: hotkeyManager,
            exclusions: exclusions
        )
    }
}
```

- [ ] **Step 4: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 5: Manual verification (Raul) — flag, don't claim done**

Run `./scripts/build-debug-app.sh && open .build/debug-app/MarkIt.app`. Grant Accessibility permission to `.build/debug-app/MarkIt.app` in System Settings → Privacy & Security → Accessibility (add it manually for now; Task 8 automates the prompt). Then:
- Drag-select text in TextEdit with "Auto-copy on Select" ON → right-click → Paste elsewhere → confirm it pastes.
- Toggle "Auto-copy on Select" OFF from the menu → drag-select different text → confirm the clipboard does *not* change.
- Press ⌘⇧V → confirm the history popup shows real selected text, not the Task 5 demo strings.

- [ ] **Step 6: Commit**

```bash
git add Sources/MarkItCore/App/StatusBarController.swift Sources/MarkItCore/App/LoginItemManager.swift Sources/MarkItCore/App/AppDelegate.swift
git commit -m "feat: wire selection watching, history, and hotkey into the app"
```

---

### Task 7: Excluded apps management window

**Files:**
- Create: `Sources/MarkItCore/UI/ExcludedAppsView.swift`
- Create: `Sources/MarkItCore/App/ExcludedAppsWindowController.swift`
- Modify: `Sources/MarkItCore/App/StatusBarController.swift` (add the "Excluded Apps…" menu item)

**Interfaces:**
- Consumes: `ExclusionList` (Task 3), `StatusBarController.exclusions` (Task 6)
- Produces: `ExcludedAppsWindowController.shared.show(exclusions: ExclusionList)`. Used by `StatusBarController`.

- [ ] **Step 1: Implement the view model and view**

Create `Sources/MarkItCore/UI/ExcludedAppsView.swift`:

```swift
import SwiftUI
import AppKit

struct RunningAppOption {
    let bundleID: String
    let name: String
}

final class ExcludedAppsModel: ObservableObject {
    @Published var excludedBundleIDs: [String] = []
    @Published var selectedRunningAppBundleID: String?
    @Published var runningAppOptions: [RunningAppOption] = []

    private let exclusions: ExclusionList

    init(exclusions: ExclusionList) {
        self.exclusions = exclusions
        refresh()
    }

    func refresh() {
        excludedBundleIDs = Array(exclusions.bundleIDs).sorted()
        runningAppOptions = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier, let name = app.localizedName else { return nil }
                return RunningAppOption(bundleID: bundleID, name: name)
            }
            .sorted { $0.name < $1.name }
    }

    func addSelected() {
        guard let bundleID = selectedRunningAppBundleID else { return }
        exclusions.add(bundleID)
        selectedRunningAppBundleID = nil
        refresh()
    }

    func remove(_ bundleID: String) {
        exclusions.remove(bundleID)
        refresh()
    }
}

struct ExcludedAppsView: View {
    @ObservedObject var model: ExcludedAppsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Excluded Apps").font(.headline)
            List {
                ForEach(model.excludedBundleIDs, id: \.self) { bundleID in
                    HStack {
                        Text(bundleID)
                        Spacer()
                        Button("Remove") { model.remove(bundleID) }
                    }
                }
            }
            .frame(minHeight: 150)

            HStack {
                Picker("Add running app", selection: $model.selectedRunningAppBundleID) {
                    Text("Choose an app…").tag(String?.none)
                    ForEach(model.runningAppOptions, id: \.bundleID) { app in
                        Text(app.name).tag(String?.some(app.bundleID))
                    }
                }
                Button("Add") { model.addSelected() }
                    .disabled(model.selectedRunningAppBundleID == nil)
            }
        }
        .padding()
        .frame(width: 360)
    }
}
```

- [ ] **Step 2: Implement the window controller**

Create `Sources/MarkItCore/App/ExcludedAppsWindowController.swift`:

```swift
import Cocoa
import SwiftUI

final class ExcludedAppsWindowController {
    static let shared = ExcludedAppsWindowController()
    private var window: NSWindow?

    func show(exclusions: ExclusionList) {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let model = ExcludedAppsModel(exclusions: exclusions)
        let hosting = NSHostingController(rootView: ExcludedAppsView(model: model))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Excluded Apps"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        NotificationCenter.default.addObserver(self, selector: #selector(windowClosed), name: NSWindow.willCloseNotification, object: window)
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func windowClosed() {
        window = nil
    }
}
```

- [ ] **Step 3: Add the menu item**

Modify `Sources/MarkItCore/App/StatusBarController.swift` — in `buildMenu()`, insert after the "Clipboard History" item and before the following separator:

```swift
let excludedItem = NSMenuItem(title: "Excluded Apps…", action: #selector(showExcludedApps), keyEquivalent: "")
excludedItem.target = self
menu.addItem(excludedItem)
```

And add the action method:

```swift
@objc private func showExcludedApps() {
    ExcludedAppsWindowController.shared.show(exclusions: exclusions)
}
```

- [ ] **Step 4: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 5: Manual verification (Raul) — flag, don't claim done**

Open "Excluded Apps…" from the menu, add a running app (e.g. Terminal) via the picker, confirm it appears in the list. Select text in that app — confirm no auto-copy happens. Remove it from the list — confirm auto-copy resumes there.

- [ ] **Step 6: Commit**

```bash
git add Sources/MarkItCore/UI/ExcludedAppsView.swift Sources/MarkItCore/App/ExcludedAppsWindowController.swift Sources/MarkItCore/App/StatusBarController.swift
git commit -m "feat: add excluded apps management window"
```

---

### Task 8: Accessibility permission onboarding

**Files:**
- Create: `Sources/MarkItCore/App/AccessibilityPermissionManager.swift`
- Create: `Sources/MarkItCore/UI/OnboardingView.swift`
- Create: `Sources/MarkItCore/App/OnboardingWindowController.swift`
- Modify: `Sources/MarkItCore/App/AppDelegate.swift` (check trust on launch and on activation)
- Modify: `Sources/MarkItCore/App/StatusBarController.swift` (reflect trust state on the status icon)

**Interfaces:**
- Consumes: nothing new
- Produces: `AccessibilityPermissionManager.isTrusted: Bool`, `.requestPermission()`, `.openAccessibilitySettings()`; `OnboardingWindowController.shared.showIfNeeded()`; `StatusBarController.updateTrustState()`.

- [ ] **Step 1: Implement `AccessibilityPermissionManager`**

Create `Sources/MarkItCore/App/AccessibilityPermissionManager.swift`:

```swift
import ApplicationServices
import Cocoa

enum AccessibilityPermissionManager {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
```

- [ ] **Step 2: Implement the onboarding view**

Create `Sources/MarkItCore/UI/OnboardingView.swift`:

```swift
import SwiftUI

struct OnboardingView: View {
    let onRequestPermission: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 40))
            Text("MarkIt needs Accessibility access")
                .font(.headline)
            Text("This lets MarkIt see when you select text anywhere, so it can copy it automatically. It never reads or stores anything except what you actively select.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open System Settings") {
                onRequestPermission()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 340)
    }
}
```

- [ ] **Step 3: Implement the onboarding window controller**

Create `Sources/MarkItCore/App/OnboardingWindowController.swift`:

```swift
import Cocoa
import SwiftUI

final class OnboardingWindowController {
    static let shared = OnboardingWindowController()
    private var window: NSWindow?

    func showIfNeeded() {
        guard !AccessibilityPermissionManager.isTrusted else {
            window?.close()
            return
        }
        guard window == nil else { return }
        let view = OnboardingView {
            AccessibilityPermissionManager.requestPermission()
            AccessibilityPermissionManager.openAccessibilitySettings()
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Welcome to MarkIt"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

- [ ] **Step 4: Wire the trust check into `AppDelegate`**

Modify `Sources/MarkItCore/App/AppDelegate.swift` — add at the end of `applicationDidFinishLaunching`:

```swift
OnboardingWindowController.shared.showIfNeeded()
NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
    OnboardingWindowController.shared.showIfNeeded()
    self?.statusBarController.updateTrustState()
}
```

- [ ] **Step 5: Reflect trust state on the status icon**

Modify `Sources/MarkItCore/App/StatusBarController.swift` — add:

```swift
func updateTrustState() {
    statusItem.button?.appearsDisabled = !AccessibilityPermissionManager.isTrusted
}
```

Call it once at the end of `init` too, so the icon is correct immediately on launch:

```swift
updateTrustState()
```

- [ ] **Step 6: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 7: Manual verification (Raul) — flag, don't claim done**

On a fresh Accessibility grant (remove MarkIt from System Settings → Privacy & Security → Accessibility first): launch MarkIt, confirm the onboarding window appears and "Open System Settings" deep-links correctly. Grant permission, reopen "Excluded Apps…" (which reactivates the app) — confirm the onboarding window doesn't reappear and the status icon is no longer dimmed. Revoke permission again, reactivate the app the same way — confirm the icon dims and the onboarding window reappears.

- [ ] **Step 8: Commit**

```bash
git add Sources/MarkItCore/App/AccessibilityPermissionManager.swift Sources/MarkItCore/UI/OnboardingView.swift Sources/MarkItCore/App/OnboardingWindowController.swift Sources/MarkItCore/App/AppDelegate.swift Sources/MarkItCore/App/StatusBarController.swift
git commit -m "feat: add accessibility permission onboarding"
```

---

### Task 9: App metadata, packaging script, and final manual pass

**Files:**
- Modify: `Resources/Info.plist` (version fields, if bumping)
- Create: `scripts/release.sh`
- Modify: `TODO.md` (record manual test results)

**Interfaces:**
- Consumes: the finished app from Tasks 1–8
- Produces: a version-tagged, signable app and a repeatable local release script. Nothing later depends on this task.

- [ ] **Step 1: Confirm version metadata**

`Resources/Info.plist` already sets `CFBundleShortVersionString` to `1.0.0` and `CFBundleVersion` to `1` from Task 1 — confirm those values are still correct for this release (bump them here directly if not).

- [ ] **Step 2: Add an app icon (Raul, design step — not code)**

MarkIt currently has no custom icon (the packaged `.app` will use a default system icon). Adding one means producing a `.icns` file and adding an `CFBundleIconFile` key to `Resources/Info.plist` pointing at it, copied into `Contents/Resources/` by the packaging scripts. No plan step can generate the artwork itself — flag this as an open item for Raul.

- [ ] **Step 3: Write the release script**

Create `scripts/release.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Required environment variables (set these in your shell — never commit them):
#   MARKIT_SIGNING_IDENTITY — e.g. "Developer ID Application: Raul Pena (TEAMID)"
#
# One-time setup for notarization (run once, stores credentials in your keychain):
#   xcrun notarytool store-credentials "MarkItNotary" \
#     --apple-id "you@example.com" --team-id "YOURTEAMID" --password "app-specific-password"

VERSION="${1:?Usage: scripts/release.sh <version, e.g. 1.0.0>}"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/MarkIt.app"
DMG_PATH="$BUILD_DIR/MarkIt-$VERSION.dmg"

rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"

swift build -c release

cp .build/release/MarkIt "$APP_DIR/Contents/MacOS/MarkIt"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"

codesign --force --deep --options runtime \
  --sign "$MARKIT_SIGNING_IDENTITY" \
  "$APP_DIR"

hdiutil create -volname "MarkIt" -srcfolder "$APP_DIR" \
  -ov -format UDZO "$DMG_PATH"

xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "MarkItNotary" \
  --wait

xcrun stapler staple "$DMG_PATH"

echo "Done: $DMG_PATH"
```

```bash
chmod +x scripts/release.sh
```

Note: `notarytool submit` requires a `.zip`, `.dmg`, or `.pkg` — never a bare `.app` directory — which is why the `.dmg` is built and stapled *before* notarization, and the dmg (not the app) is what's submitted.

- [ ] **Step 4: Verify what can be verified without Raul's Apple credentials**

Run: `bash -n scripts/release.sh`
Expected: no syntax errors (no output).

Run: `plutil -p Resources/Info.plist | grep -E "CFBundleShortVersionString|CFBundleVersion|LSUIElement"`
Expected: shows `1.0.0`, `1`, and `1` (true) respectively.

Run: `swift build`
Expected: `Build complete!`

Run: `swift test`
Expected: all unit tests (`ClipboardHistoryStoreTests`, `ExclusionListTests`, `SelectionGateTests`) PASS.

- [ ] **Step 5: Run the full manual checklist and record results (Raul)**

Work through the spec's Testing Plan manual checklist end to end (`docs/superpowers/specs/2026-09-19-markit-design.md`). Update `TODO.md` with which items passed, and flag anything that didn't. The signed/notarized Gatekeeper check (`spctl -a -vv build/MarkIt.app`) requires Raul to actually run `scripts/release.sh` with his Apple credentials first — that step is explicitly his to do, not something completed in an agent session.

- [ ] **Step 6: Commit**

```bash
git add Resources/Info.plist scripts/release.sh TODO.md
git commit -m "chore: add release script and version metadata"
```

---

## Self-review notes

- **Spec coverage:** every spec section maps to a task — architecture/components → Tasks 1–6; detection behavior → Task 4; sandboxing → Global Constraints (no App Sandbox target/entitlement exists in `Package.swift`, satisfying it by omission); clipboard history → Task 2; hotkey/popup → Task 5; menu bar menu → Tasks 6–8; error handling → Tasks 2 (corrupt file), 4 (AX fallback, tap resilience), 5 (hotkey registration failure logged, not surfaced as a UI feature per YAGNI — acceptable since the spec only requires it not crash silently-broken), 8 (permission revoked); repo layout → Task 1 (superseded by the SPM ruling above; `AGENTS.md` updated to match); testing plan → automated portions in Tasks 2–4, manual portions distributed across Tasks 1, 5–9; distribution → Task 9.
- **Placeholder scan:** no TBD/TODO markers; every step has runnable code or an exact command.
- **Type consistency:** verified `ClipboardHistoryStore`, `ExclusionList`, `SelectionGate`, `SelectionWatcher`, `HotkeyManager`, `HistoryPopupController`, `StatusBarController`, `LoginItemManager`, `ExcludedAppsWindowController`, `AccessibilityPermissionManager`, and `OnboardingWindowController` signatures match between the task that defines them and every later task that calls them. Cross-module (`MarkItCore` → `MarkIt` executable) boundary verified: only `AppDelegate` (class + init + `applicationDidFinishLaunching`) needs `public`, since `Sources/MarkIt/main.swift` is the only consumer outside `MarkItCore`.
