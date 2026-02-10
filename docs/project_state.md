# Project State (Context Archive)

Last updated: 2026-02-10

## Product Goal
Mobile MVP to reduce food waste by tracking items and expiration dates, with fast UX and offline-first behavior.

## Stack
- Flutter (Android-first)
- State: Provider + ChangeNotifier
- Local persistence: Hive
- Barcode scan: mobile_scanner
- Product lookup: Open Food Facts API (`http`)
- OCR expiry experiment: image_picker + google_mlkit_text_recognition (in progress, not yet committed)

## Current Architecture
- `lib/features/inventory/domain/fridge_item.dart`
- `lib/features/inventory/data/inventory_repository.dart` (Hive repo)
- `lib/features/inventory/data/open_food_facts_client.dart`
- `lib/features/inventory/presentation/inventory_controller.dart`
- `lib/features/inventory/presentation/inventory_screen.dart`
- `lib/features/inventory/presentation/add_item_screen.dart`
- `lib/features/inventory/presentation/barcode_scanner_screen.dart`
- `lib/features/inventory/presentation/barcode_value_parser.dart`
- `lib/features/inventory/presentation/expiry_date_parser.dart` (new, in progress)

## Implemented Features
- Add fridge items (name, optional barcode, qty, date, location)
- Edit existing items
- Delete with swipe gesture
- Undo delete via snackbar action + restore logic
- Expiring-soon filter (within 3 days)
- Barcode scan flow
- Open Food Facts lookup + user feedback states
- Local persistence (Hive)

## Testing & Quality
- Unit tests: controller, parser(s), Open Food Facts client, model serialization, real Hive repo implementation
- Latest run: `flutter test --coverage` passed
- Coverage: 97.92% (188/192) with current uncommitted OCR changes
- Remaining uncovered lines: defensive/default branches in `lib/features/inventory/presentation/expiry_date_parser.dart`

## Current In-Progress (Uncommitted)
- OCR-assisted expiry date suggestions in `AddItemScreen`
- `expiry_date_parser` with:
  - comma/dot/slash/hyphen separators
  - keyword-aware scoring (`EXP`, `best before`, Hungarian variants)
  - candidate list + explicit user confirmation sheet
  - 30-year future horizon
- Tests with OCR-like sample strings (Mizse/Wippy examples)

## Known Environment Notes
- Flutter SDK path: `C:\dev\flutter`
- Android SDK path: `C:\Users\Admin\AppData\Local\Android\Sdk`
- JAVA_HOME set to Android Studio JBR
- Some generated plugin registrant files can change when dependencies change:
  - `linux/flutter/generated_plugin_registrant.cc`
  - `linux/flutter/generated_plugins.cmake`
  - `windows/flutter/generated_plugin_registrant.cc`
  - `windows/flutter/generated_plugins.cmake`
  - `macos/Flutter/GeneratedPluginRegistrant.swift`

## Runbook
- Run app on Android device:
  - `flutter run -d <device_id>`
- Full rebuild after plugin changes:
  - `flutter clean`
  - `flutter pub get`
  - `flutter run -d <device_id>`
- Test + coverage:
  - `flutter test --coverage`

## Next Recommended Work
1. Commit current OCR expiry feature changes.
2. Add widget/integration test for OCR suggestion flow (mocking analysis layer).
3. Add local notifications for upcoming expiration.
4. Add data export/import backup.

## Session Bootstrap
When a new session starts:
1. Read `docs/project_state.md` first for current architecture and in-progress work.
2. Read `docs/project_history.md` for timeline and previous fixes.
3. Append new entries to `docs/worklog.md` for each task delivered.
