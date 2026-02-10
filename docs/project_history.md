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
- `18aee0a` - Docs archive/log foundation
- `3395d5a` - OCR-assisted expiry suggestion flow
- `fa748bb` - AI expiry fallback + debug statuses
- `23a0b63` - Exact duplicate batch merge on add/edit
- `68abd62` - Free barcode fallback/settings/cache + scanner/cache fixes

## Major Milestones
1. Core offline inventory shipped (CRUD + expiring-soon + Hive persistence).
2. Barcode scan shipped and stabilized for Android camera permission behavior.
3. Open Food Facts product-name autofill added.
4. Edit/delete/undo usability completed.
5. Coverage hardening added for controller/repository/model/API logic.
6. OCR expiry recognition added with heuristic parser + candidate confirmation.
7. Optional AI expiry extraction added (text and image fallback).
8. Duplicate batch merge behavior implemented for realistic inventory handling.
9. Multi-provider free barcode lookup fallback + cache + settings UI implemented.
10. Local notifications kickoff + settings hub refactor implemented.
11. Daily summary notification flow completed with tap deep-link and snooze actions.

## Recent Error/Fix Register
- `MissingPluginException` after plugin changes
  - Fix: full restart (`flutter clean && flutter pub get && flutter run`)

- Scanner captured QR website links as barcode values
  - Cause: parser accepted any non-empty string.
  - Fix: restricted scanner parser to numeric barcode-like values (8-14 digits).

- Products previously found later returning not found after provider/caching changes
  - Cause: cached `notFound` entries blocked fresh provider lookup.
  - Fix: ignore cached `notFound` and cache only successful `found` responses.

- Android build failed after notification dependency integration
  - Cause: missing core library desugaring config for notification dependency.
  - Fix: enabled desugaring in app Gradle config and added `desugar_jdk_libs`.

- Edge/web list appeared stale after add until filter toggled
  - Cause: notification sync path could interfere on unsupported platforms.
  - Fix: web-safe scheduler creation and fail-safe scheduling error handling.

- Debug notification scheduled for ~1 minute did not reliably appear
  - Cause: inexact scheduling/idle behavior variability on device.
  - Fix: debug action changed to immediate local notification send.

- Notification tap stayed on Debug Tools and did not navigate to expiring items
  - Cause: notification response callback not wired to app navigation/filter state.
  - Fix: added app navigator callback from scheduler to pop to inventory and apply Today filter.

- Notification snooze actions gave no clear confirmation
  - Cause: no confirmation signal after action scheduling.
  - Fix: added explicit snooze confirmation notification with relative day text (today/tomorrow/date).

## Coverage Snapshots
- Earlier baseline after hardening: 100% (131/131)
- OCR/AI expansion phase: ~97-98%
- Current (after provider fallback + cache + bugfixes): 94.67% (426/450)
- Current after notification and settings refactor: 88.29% (445/504)

## Operational Notes
- PATH/JAVA/ADB setup can drift across terminal restarts.
- Permission prompt freezes can occur; restart run and continue from docs/worklog.
- Use targeted tests during iteration; full coverage run before commit/push.
