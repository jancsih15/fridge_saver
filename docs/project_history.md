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

## Recent Error/Fix Register
- `MissingPluginException` after plugin changes
  - Fix: full restart (`flutter clean && flutter pub get && flutter run`)

- Scanner captured QR website links as barcode values
  - Cause: parser accepted any non-empty string.
  - Fix: restricted scanner parser to numeric barcode-like values (8-14 digits).

- Products previously found later returning not found after provider/caching changes
  - Cause: cached `notFound` entries blocked fresh provider lookup.
  - Fix: ignore cached `notFound` and cache only successful `found` responses.

## Coverage Snapshots
- Earlier baseline after hardening: 100% (131/131)
- OCR/AI expansion phase: ~97-98%
- Current (after provider fallback + cache + bugfixes): 94.67% (426/450)

## Operational Notes
- PATH/JAVA/ADB setup can drift across terminal restarts.
- Permission prompt freezes can occur; restart run and continue from docs/worklog.
- Use targeted tests during iteration; full coverage run before commit/push.

