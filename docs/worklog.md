# Worklog

Last updated: 2026-02-10

Use this log for day-to-day progress so history stays easy to query later.

## Entry Template
- Date:
- Task:
- Result:
- Errors:
- Hardships/Operational Issues:
- Fixes:
- Tests:
- Coverage:

## Entries
- Date: 2026-02-10
- Task: Create persistent context archive and project history documents.
- Result: Added/updated `docs/project_state.md` and `docs/project_history.md`.
- Errors: None.
- Hardships/Operational Issues: None.
- Fixes: N/A.
- Tests: N/A (documentation change only).
- Coverage: N/A.

- Date: 2026-02-10
- Task: Persist non-app engineering issues for continuity across sessions.
- Result: Added explicit logging fields and history section for environment/tooling friction.
- Errors: Repeated command interruptions during long-running tasks.
- Hardships/Operational Issues:
  - PATH setup drift (`flutter`/`adb` not recognized).
  - Terminal session restarts causing command context loss.
  - Permission prompt freeze/stuck approval flow in Codex runs.
- Fixes:
  - Standardized PATH/JAVA setup notes in docs.
  - Added this persistent non-app issue log format.
- Tests: N/A (documentation change only).
- Coverage: N/A.

- Date: 2026-02-10
- Task: Add AI-assisted expiry extraction with OCR-text first and image fallback.
- Result:
  - Added AI client with Responses API integration (`gpt-4.1-mini`).
  - Added debug scan status labels (`AI: disabled/no date/failed/text used/image used`).
  - Added image-based AI fallback for difficult packaging when OCR parsing is weak.
- Errors:
  - `AI: disabled` shown initially due missing runtime API key injection.
  - Wireless device connection dropped intermittently during testing.
  - OpenAI usage page did not show immediate request usage (dashboard delay confusion).
- Hardships/Operational Issues:
  - Environment variable setup in Windows terminals was inconsistent between sessions.
  - Needed full rerun with `--dart-define` (hot reload not enough for config changes).
- Fixes:
  - Set `OPENAI_API_KEY` at user environment level and reran app with `--dart-define`.
  - Added explicit runtime scan feedback labels to verify whether AI path was actually used.
  - Added image fallback so hard cases (e.g., water bottle date print) can still be read.
- Tests:
  - Added unit tests for AI client text parsing, image request path, and failure/disabled states.
  - Full suite executed successfully.
- Coverage:
  - 97.27% (249/256) after image-fallback additions.
- User Test Outcomes:
  - Wippy item: AI returned correct date and reported AI usage.
  - Water bottle: OCR remained hard, but AI image fallback succeeded (`AI: image used`).
