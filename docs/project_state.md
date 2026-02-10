# Project State (Context Archive)

Last updated: 2026-02-10

## Product Goal
Android-first MVP that reduces food waste by tracking items and expiration dates with fast, offline-first UX.

## Stack
- Flutter (Android-first)
- State: Provider + ChangeNotifier
- Local storage: Hive (`fridge_items`, `app_settings`)
- Barcode scan: `mobile_scanner`
- Expiry OCR: `google_mlkit_text_recognition` + `image_picker`
- Optional AI assist: OpenAI Responses API (via `--dart-define=OPENAI_API_KEY=...`)
- Barcode lookup: free Open Facts provider fallback chain + local cache
- Local notifications: `flutter_local_notifications` + timezone support

## Current Architecture
- Domain:
  - `lib/features/inventory/domain/fridge_item.dart`
- Data:
  - `lib/features/inventory/data/inventory_repository.dart`
  - `lib/features/inventory/data/ai_expiry_date_client.dart`
  - `lib/features/inventory/data/barcode_lookup_models.dart`
  - `lib/features/inventory/data/barcode_lookup_provider_client.dart`
  - `lib/features/inventory/data/barcode_lookup_service.dart`
  - `lib/features/inventory/data/barcode_lookup_settings_repository.dart`
  - `lib/features/inventory/data/barcode_lookup_cache_repository.dart`
  - `lib/features/inventory/data/expiration_notification_scheduler.dart`
- Presentation:
  - `lib/features/inventory/presentation/inventory_controller.dart`
  - `lib/features/inventory/presentation/inventory_screen.dart`
  - `lib/features/inventory/presentation/add_item_screen.dart`
  - `lib/features/inventory/presentation/barcode_scanner_screen.dart`
  - `lib/features/inventory/presentation/barcode_value_parser.dart`
  - `lib/features/inventory/presentation/expiry_date_parser.dart`
  - `lib/features/inventory/presentation/barcode_lookup_settings_controller.dart`
  - `lib/features/inventory/presentation/barcode_lookup_settings_screen.dart`
  - `lib/features/inventory/presentation/app_settings_screen.dart`
  - `lib/features/inventory/presentation/debug_tools_screen.dart`

## Implemented Features
- Inventory CRUD (add/edit/delete) with undo delete.
- Expiring-soon filter (within 3 days).
- Duplicate merge logic:
  - Exact duplicate batch (same name+barcode+date+location) merges quantity.
  - Different expiry dates remain separate rows.
- Barcode scan flow with overlay and camera error UI.
- Multi-provider barcode name lookup (free providers) with configurable order/enabled state.
- Barcode lookup cache and settings screen (reorder/toggle/clear cache).
- Settings hub with thematic sections (Barcode Providers, Debug Tools).
- Local expiry reminders:
  - scheduled 2 days before expiration at 09:00 local time,
  - synced on inventory mutations,
  - debug test notification action in Debug Tools.
- Expiry date entry:
  - manual date picker,
  - OCR suggestions,
  - optional user-triggered AI fallback (text then image).

## Quality Snapshot
- Latest test run: full suite passed.
- Latest coverage: 88.29% (445/504).
- Largest remaining misses are in new notification and settings-related branches.

## Known Environment Notes
- Flutter SDK path: `C:\dev\flutter`
- Android SDK path: `C:\Users\Admin\AppData\Local\Android\Sdk`
- `JAVA_HOME` uses Android Studio JBR.
- Run with AI enabled:
  - `flutter run -d <device_id> --dart-define=OPENAI_API_KEY=$env:OPENAI_API_KEY`

## Runbook
- Run app:
  - `flutter run -d <device_id>`
- Full rebuild (if plugins/config seem stale):
  - `flutter clean`
  - `flutter pub get`
  - `flutter run -d <device_id>`
- Tests + coverage:
  - `flutter test --coverage`
- Notification debug test:
  - `Settings -> Debug Tools -> Send test notification now`

## Next Recommended Work
1. Add user-configurable reminder preferences (lead time and reminder hour).
2. Add tests for settings/debug screens and notification scheduler integration.
3. Optional cache TTL policy for found entries (if provider data freshness becomes an issue).

## Session Bootstrap
1. Read `docs/project_state.md`.
2. Read `docs/project_history.md`.
3. Continue appending `docs/worklog.md` per delivered task.
