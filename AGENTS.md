# MarkIt — agent notes

Native Swift/AppKit macOS menu bar app. Selecting text anywhere
auto-copies it to the clipboard (no ⌘C needed); right-click → Paste
then works anywhere, unmodified. Includes a small clipboard history
(⌘⇧V) and per-app exclusions.

Full design: `docs/superpowers/specs/2026-09-19-markit-design.md`.
Current status: `TODO.md`.

## Build & test

- Open `MarkIt.xcodeproj` in Xcode, or:
  `xcodebuild -project MarkIt.xcodeproj -scheme MarkIt build`
- Unit tests: `xcodebuild test -project MarkIt.xcodeproj -scheme MarkIt -only-testing:MarkItTests`
- Unit tests cover `ClipboardHistoryStore` and `ExclusionList` only —
  `SelectionWatcher`/`HotkeyManager` need live Accessibility
  permission and global event taps, so they're covered by the manual
  checklist in the design spec, not XCTest.

## Architecture (see spec for full detail)

- `SelectionWatcher` — detects selection gestures, simulates ⌘C.
- `ClipboardHistoryStore` — pasteboard history, JSON-persisted.
- `ExclusionList` — per-app opt-out, `UserDefaults`-persisted.
- `HotkeyManager` — global ⌘⇧V via Carbon, opens history popup.
- `StatusBarController` — menu bar UI, wires everything together.

## Gotchas

- Not sandboxed, and can't be — `CGEventTap` + cross-process
  `AXUIElement` reads are incompatible with the App Sandbox. Ships as
  a direct Developer-ID-signed download, not on the Mac App Store.
- Needs Accessibility permission (System Settings → Privacy &
  Security → Accessibility) to do anything. The app checks
  `AXIsProcessTrusted()` on launch and on every activation.
- Signing/notarization requires Raul's Apple Developer credentials
  locally — not something an agent session can do unattended.
