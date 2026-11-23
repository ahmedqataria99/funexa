# Furnexa Current Checkpoint

**As of:** 2026-11-23  
**Inspection mode:** read-only except for creation of the three handover documents. No tests, analysis, builds, packaging, database opens, cleanup or process termination were performed for this checkpoint.

## Exact Latest Checkpoint

The latest relevant work investigated (1) the blank/gray Demand Intelligence forecast chart and (2) a PyInstaller child process left listening after Furnexa closes.

| Item | Status | What changed / what was verified |
|---|---|---|
| Forecast chart implementation | PARTIALLY COMPLETED | `demand_forecast_panel.dart` contains a custom `CustomPainter` rendering actual and forecast series, a 90-day history window, legends, axes, hover tooltip and invalid/empty states. A widget test file checks chart widget/legend/semantics and summary states. No saved result verifies the latest chart actually paints visible pixels in the running Windows UI. |
| Blank/gray chart in actual Furnexa | NOT TESTED | Prior acceptance says Demand Intelligence and historical chart were not opened/visually checked. No post-edit render/screenshot evidence exists. Current compiled Flutter bundle predates chart source. |
| Process-tree code change | PARTIALLY COMPLETED | `local_ai_process_bridge.dart` now creates a Windows Job Object, assigns the started process, and calls `TerminateJobObject` on stop. App lifecycle invokes `stop()` on detached/dispose. This is code evidence only. |
| Post-close process IDs | FAILED (prior runtime smoke) / NOT TESTED (latest code) | Saved app smoke: after Furnexa exited, launcher PID `20136` and worker PID `10100` remained with port `62436`; the harness later stopped those two smoke-owned processes. The Job Object source edit occurred later. No post-edit process IDs were captured. Current read-only process snapshot found no matching Furnexa process. |
| Loopback port release | FAILED (prior runtime smoke) / NOT TESTED (latest code) | App smoke recorded port `62436` still listening after close; it was released only after the test harness cleanup. Independent smoke recorded `54070` still listening and service exit code 1. Current snapshot found no listener on either historical port, but did not exercise the edited shutdown behavior. |
| Runtime health and forecasts | COMPLETED for prior artifact | Saved app smoke records authenticated health HTTP 200 and 7/14/30-day forecasts using `ets_guarded`, 365 observations, and 7/14/30 points. This does not verify the current source edits. |
| Focused Flutter verification | FAILED before test execution | Latest saved bridge, Sales Returns, Purchase Returns and Returns workflow runs exit 1 before tests because Flutter crashes copying `sqlite3.dll` to `build/native_assets/windows/sqlite3.dll` (`PathExistsException`, OS error 183, destination already exists). |
| Final report before this handover | NOT PRESENT | No `FURNEXA_COMPLETE_PROJECT_HANDOVER.md`, `FURNEXA_CURRENT_CHECKPOINT.md` or `FURNEXA_FINAL_FILE_INVENTORY.md` existed before this request. This document and the other two are the final handover reports. |

### Changes That Can Be Attributed

Current code has the Windows Job Object process-tree termination path and the chart custom painter. The chart and bridge Dart files have filesystem timestamps of 2026-11-23 18:06 UTC. The available evidence does not establish which exact agent operation produced each edit or whether the Job Object code was run. It is therefore accurate to say the code was changed, not that the prior failure was fixed.

The Release `data\app.so` is timestamped 2026-11-23 17:34 UTC, before those Dart source edits; the app executable is dated 2026-11-22. The latest source is not included in the current Flutter Release payload. The current ZIP contains that same older `app.so`.

### HTTP 408 and Interrupted Operations

No explicit HTTP 408 result was found in the saved project reports/logs inspected. The available test logs instead show Flutter native-assets crashes. `.vscode\tasks.json` contains labels recording earlier stalled-test inspection and process-stop tasks, but there is no corresponding complete agent-operation transcript in the inspected project evidence. The reason, response code, and completion state of any interrupted agent operation cannot be independently established; do not infer a 408 or successful completion.

## Release and Database State

- Release: `build\windows\x64\runner\Release\`
- App executable: `build\windows\x64\runner\Release\furnexa.exe`, 70,656 bytes; timestamp 2026-11-22 21:49 UTC.
- Flutter payload: `build\windows\x64\runner\Release\data\app.so`, timestamp 2026-11-23 17:34 UTC, older than the current chart/bridge Dart sources.
- Canonical AI runtime: `build\windows\x64\runner\Release\ai_runtime\furnexa_ai_service.exe`, 162,104,184 bytes; timestamp 2026-11-23 18:28 UTC.
- Extra stale runtime artifacts also exist under `ai_runtime\furnexa_ai_service\` and `ai_runtime\_internal\`; the current folder is not the previously documented single-executable layout.
- Portable archive exists: `build\release\furnexa-windows-x64-portable.zip`, 465,989,919 bytes, timestamp 2026-11-23 18:42 UTC. It includes both the canonical and nested duplicate service executable, old `data\app.so`, and zero database/backup entries. It is not current with the latest Flutter edits.
- Installer: none found/reported.
- Release database exclusion: PASS; no `.db`, `.sqlite`, `.sqlite3` or `.bak` file in the Release tree. ZIP inspection also found zero such entries.
- Local database path: `%LOCALAPPDATA%\Furnexa\furnexa.db`. Filesystem metadata only was inspected. Existing pre-synthetic backup paths are recorded in the complete handover. No database contents were opened or changed here.
- Synthetic database during this task: NOT MODIFIED. The existing app smoke evidence is read-only; the current checkpoint did not access the database.

## Verification Inventory

Exact exit code is shown only where the saved evidence explicitly contains it. “Not recorded” is not a pass.

| Test / verification | Latest result | Exact exit code | Evidence |
|---|---|---:|---|
| Dart analysis | Previous scoped analysis PASS; not rerun | Not recorded in report | Completion report: no analyzer errors; broad analysis had 139 `info` diagnostics. Not evidence for later Job Object/chart edits. |
| Flutter Demand Intelligence widget tests | NOT TESTED | N/A | `test/demand_forecast_panel_test.dart` exists; latest Flutter runner did not reach tests due the native-assets failure. |
| Flutter AI bridge/payload/packaged runtime group | FAILED before tests | 1 | `FURNEXA_TEST_AI_BRIDGE.txt`; `sqlite3.dll` copy collision, OS error 183. |
| Sales Returns scrolling widget test | FAILED before tests | 1 | `FURNEXA_TEST_SALES_RETURNS.txt`; runner crash before test entry. Positive-scroll assertion is present but unverified. |
| Purchase Returns scrolling widget test | FAILED before tests | 1 | `FURNEXA_TEST_PURCHASE_RETURNS.txt`; same native-assets failure before test entry. |
| Return workflow/migration regressions | FAILED before tests | 1 | `FURNEXA_TEST_RETURNS_WORKFLOW.txt`; same native-assets failure before test entry. |
| Earlier Sales read-scope security tests | Previous PASS | Not recorded | Security-fix report: 9 tests passed in isolated temporary copy. |
| Earlier Sales Return/QC/posting regressions | Previous PASS | Not recorded | Security-fix report: 1 legacy QC + 2 receipt/QC + 2 posting/idempotency regressions passed in isolated copy. |
| Earlier AI bridge/payload tests | Previous PASS | Not recorded | Bridge report: 6 tests passed; later runtime-blocker report: combined 26 Flutter tests passed. Earlier results do not cover current source edits. |
| Earlier historical dataset builder tests | Previous PASS | Not recorded | Historical dataset report: 8 Dart tests passed. |
| Earlier return stock reconciliation matcher tests | Previous PASS | Not recorded | Report: 14 focused payload matcher tests passed. |
| Synthetic factory end-to-end integration | Previous PASS | Not recorded | Report: 1 isolated synthetic integration test passed; foreign-key checks and 365-day expected totals asserted there. |
| Python AI suite | PASS, latest saved result | 0 | `FURNEXA_PYTHON_TESTS.txt`: `81 passed, 3 warnings in 32.36s`; includes Demand Intelligence and local service/forecast tests. |
| Python local AI service tests | Included in latest suite | 0 (suite) | Saved suite lists service auth/loopback, payload, missing-vs-zero and dataset tests passed. Earlier report specifically recorded 10 service tests. |
| PyInstaller packaging | PASS, prior build | 0 | `FURNEXA_FINAL_BUILD_COMPLETION_REPORT_V1.md` records success; current packaged executable exists. No current packaging command was run. |
| Flutter Windows Release build | PASS, prior documented build | 0 | `FURNEXA_WINDOWS_BUILD_RELEASE.txt` records standard build exit 0. Existing executable timestamp precedes current Dart edits. |
| Packaged 7-day forecast | PASS, prior artifact | N/A | App smoke: HTTP 200, model `ets_guarded`, 7 points, 365 observations. |
| Packaged 14-day forecast | PASS, prior artifact | N/A | App smoke: HTTP 200, model `ets_guarded`, 14 points, 365 observations. |
| Packaged 30-day forecast | PASS, prior artifact | N/A | App smoke: HTTP 200, model `ets_guarded`, 30 points, 365 observations. |
| Actual Demand Intelligence chart rendering | NOT TESTED | N/A | No page/chart screenshot or pixel evidence; acceptance report explicitly did not exercise the page. |
| Development service startup | Previous PASS | N/A | Runtime-blocker report: `.venv` service stayed running and authenticated health became ready. |
| Packaged service startup/health | PASS, prior artifact | N/A | App smoke: child auto-started and authenticated health returned HTTP 200. |
| Service shutdown after Furnexa close | FAILED, prior code path; new path NOT TESTED | N/A | `FURNEXA_APP_RUNTIME_SMOKE.txt`: launcher/worker PIDs 20136/10100 survived. Current Job Object code has no post-change smoke. |
| Process-tree termination | FAILED, prior code path; new path NOT TESTED | N/A | Prior app and standalone runtime evidence shows surviving PyInstaller worker. No current test. |
| Loopback port release after app close | FAILED, prior code path; new path NOT TESTED | N/A | Port 62436 / 54070 remained until separate cleanup; no post-change release proof. |
| Current process/port snapshot | No matching app/port at inspection time | N/A | Read-only process/listener query; does not validate shutdown implementation. |
| Database path and backup inventory | PASS (metadata-only) | N/A | `%LOCALAPPDATA%\Furnexa\furnexa.db` and pre-synthetic backup/displaced-file names listed; no DB content opened. |
| Database isolation in Release/ZIP | PASS | N/A | Recursive Release file scan and ZIP entry scan found zero database/backup files. |
| Synthetic seed foreign-key/admin checks | Previous PASS in isolated test | Not recorded | Seed test asserts `foreign_key_check` empty and old administrator password hash preserved. Current live database was not checked. |
| Full manual UI acceptance | NOT TESTED | N/A | Native Flutter controls were not available to earlier Windows UI automation; login and module workflows were not exercised. |

## Remaining Issues and Prioritized Actions

1. **P0 - Child-process shutdown is not proven.** Prior smoke left the PyInstaller launcher/worker and loopback port alive; a Windows Job Object implementation now exists but is newer than the compiled Flutter payload and has no post-edit evidence. Next action: after resolving the test/build environment blocker, rebuild from the current source, launch the rebuilt app, close it normally, record process IDs and port ownership before cleanup, and require both the launcher/worker tree and listener to disappear without harness cleanup.
2. **P0 - Latest chart rendering is unverified.** Source painter and widget tests exist, but no current executable uses them and no actual chart pixels have been observed. Next action: rebuild with current source, open Demand Intelligence using authorized access to the existing data, and verify historical and forecast lines, dates, scale, legend, and empty/error states; record a screenshot or automated render evidence.
3. **P1 - Flutter test infrastructure blocks verification.** Latest runs exit 1 before tests due `PathExistsException` while copying `sqlite3.dll` (OS error 183). Next action: investigate the native-assets cache/collision without deleting user data, then run focused AI/chart/returns tests and capture exact summaries. This handover did not attempt cache repair.
4. **P1 - Release/ZIP are stale and contain duplicate AI runtime files.** The current Flutter bundle predates the chart/bridge source timestamps; the ZIP contains duplicate nested service files and does not have the documented lean layout. Next action: after source verification, rebuild Release, stage one canonical runtime only through the supported packaging script, verify icon/metadata and absence of SQLite databases, then regenerate the portable archive only if authorized.
5. **P1 - Synthetic replacement state is not independently proven live.** Seeder code and an isolated test document preservation and integrity, but the live database was intentionally not opened here. Next action: only under an explicitly authorized read-only procedure, verify path/version/integrity and seed state without running the replacement script; do not expose credentials or mutate the database.
6. **P2 - Full manual workflow and business readiness remain open.** Earlier acceptance did not test login, filters, module navigation or in-app forecast trigger. AI reports state real-model readiness is blocked absent an approved representative snapshot and real holdout validation. Next action: separately authorize interactive acceptance and data-governance review; do not interpret synthetic metrics as operational accuracy.
7. **P2 - AI root lacks version-control metadata.** `D:\avatar\vs code\My APPS\furnixa-ai` has no `.git`; exact modified/untracked status cannot be supplied from Git. Next action: establish a controlled repository baseline or provide an authoritative file manifest before treating its file delta as complete.

**Most important remaining blocker:** the app-owned Python process tree has a recorded post-close leak and the newer Job Object fix has not been validated in a Release that actually contains the latest Flutter source. No next action above was executed.