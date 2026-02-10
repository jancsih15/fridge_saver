# Project History

Last updated: 2026-02-10

## Timeline (Commits)
- `98fbc9e` - Initial Flutter app scaffold
- `b4a6a62` - MVP inventory flow with local persistence and tests
- `dc1cfd9` - Fix add-item keyboard overflow on small screens
- `205fbe3` - Add barcode scanning flow with `mobile_scanner`
- `531556e` - Improve Open Food Facts lookup feedback and not-found handling
- `c60adc0` - Add edit/delete item flows and strengthen controller tests
- `79a26d1` - Add high-value repository/model coverage tests
- `0c2e043` - Add undo support for swipe delete with snackbar action

## Task Log (Major Milestones)
1. Environment setup
- Actions:
  - Installed Flutter SDK and Android tooling on Windows
  - Configured JAVA_HOME/JDK for Gradle builds
  - Set up wireless Android debugging path
- Common errors and fixes:
  - `CreateFile failed 5` / sandbox restrictions: reran with elevated permissions
  - `JAVA_HOME is not set`: configured Android Studio JBR
  - `adb not recognized`: added platform-tools to PATH

2. MVP inventory foundation
- Actions:
  - Added model, controller, repository, list/add views
  - Wired Hive persistence
- Result:
  - Offline item CRUD started with add + list + expiring filter

3. UX stabilization
- Issue:
  - Add-item keyboard overflow on mobile
- Fix:
  - Scrollable, keyboard-safe form layout

4. Barcode feature
- Actions:
  - Added scanner screen and barcode parser utility
  - Barcode field scan button integration
- Issue:
  - Scanner opened without camera permission behavior on Android
- Fix:
  - Added `android.permission.CAMERA` in manifest
  - Added scanner error UI and visible frame overlay

5. Open Food Facts integration
- Actions:
  - Barcode-based product lookup and name autofill
  - Added user feedback messages
- Issue:
  - Missing products reported as failure in some cases
- Fix:
  - Treated HTTP 404 as `notFound`, kept server/network as `failed`

6. Editing, deletion, undo
- Actions:
  - Added edit flow (prefilled form)
  - Added swipe-delete and undo window via snackbar
- Result:
  - Core day-to-day usability significantly improved

7. Test hardening and coverage push
- Actions:
  - Added repository tests against real `HiveInventoryRepository`
  - Added model serialization tests (`FridgeItem`)
  - Expanded API edge-case tests
  - Added controller branch tests
- Result:
  - Reached and validated very high coverage baseline

8. OCR expiry-date experiment (in progress, uncommitted)
- Actions:
  - Added ML Kit OCR + image capture flow for expiry date suggestion
  - Added parser with multiple date formats and keyword-based ranking
  - Added candidate confirmation sheet in UI
  - Added real-world OCR sample tests (Mizse/Wippy/text examples)
- Current status:
  - Tests passing with coverage 97.92% in current working tree
  - Pending commit

## Error/Fix Register (Condensed)
- `MissingPluginException` after adding native plugin
  - Cause: app not fully rebuilt
  - Fix: `flutter clean && flutter pub get && flutter run`

- OCR parsed wrong date from noisy image
  - Cause: OCR quality/noise + parser heuristics
  - Fixes applied:
    - comma separator support
    - keyword-aware ranking
    - user confirmation step for suggested date

- Far-future year not accepted
  - Cause: parser horizon cap too short (+5y)
  - Fix: increased to +30y with tests

## Operational Issues (Non-App)
- PATH inconsistency across shells
  - Symptoms: `flutter` and `adb` intermittently not recognized.
  - Mitigation: keep SDK paths documented and verify with new terminal session.

- Terminal/session restarts during setup
  - Symptoms: command context and environment assumptions lost.
  - Mitigation: re-run quick diagnostics (`where flutter`, `flutter doctor`, `adb devices`) after restart.

- Codex permission prompt freeze/stuck approval flow
  - Symptoms: long-running task appears blocked even after user response.
  - Mitigation: stop the run, resume in a fresh command, and keep work checkpoints in docs.

## Coverage Snapshots
- Earlier stabilized baseline: 100% (131/131)
- With OCR parser module added: 97.92% (188/192)
  - Remaining misses are defensive/default branches in expiry parser

## Notes for Future Sessions
- Keep this file + `docs/project_state.md` updated after each major feature.
- Record coverage number after every significant test run.
- When context is reset, resume from these docs first.
