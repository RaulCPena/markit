# MarkIt — design spec

Date: 2026-09-19
Status: approved (chat walkthrough with Raul, 2026-09-19)

## Purpose

A free, open-source macOS menu bar utility that copies text to the
clipboard automatically the moment it's selected/highlighted —
mimicking the X11 "primary selection" behavior — so the user can
immediately right-click → Paste anywhere without pressing ⌘C first.
Adds a lightweight clipboard history on top, since the auto-copy
behavior makes clobbering the clipboard more frequent.

Distributed publicly and for free: source on GitHub (MIT license),
signed + notarized `.dmg` on GitHub Releases.

## Goals

- Selecting text anywhere on macOS (drag-select or keyboard selection)
  copies it to the clipboard with no explicit copy action.
- Right-click → Paste (standard macOS behavior, unmodified) then works
  immediately, anywhere.
- Small clipboard history so an auto-copy that overwrites something
  the user wanted isn't destructive.
- Per-app exclusions and a global on/off toggle, since blind auto-copy
  is undesirable in some apps/contexts.
- Zero configuration required to get the core behavior working beyond
  granting Accessibility permission once.

## Non-goals (v1)

- Syncing clipboard history across devices.
- Non-text clipboard content (images, files, rich text/RTF preserved
  formatting) — v1 is plain text only.
- Remappable global hotkey (ships with one fixed default).
- Auto-update mechanism — users redownload new releases manually.
- Mac App Store distribution (see Sandboxing, below, for why).

## Architecture

Native Swift + AppKit menu bar app (`LSUIElement = true`, no Dock
icon). Minimum deployment target: macOS 13.0 (required for
`SMAppService` login-item API).

Six components, each independently reasoned about:

| Component | Responsibility | Depends on |
|---|---|---|
| `SelectionWatcher` | Detects a text-selection gesture (mouse-drag-release or keyboard selection), applies exclusion/toggle checks, simulates ⌘C | `ExclusionList`, AX API, CGEventTap |
| `ClipboardHistoryStore` | Watches `NSPasteboard.changeCount`, appends/dedupes/caps/persists text items | none (pure model + disk I/O) |
| `ExclusionList` | Set of excluded app bundle IDs, persisted | `UserDefaults` |
| `HotkeyManager` | Registers global hotkey (default ⌘⇧V), fires a callback | Carbon `RegisterEventHotKey` |
| `HistoryPopupView` (SwiftUI) | Floating window listing recent history items; click sets pasteboard | `ClipboardHistoryStore` |
| `StatusBarController` | `NSStatusItem` menu; wires everything; owns app-level state (enabled/disabled) | all of the above |

`ClipboardHistoryStore` and `ExclusionList` are pure enough to unit
test directly. `SelectionWatcher` and `HotkeyManager` require live
global OS state (Accessibility trust, event taps) and are covered by
manual testing only (see Testing).

## Detection behavior

**Trigger conditions** (any of):
- Left mouse-up that follows a mouse-drag (click-and-drag text
  selection).
- Key-up after Shift+Arrow, Shift+Cmd+Arrow, or Cmd+A.

A 60ms debounce collapses rapid repeated trigger events (e.g. multiple
shift-arrow presses extending a selection) into a single copy.

**Verification before copying:** `SelectionWatcher` attempts to read
`kAXSelectedTextAttribute` from the system-wide focused UI element via
the Accessibility API.
- Non-empty string returned → simulate ⌘C via `CGEvent`.
- AX read fails or returns empty (common in some Electron/web-based
  apps that don't expose this attribute) → fall back to simulating ⌘C
  unconditionally on the trigger event. This is a deliberate
  best-effort fallback: a plain click with no drag won't reach this
  code path (no drag = no trigger), so the main risk is a false
  positive on an app that doesn't expose AX selection state, which is
  a no-op-ish clipboard overwrite, not data loss.

**Exclusions:** before acting, check `NSWorkspace.shared
.frontmostApplication`'s bundle ID against `ExclusionList`, and always
implicitly exclude MarkIt's own bundle ID and system UI processes
(Dock, SystemUIServer, WindowManager) to avoid feedback loops.

**Global toggle:** a menu bar checkbox item disables `SelectionWatcher`
entirely without unregistering the event tap (cheap to re-enable), for
cases like screen-sharing where the user wants zero automatic
clipboard writes.

**Permission flow:** on launch, check `AXIsProcessTrusted()`.
- Not trusted → show a one-screen onboarding window (plain-language
  explanation + a button that calls
  `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`,
  which both prompts the system dialog and deep-links to System
  Settings → Privacy & Security → Accessibility).
- Re-check on every app activation (`NSApplication` becoming active),
  since the user may grant/revoke permission while MarkIt is running;
  reflect current trust state in the menu bar icon (e.g. dimmed if
  untrusted).

**Event tap resilience:** macOS disables a `CGEventTap` if its callback
takes too long or the process is suspended. `SelectionWatcher` listens
for `.tapDisabledByTimeout` / `.tapDisabledByUserInput` and calls
`CGEvent.tapEnable(tap:true)` to re-arm it immediately.

## Sandboxing

MarkIt does **not** use the App Sandbox. Global `CGEventTap` creation
and reading another process's `AXUIElement` attributes are both
incompatible with the sandbox — this is precisely why an equivalent
app can't ship on the Mac App Store, and why distribution is a
Developer-ID-signed direct download instead.

## Clipboard history

- `ClipboardHistoryStore` polls `NSPasteboard.general.changeCount`
  (checked from the same debounce/trigger path as `SelectionWatcher`,
  no separate timer needed) and appends a new `ClipboardItem` when it
  changes and contains plain text (`public.utf8-plain-text`).
- `ClipboardItem { id: UUID, text: String, timestamp: Date }`.
- Deduped by text equality against the most recent 10 items (avoids a
  string of identical entries from repeated selection of the same
  text).
- Capped at 50 items (oldest evicted first).
- Persisted as JSON under
  `~/Library/Application Support/MarkIt/history.json`, loaded on
  launch, saved on every append (fire-and-forget, small file).

## Global hotkey & history popup

- Default hotkey: ⌘⇧V, registered via Carbon's
  `RegisterEventHotKey`/`InstallEventHandler` (no third-party
  dependency). Not user-remappable in v1 (YAGNI — add later if
  requested).
- On trigger, `HistoryPopupView` (SwiftUI, hosted in an `NSPanel`)
  appears near the current mouse location listing history items
  newest-first (text preview, truncated).
- Clicking an item sets it as the current pasteboard content and
  dismisses the popup; the user then pastes normally (right-click or
  ⌘V) wherever they want it.
- Popup also dismisses on Escape or click-outside.
- Same list is reachable from the menu bar icon's "Clipboard History"
  submenu, for discoverability without the hotkey.

## Menu bar menu

- MarkIt icon (template image, adapts to light/dark menu bar) — visual
  state reflects enabled/disabled and Accessibility-trust status.
- ☑︎ Auto-copy on Select (toggle)
- Clipboard History ▸ (submenu, same items as popup, click-to-set)
- Excluded Apps… (opens a small window: list of excluded bundle IDs,
  add via a running-app picker or manual bundle ID entry, remove via
  swipe/delete)
- ☐ Launch at Login (toggle, backed by `SMAppService.mainApp`)
- About MarkIt
- Quit

## Error handling

- Accessibility permission revoked while running → `SelectionWatcher`
  simply stops producing usable AX reads; falls back to blind ⌘C per
  the fallback rule above; menu bar icon reflects untrusted state so
  the user knows why.
- History file unreadable/corrupt on launch → start with empty
  history rather than crashing; overwrite on next successful save.
- Hotkey registration failure (e.g. already claimed by another app) →
  log and disable the history-popup hotkey feature for the session;
  menu bar access to history still works.

## Repo layout

Built as a Swift Package rather than an Xcode-GUI-created `.xcodeproj`
(a ruling made at implementation time — see the implementation plan's
header — since project creation via Xcode's GUI wizard isn't
scriptable by an automated build; `swift build`/`swift test` replace
`xcodebuild`, and a shell script assembles the real `.app` bundle for
running and distribution). This changes build tooling only; every
component below is unchanged.

```
markit/
  Package.swift
  Sources/
    MarkIt/                 (executable target: main.swift only)
    MarkItCore/              (library target: everything else)
      App/                   (AppDelegate, StatusBarController, LoginItemManager,
                               ExcludedAppsWindowController, AccessibilityPermissionManager,
                               OnboardingWindowController)
      Selection/             (SelectionGate, SelectionWatcher)
      Clipboard/             (ClipboardHistoryStore, ClipboardItem)
      Exclusions/            (ExclusionList)
      Hotkey/                (HotkeyManager)
      UI/                    (HistoryPopupView, HistoryPopupController,
                               OnboardingView, ExcludedAppsView)
  Tests/
    MarkItCoreTests/
      ClipboardHistoryStoreTests.swift
      ExclusionListTests.swift
      SelectionGateTests.swift
  Resources/
    Info.plist               (template copied into the packaged .app bundle)
  scripts/
    build-debug-app.sh        (assembles a debug .app for manual testing)
    release.sh                 (release build, codesign, notarize, dmg)
  docs/
    superpowers/specs/2026-09-19-markit-design.md
    superpowers/plans/2026-09-19-markit-implementation.md
  TODO.md
  AGENTS.md
  README.md
  LICENSE (MIT)
```

## Testing plan

**Automated (XCTest, run in CI and locally, no permissions needed):**
- `ClipboardHistoryStoreTests`: append/dedupe/cap-at-50/persist-and-
  reload/corrupt-file-recovery.
- `ExclusionListTests`: add/remove/matching against a bundle ID,
  persistence round-trip.

**Manual (checklist run before each release, requires a real macOS
session with Accessibility permission granted):**
- Grant Accessibility permission via onboarding flow; confirm icon
  reflects trusted state.
- Drag-select text in Safari, TextEdit, Terminal, and one Electron app
  (e.g. VS Code or Slack) → confirm each is copied without ⌘C.
- Keyboard-select (Shift+Arrow, Cmd+A) in TextEdit → confirm copied.
- Add an app to the exclude list → confirm selecting text there no
  longer copies.
- Toggle "Auto-copy on Select" off → confirm no copies fire anywhere.
- Trigger the hotkey → confirm popup shows recent history; click an
  item → confirm it becomes the pasteboard content and can be pasted
  via right-click.
- Enable "Launch at Login", reboot, confirm MarkIt is running.
- Revoke Accessibility permission while running → confirm graceful
  fallback behavior and updated icon state, no crash.
- Launch the signed, notarized `.dmg` build on a separate/clean Mac
  account (or via `spctl -a -vv MarkIt.app`) → confirm no Gatekeeper
  warning.

## Distribution

- Public GitHub repo under Raul's personal GitHub account, MIT
  license.
- Build: `swift build -c release`, assembled into a `.app` bundle by
  `scripts/release.sh`, signed with a Developer ID Application
  identity already in Raul's keychain.
- Notarization: the assembled `.app` is wrapped in a `.dmg` first (a
  bare `.app` directory can't be submitted directly), then
  `xcrun notarytool submit` + `xcrun stapler staple` run against that
  `.dmg` — run manually by Raul (requires his Apple ID / team ID / an
  app-specific password or App Store Connect API key — credentials
  this session does not have and should not attempt to obtain).
- Packaging: signed `.app` wrapped in a `.dmg` (drag-to-Applications
  layout), attached to a GitHub Release.
- No auto-update; users redownload new releases manually (see
  Non-goals).

## Assumptions made explicit (no open TBDs)

- Minimum macOS version: 13.0 (Ventura), for `SMAppService`.
- Default hotkey: ⌘⇧V, fixed in v1.
- History cap: 50 items, dedup window: last 10.
- Exclude list starts empty by default.
- Text-only clipboard content in v1 (no images/files/RTF).
- Repo is created fresh under `~/Development/markit`, initialized on
  `main`.
