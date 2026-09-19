# MarkIt — status

## Built
- Nothing yet. Design spec approved and committed:
  `docs/superpowers/specs/2026-09-19-markit-design.md`.

## In progress
- None. Next step is an implementation plan (writing-plans skill),
  then execution on a `feat/` branch.

## Next
- Scaffold Xcode project per the repo layout in the design spec.
- Implement `ClipboardHistoryStore` + `ExclusionList` with unit tests
  first (TDD).
- Implement `SelectionWatcher`, `HotkeyManager`, `StatusBarController`,
  SwiftUI views.
- Manual test pass per the spec's checklist.
- Raul: sign, notarize, and cut the first GitHub Release (requires his
  Apple Developer credentials — not something done in an agent
  session).
