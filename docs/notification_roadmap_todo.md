# Notification Roadmap TODO

Last updated: 2026-02-10

## Goal
Daily, useful expiry reminders with snooze and deep-linking into the expiring view.

## Steps
1. Dynamic expiring filter window on main page (`N` days) with local persistence.
   - Status: `done`
2. Daily summary notification in the morning with compact message format.
   - Example: `3 items expire today (Milk, Yogurt +1 more)`
   - Status: `done`
3. Notification actions and deep-link behavior.
   - Snooze to noon / late afternoon.
   - Tap notification opens expiring items view.
   - Status: `done`

## Notes
- Keep MVP-friendly defaults and avoid platform-heavy complexity first.
- Prefer Android-first implementation details; defer iOS-specific polish.

## QA Tools Backlog
1. Debug action: schedule daily summary for +1 minute.
   - Status: `pending`
2. Debug panel: show currently scheduled notification IDs and trigger times.
   - Status: `pending`
3. Debug action: cancel only summary notifications (without clearing item reminders).
   - Status: `pending`
