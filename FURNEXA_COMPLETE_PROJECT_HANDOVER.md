# Furnexa Complete Project Handover

**Checkpoint date:** 2026-11-23  
**Scope:** Read-only inspection of the Furnexa Flutter application and Furnexa AI Python service. This handover did not run tests, Dart analysis, builds, packaging, database queries, or cleanup. Only the three handover documents were created.

## Project Roots

- Flutter application: `D:\avatar\vs code\My APPS\furnexa`
- AI research/service project: `D:\avatar\vs code\My APPS\furnixa-ai`
- The Flutter root is a Git worktree. The sibling AI root has no `.git` directory, so an exact VCS delta for that root cannot be reconstructed.
- `furnexa\furnixa-ai\src\api\local_ai_service.py` is a separate zero-byte workspace file; the real service source used by the build script is in the sibling AI root. Do not treat the zero-byte mirror as the service implementation.

## Project Journey

### Database and Synthetic Factory Data

The developer database replacement utility is `tool/seed_developer_synthetic_factory.dart`, with data generation in `tool/demo_data_seeder.dart`. The replacement workflow is designed to stop if Furnexa is running or SQLite WAL/SHM sidecars exist, copy and SHA-256-verify the current database, generate a separate migrated staging database, seed it, preserve authentication and access data, run foreign-key checks, and only then switch the staged database into the normal local path. A rollback rename is attempted if the final staged rename fails.

The seeder covers factory structure (one factory, sections, workshops, production stages, and raw/WIP/finished/quarantine warehouses), catalog (units, categories, materials, products, variants and BOMs), suppliers and purchase orders/receipts, production routes/orders/material consumption/outputs, customers, sales orders/deliveries/invoices, accounting expenses/journals, and historical sales. The test asserts an idempotent seed, at least three products and customers, two suppliers, 365 distinct posted delivery dates with 1,460 delivery lines, no foreign-key violations, and preservation of the prior administrator password hash. The documented synthetic sales integration fixture additionally covers eligible and ineligible warehouses, posted/unposted deliveries, returns, missing dates, observed zero, and separate units.

The current Windows local database path is `%LOCALAPPDATA%\Furnexa\furnexa.db` (`C:\Users\ahmed\AppData\Local\Furnexa\furnexa.db`). The path resolver also accepts `FURNEXA_DATABASE_PATH`, and migrates/copies a legacy database only if the stable path does not yet exist. Metadata-only inspection found a 3,760,128-byte database file and these pre-synthetic artifacts:

- `C:\Users\ahmed\AppData\Local\Furnexa\furnexa.db.pre-synthetic-20261122T180538268306Z`
- `C:\Users\ahmed\AppData\Local\Furnexa\backups\furnexa-pre-synthetic-20261122T174218Z.db`
- `C:\Users\ahmed\AppData\Local\Furnexa\backups\furnexa-pre-synthetic-20261122T180538268306Z.db`

Only paths, sizes, and timestamps were inspected. No database was opened in this checkpoint, so its live contents, current `user_version`, and integrity are not asserted here. Prior seed and smoke evidence describes 365 posted daily observations spanning 2025-11-23 through 2026-11-22. The seeder preserves the existing system administrator's username, salted password hash, role, permissions, scopes, and user records when replacing the developer data. The seed test checks the administrator hash in its isolated test database. No credentials or permissions were changed during this handover.

Furnexa is offline-first and stores its operational database per Windows user's local application-data area. The Release and portable ZIP do not carry a customer database. Different Windows profiles get different local paths; this is not a hosted multi-tenant service or cloud synchronization boundary. `FURNEXA_DATABASE_PATH` can intentionally override the default. Database backups remain local.

### Furnexa AI Implementation

The Python service is `D:\avatar\vs code\My APPS\furnixa-ai\src\api\local_ai_service.py`, implemented with FastAPI, Pydantic, pandas and NumPy. It binds only to `127.0.0.1`; its port and per-process bearer secret are supplied by the Flutter process through `FURNEXA_LOCAL_AI_PORT` and `FURNEXA_LOCAL_AI_TOKEN`. Authenticated endpoints include `/health`, `/v1/analyze/sales-demand`, `/v1/datasets/sales-historical`, and `/v1/forecast/sales-demand`. Payload size, row count, horizon, identity uniqueness, period, units, quantity equations and missing/zero semantics are validated. Python has no SQLite access, database path, business mutation API, or external-network role.

Flutter owns authorization and queries the local database through `SalesAiPayloadBuilder`. It requires the relevant Sales/Returns/Quality permissions and authorized warehouse scope; accepts only delivered, inventory-posted lines with verified product/variant/base-unit snapshots; pseudonymizes identifiers before sending; preserves missing dates separately from observed zero; and reports exclusions. Accepted Sales Returns reduce demand only when the return/QC/receipt chain and exact matched stock-transfer reference pair reconcile. Rejected, quarantined, pending, unmatched or duplicate evidence does not reduce demand. `HistoricalSalesDatasetBuilder` validates the allow-listed, pseudonymized dataset and returns coverage and data-quality counts.

The service calls the existing forecasting implementation in `src/evaluation/sales_forecasting_optimization_v4.py`, including `_select_conservative`, `_forecast` and guarded ETS. The candidate set includes naive, moving-average, ETS/guarded ETS, Croston and seasonal-naive comparisons. The synthetic first experiment evaluated 24 series over 7/14/30 observed-row horizons using chronological rolling origins; its artifacts explicitly say all 24 series are caution-classified and no model is ready for an operational claim. Reported aggregate errors and selector behavior are synthetic evidence only, not calibrated or commercial accuracy. No model training, business writeback or automatic purchasing/production action is implemented.

The Python evidence suite currently saved in `FURNEXA_PYTHON_TESTS.txt` reports 81 passing tests and three warnings. The local real-sales readiness report says no approved representative snapshot was used for model validation. Separately, a packaged-runtime smoke record queried 365 posted observations read-only from the user's local database for inference; the database was not independently inspected in this handover, so that smoke does not establish an approved, representative real-world evaluation.

### Demand Intelligence UI

Demand Intelligence is a navigation item immediately after Dashboard, gated by existing `SALES_VIEW` permission. The page has warehouse, product, variant/base-product and 7/14/30-day horizon selection; Arabic labels and RTL; and summaries for total forecast, daily average, date range and selected model. It uses actual response history and forecast values, trims the displayed historical series to 90 days, and includes separate historical/forecast colors and legends, a future-boundary divider, quantity/date axes and hover tooltip. Loading, empty, insufficient-history, invalid-response, service-unavailable and request-error states have Arabic copy. The page runs all three forecast horizons and selects the requested horizon's result for presentation.

The chart panel and widget tests exist, including checks for legends, semantics, response summary, zero observations, loading, insufficient data and invalid inputs. However, the actual native Demand Intelligence chart was not navigated to or visually verified in the latest evidence. The earlier portable acceptance report marks the page and historical chart NOT TESTED. The latest source implements a custom painter, but there is no recorded post-edit render test. Thus the original blank/gray chart issue is only **partially addressed in code**; visible chart rendering remains unverified.

### Python Runtime and Process Lifecycle

In development mode, `LocalAiRuntime` prefers `FURNEXA_PYTHON_EXECUTABLE`, otherwise the sibling AI `.venv\Scripts\python.exe`, then `python`; it launches the service script with the AI project root as working directory. Release mode resolves `ai_runtime\furnexa_ai_service.exe` relative to `Platform.resolvedExecutable` (with a nested compatibility lookup). The one-file PyInstaller executable packages FastAPI, Pydantic, Uvicorn, pandas and NumPy; the intended runtime path is `Release\ai_runtime\furnexa_ai_service.exe`. The script `tool/build_windows_release.ps1` performs Flutter build (unless skipped), PyInstaller packaging, Release database-file check, executable icon/version checks, and optional ZIP creation.

The bridge chooses an ephemeral loopback port, generates a random bearer token, passes the environment contract, shares concurrent startup, polls authenticated `/health`, retains bounded stdout/stderr diagnostics, and can restart a terminated service. The application starts the runtime after `runApp` and requests `stop()` on detached lifecycle/dispose.

**Shutdown checkpoint:** a previous app-level smoke recorded Furnexa closing while PyInstaller launcher PID `20136` and worker PID `10100` remained alive on port `62436`; the harness later stopped those exact smoke-owned processes, after which the port was released. An independent runtime smoke recorded launcher exit code 1 and port `54070` still listening. A later source edit added Windows Job Object creation, assignment of the launched process, and `TerminateJobObject` on stop. That source edit is newer than the Flutter `data\app.so` inside the current Release/ZIP. No post-edit app-close process-tree or port-release evidence exists. Therefore shutdown is **partially implemented, not verified or resolved**. A current metadata-only process snapshot found no matching Furnexa process and no listener on those two historical ports; that is not proof of the edited lifecycle behavior.

### Furnexa UI, Returns and Branding

- Sales Returns and Purchase Returns now use a dedicated outer vertical `ScrollController`/`SingleChildScrollView`; the shared data table keeps horizontal scrolling and pagination without owning a competing vertical scroll. Tests assert a positive drag offset, but the latest Flutter test run crashed before entering these tests.
- Sales delivery-history and Returns reads were tightened to enforce warehouse authorization in SQL and bind child rows to verified parent relationships. Administrator unrestricted warehouse behavior is preserved under existing permission checks. The change does not add a factory-scope permission model.
- Furnexa branding includes generated square and transparent PNG icon assets, a multi-resolution ICO embedded through `Runner.rc`, application title `Furnexa`, and Windows metadata `ProductName=Furnexa ERP`, `FileDescription=Furnexa ERP`, version `1.0.0+1`. A prior report records successful icon extraction from an executable.
- These changes include source and tests, but their final combined Windows UI state is not completely revalidated in a fresh build. The database-reset/seed utility code is part of the untracked workspace state; running it is not part of this checkpoint.

### Windows Release and Packaging

The last documented successful Flutter command was `C:\flutter\bin\flutter.bat build windows --release` (exit code 0); a verbose build also recorded `BUILD_EXIT_CODE=0`. The corresponding prior `furnexa.exe` is 70,656 bytes. PyInstaller reported exit code 0 for the one-file Python service. Windows icon extraction and executable metadata were previously checked. The Release must not be assumed to contain all current source changes.

Current Release directory:

`D:\avatar\vs code\My APPS\furnexa\build\windows\x64\runner\Release`

- App: `furnexa.exe`
- Canonical AI executable: `ai_runtime\furnexa_ai_service.exe`
- Flutter payload: `data\app.so`
- The current `data\app.so` timestamp is 2026-11-23 17:34 UTC. The chart and process-bridge Dart sources are timestamped 18:06 UTC, so the current Release Flutter payload predates those edits. The `furnexa.exe` file itself is timestamped 2026-11-22 21:49 UTC.
- The packaged AI executable is timestamped 2026-11-23 18:28 UTC. Release also contains stale/duplicate `ai_runtime\furnexa_ai_service\furnexa_ai_service.exe` (42,698,331 bytes) and `_internal`/nested runtime content in addition to the canonical executable. This does not match the clean one-executable runtime layout described by earlier reports.
- No `.db`, `.sqlite`, `.sqlite3` or `.bak` database file was found in the Release tree.

A portable ZIP exists at `D:\avatar\vs code\My APPS\furnexa\build\release\furnexa-windows-x64-portable.zip`, size 465,989,919 bytes, timestamp 2026-11-23 18:42 UTC. Its 24,488 entries include `furnexa.exe`, `data\app.so`, the canonical AI executable and the duplicate nested AI executable. Archive inspection found zero database/backup entries. It packages the same stale Flutter payload and must not be called current for the later chart/Job Object changes. Prior conflicting reports alternately say no ZIP existed and that a ZIP was extracted; the current filesystem proves one exists now. No installer was found or reported.

## Overall Checkpoint

The core offline ERP, synthetic demo-data tooling, local read-only AI boundary, historical dataset validation, synthetic forecasting experiments, Demand Intelligence interface source, returns scrolling changes and Furnexa branding are implemented to varying degrees. The Python suite and an earlier Windows Release/inference path have recorded successful results. The project is **not at final acceptance**: the latest chart rendering is unverified, the new Windows process-tree termination path is unverified, Flutter tests are blocked before execution by a repeated SQLite native-assets copy collision, and the current Release/ZIP does not contain the latest Dart changes. Real-world model validation and full manual UI acceptance remain open. See [FURNEXA_CURRENT_CHECKPOINT.md](FURNEXA_CURRENT_CHECKPOINT.md) and [FURNEXA_FINAL_FILE_INVENTORY.md](FURNEXA_FINAL_FILE_INVENTORY.md) for precise status and next actions.