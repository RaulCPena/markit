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
  - All components integrated; `os_log` now covers the failure paths the spec's
    Error handling section calls for (login-item registration, global hotkey
    registration, event-tap creation). Corrupt-history recovery is silent by
    design — the spec only requires starting empty rather than crashing.

- **Task 9:** Version metadata, release script, and automated verification
  - Version metadata confirmed: CFBundleShortVersionString=1.0.0, CFBundleVersion=1, LSUIElement=true ✓
  - Release script written (`scripts/release.sh`) and made executable ✓
  - Automated verification complete:
    - `bash -n scripts/release.sh` - syntax check passed ✓
    - `plutil -p Resources/Info.plist` - version metadata verified ✓
    - `swift build` - build complete ✓
    - `swift test` - 14 tests passed (ClipboardHistoryStore 5, ExclusionList 4, SelectionGate 5) ✓

- **Final review fix wave (post-Task 9):** all findings from the whole-branch review applied
  - `SelectionWatcher.startIfNeeded()` + re-arm on `didBecomeActive`, so the event tap is
    created after Accessibility permission is granted (previously dead until relaunch)
  - Removed the force-cast in the Accessibility path (CFTypeID-guarded, can no longer trap)
  - Added `os_log` for hotkey-registration and event-tap-creation failures
  - Rewrote `scripts/release.sh`: notarize + staple the `.app` before building the dmg,
    dropped `--deep`, early `MARKIT_SIGNING_IDENTITY` guard, `/Applications` symlink in the
    dmg, `swift test` gate before the release build
  - `.build/` added to `.gitignore`
  - `OnboardingWindowController` now clears its window reference on a manual close
  - Removed the placeholder test file; documented magic numbers in `SelectionWatcher`
  - Spec updated to match the shipped flat "Clipboard History" menu item, the picker-only
    exclusion UI, and the corrected notarization order

## In progress
- None. All automated tasks complete.

## Known limitations / deferred from final review

Known, deliberately deferred, not blocking the v1 branch. Recorded so they aren't
rediscovered as surprises later.

- No "Clear History" action in the menu — `history.json` is plaintext and there is currently
  no way to clear it from the UI.
- `StatusBarController.hotkeyManager` is stored but never used.
- The status bar icon reflects Accessibility trust state only, not the auto-copy-off state.
- `isAutoCopyEnabled` is in-memory only; it resets to on across relaunches.
- Several `MarkItCore` types are `public` when only `AppDelegate` needs to cross the module
  boundary — a tidy-up opportunity, not a bug.
- Escape-to-dismiss on the history popup relies on `NSPanel` defaults and should be confirmed
  in the manual QA pass rather than assumed.
- No background poll for the case where Accessibility is granted in System Settings with no
  subsequent MarkIt interaction; the `didBecomeActive` re-arm covers the normal flow.

## Open Items (Raul to complete)
- Step 2: App icon — done on `feat/app-icon` (`Resources/AppIcon.png` source, `Resources/AppIcon.icns` generated from it, `CFBundleIconFile` set, both build scripts copy it). Confirm it looks right in Finder/DMG on the next release build.
- Step 5: Run full manual QA checklist from spec's Testing Plan
- Step 5: Cut signed/notarized release (requires Apple Developer credentials):
  - Set MARKIT_SIGNING_IDENTITY environment variable
  - Run `scripts/release.sh 1.0.0` to build, sign, create DMG, notarize, and staple
  - Verify Gatekeeper: `spctl -a -vv build/MarkIt.app`
  - Create GitHub Release with notarized DMG
