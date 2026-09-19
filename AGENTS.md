# MarkIt — agent notes

Native Swift/AppKit macOS menu bar app. Selecting text anywhere
auto-copies it to the clipboard (no ⌘C needed); right-click → Paste
then works anywhere, unmodified. Includes a small clipboard history
(⌘⇧V) and per-app exclusions.

Full design: `docs/superpowers/specs/2026-09-19-markit-design.md`.
Current status: `TODO.md`.

## Build & test

- It's a Swift Package (`Package.swift`), not an Xcode-GUI-created
  project — Xcode opens `Package.swift` directly, or use the CLI:
  `swift build`
- Unit tests: `swift test` (or `swift test --filter <TestClassName>`)
- Run the app: `./scripts/build-debug-app.sh && open .build/debug-app/MarkIt.app`
  (a raw `swift run` binary has no Info.plist / bundle identity, so
  `LSUIElement`, Accessibility permission, and login-item registration
  won't behave correctly without going through this script)
- Unit tests cover `ClipboardHistoryStore`, `ExclusionList`, and
  `SelectionGate` (the pure copy-decision logic) only —
  `SelectionWatcher`/`HotkeyManager`'s live `CGEventTap`/Accessibility
  wiring needs a live GUI session, so it's covered by the manual
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
- Accessibility permission is tied to code identity, not just the
  display name in System Settings. `scripts/build-debug-app.sh` signs
  the debug app with the local Apple Development cert when present so
  rebuilds keep the same identity. If the onboarding sheet keeps
  coming back after the toggle looks on, Settings is still bound to an
  older ad-hoc copy — remove MarkIt from Accessibility, add
  `.build/debug-app/MarkIt.app` again, then relaunch.
- `SMAppService` (Launch at Login) is most reliable for an app
  installed in `/Applications` — test that feature against a release
  build, not the raw debug build sitting in the repo.
