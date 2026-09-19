# MarkIt — status

## Built (Task 1-9)
- **Tasks 1-8:** Fully implemented and committed
  - Scaffolded Swift Package project structure
  - Implemented `ClipboardHistoryStore` with unit tests (5 tests passing)
  - Implemented `ExclusionList` with unit tests (4 tests passing)
  - Implemented `SelectionGate` with unit tests (5 tests passing)
  - Implemented `SelectionWatcher` (background selection detection)
  - Implemented hotkey manager and popup history window
  - Implemented status bar menu and menu items
  - Implemented excluded apps window and accessibility permission manager
  - All components integrated with logging and error handling

- **Task 9:** Version metadata, release script, and automated verification
  - Version metadata confirmed: CFBundleShortVersionString=1.0.0, CFBundleVersion=1, LSUIElement=true ✓
  - Release script written (`scripts/release.sh`) and made executable ✓
  - Automated verification complete:
    - `bash -n scripts/release.sh` - syntax check passed ✓
    - `plutil -p Resources/Info.plist` - version metadata verified ✓
    - `swift build` - build complete ✓
    - `swift test` - 15 tests passed (ClipboardHistoryStore 5, ExclusionList 4, SelectionGate 5, MarkItCore 1) ✓

## In progress
- None. All automated tasks complete.

## Open Items (Raul to complete)
- Step 2: Add app icon (design asset) — produce `.icns` file and add `CFBundleIconFile` to Info.plist
- Step 5: Run full manual QA checklist from spec's Testing Plan
- Step 5: Cut signed/notarized release (requires Apple Developer credentials):
  - Set MARKIT_SIGNING_IDENTITY environment variable
  - Run `scripts/release.sh 1.0.0` to build, sign, create DMG, notarize, and staple
  - Verify Gatekeeper: `spctl -a -vv build/MarkIt.app`
  - Create GitHub Release with notarized DMG
