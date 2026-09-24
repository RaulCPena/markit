# MarkIt — agent notes

Native Swift/AppKit macOS menu bar app. Selecting text anywhere
auto-copies it to the clipboard (no ⌘C needed); right-click → Paste
then works anywhere, unmodified. Includes a small clipboard history
(⌘⇧V) and per-app exclusions.

The **app** is Swift only (`Sources/`, `Tests/`). `MarkIt.xcodeproj`
is generated from `project.yml` via XcodeGen. `Package.swift` remains
for optional `swift test`. No Python/JS runtime in the product.

Public GitHub page is `README.md`. Do not point visitors at
`TODO.md` or superpowers plans. Do not name competing apps in
user-facing docs (README, site, free-vs-pro).

Full design: `docs/superpowers/specs/2026-09-19-markit-design.md`.
Current status: `TODO.md`. Product split: `docs/free-vs-pro.md`.

## Working style (this product)

- Raul is product: features, tone, shipping calls.
- Agent is Swift/AppKit: clean code, tests, build scripts.
- Prefer small, readable types over clever abstractions.
- User-facing copy (README, site, in-app strings): short,
  plain, technical when needed — not “AI brochure” voice.
  Match how a Mac utility author would write it.
- PDF user guide is planned later; until then keep Markdown
  tight enough that a PDF export won’t need a rewrite.

## Build & test

- Xcode app project: `open MarkIt.xcodeproj` (or `xed .`).
  After editing `project.yml`, run `xcodegen generate`.
- Debug run from Xcode (⌘R), or:
  `./scripts/build-debug-app.sh && open /Applications/MarkIt.app`
  Grant Accessibility to **`/Applications/MarkIt.app`**.
- Unit tests: ⌘U in Xcode, or `swift test`.
- **Ship / notarize (preferred):** Xcode → Product → Archive →
  Distribute App → **Direct Distribution** (Developer ID) → Notarize.
  Needs a logged-in Apple ID in Xcode Settings → Accounts (team
  `D9M7YX54A8`). Xcode can handle notarization without a separate
  `notarytool` profile when you use Organizer.
- CLI equivalent: `./scripts/release.sh 1.0.0` (still needs
  keychain profile `MarkItNotary` for `notarytool`).
- Unit tests cover store/gate/planner logic. Live `CGEventTap` /
  Accessibility paths are manual checklist in the design spec.

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
- Bundle ID is `com.raulpena.markit` — do not change without
  re-granting Accessibility.
- Signing/notarization needs Raul's Apple Developer account in
  Xcode. Agent sessions cannot notarize unattended.
- Accessibility permission is tied to code identity. Prefer the
  `/Applications/MarkIt.app` install from `build-debug-app.sh` or a
  Release/Archive build. If onboarding keeps returning, remove MarkIt
  from Accessibility, add the current app path, relaunch.
- `SMAppService` (Launch at Login) is most reliable for an app
  installed in `/Applications` — test against a release/Archive build.
- Regenerate the Xcode project after `project.yml` changes:
  `xcodegen generate`. Commit `MarkIt.xcodeproj` so Raul can open
  it without running XcodeGen first.
