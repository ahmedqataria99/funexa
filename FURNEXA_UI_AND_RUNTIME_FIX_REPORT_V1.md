# Furnexa UI and Runtime Fix Report V1

## Navigation

- Demand Intelligence is already represented by one navigation entry in the Furnexa shell.
- The entry is positioned immediately after Dashboard and retains the existing `SALES_VIEW` permission check.
- The label remains `ذكاء الطلب`, the existing icons/active styling are preserved, and RTL/locale behavior is unchanged.
- No duplicate entry or user/profile entry was removed.

## Demand Intelligence

- The existing page keeps the Wood & Navy theme, localization, and RTL layout.
- The page hierarchy remains: title and description, filters, horizon selector, summary, chart, and model details.
- Horizon labels remain Arabic: `7 أيام`, `14 يومًا`, and `30 يومًا`.
- Forecast summary values are derived from the selected forecast response: total forecast, daily average, forecast date range, and selected model.
- The chart uses the actual historical and forecast response series. Historical display is limited to the latest 90 days for readability, while the original payload and model input are unchanged.
- Actual and forecast series have separate colors and Arabic legend entries, with a dashed historical/future divider and inspectable hover tooltip.
- Loading, unavailable-service, insufficient-history, invalid-request, and execution-failure messages are presented in Arabic. Technical details remain in bridge diagnostics rather than normal UI text.

## AI Runtime

### Missing environment variable root cause

The packaged executable was previously usable as an independent executable. Because it receives `FURNEXA_LOCAL_AI_PORT` and `FURNEXA_LOCAL_AI_TOKEN` only from its managed parent, direct launch without those variables caused an unsafe startup state. The Python service already validates both variables and exits with controlled codes instead of requiring a hardcoded port.

### Connection-refused root cause

The UI could reach the bridge before the child service had bound the loopback port. The bridge now shares one `_startFuture` across concurrent callers, waits for `/health` during startup, and restarts a terminated child using the exact remembered executable, script, working directory, and ephemeral loopback port.

### Runtime layout

The Release runtime uses the relative location:

```text
furnexa.exe
ai_runtime/
  furnexa_ai_service.exe
```

Furnexa locates the executable relative to `Platform.resolvedExecutable`. Legacy in-place packaged-service lookup was removed. Development mode continues to launch the source service with the existing `.venv` Python executable or configured Python executable.

Furnexa remains the only user-facing application. The AI executable is internal and managed by the Flutter process.

## Sales and Purchase Returns

- Both pages now use a named outer `ScrollController` for a dedicated vertical `SingleChildScrollView`.
- `FurnexaDataTable(verticalScrollable: false)` remains the only internal table behavior, preserving the separate horizontal table scroller and pagination.
- Nested table scrolling and conflicting page/table vertical scroll ownership were removed from the page layout.
- Existing widget tests now assert that a drag produces a positive controller scroll offset.
- Mouse-wheel and touchpad behavior continues to use the same Flutter vertical scrolling surface on Windows.

## Verification

- Targeted Dart analysis: passed for the touched implementation and test files, with only existing style/deprecation info diagnostics.
- Sales Returns widget test: updated with a positive scroll-offset assertion.
- Purchase Returns widget test: updated with a positive scroll-offset assertion.
- Widget test execution: blocked by recurrent Flutter native-assets/cache failures for `sqlite3.dll` (`errno 183`, then missing source cache).
- Python AI tests using the existing `.venv`: **20 passed**, 1 FastAPI/Starlette deprecation warning.
- Windows Release build: blocked in Flutter/CMake native asset assembly; no source-level Dart errors were reported in the focused analysis.
- No SQLite database was intentionally staged in a Release folder during this pass.

## Final Release Status

Final Release path was not produced because the current Windows build remained blocked by native-assets/CMake state. The existing build output remains at:

```text
D:\avatar\vs code\My APPS\furnexa\build\windows\x64\runner\Release\furnexa.exe
```

## Remaining Issues

- The Windows native-assets cache for `sqlite3.dll` requires cleanup/repair before tests and Release builds can complete in this environment.
- Return suites could not execute conclusively in this pass because of that cache blocker.
- Final packaged AI executable staging and live Furnexa launch verification remain pending until the Windows build can complete.
- The existing 11 targeted Dart style/deprecation diagnostics are informational and unrelated to the implementation changes.
