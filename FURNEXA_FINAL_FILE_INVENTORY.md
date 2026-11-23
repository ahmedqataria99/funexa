# Furnexa Final File Inventory

**Checkpoint:** 2026-11-23  
**Method:** Read-only Git status for the Furnexa Git root, directory/file inspection for build outputs, and report/source inspection for the sibling AI root. No files were removed, reverted, formatted or tested. The only new files from this handover are the three Markdown documents listed below.

## Inventory Limits and Counts

The Furnexa worktree had **23 tracked paths modified or deleted** and **48 untracked files** before this handover. This document and the other two handover reports add three untracked Markdown files, for **74 observable Furnexa worktree changes** now. The 23 tracked paths comprise 18 modified and five deleted paths.

`D:\avatar\vs code\My APPS\furnixa-ai` has no `.git` directory. Consequently, there is no Git baseline from which to distinguish modified, newly created, or unchanged files there. The AI entries below identify the implementation files and recorded evidence relevant to this project handover; they are not a claim that the non-Git AI directory's complete change history is reconstructable.

Release outputs and database backup metadata are listed separately because generated build outputs are not represented by the Git worktree status. No database contents were opened.

## Furnexa Git Worktree: Modified or Deleted Tracked Files

| File path | Project | Current status | Purpose of changes | Verification status |
|---|---|---|---|---|
| `lib/core/localization/app_localizations.dart` | Furnexa | Modified | Localization additions used by Returns/AI-facing flows. | Prior targeted analysis reported no errors; latest Flutter tests did not reach tests. |
| `lib/core/shared/widgets/furnexa_table.dart` | Furnexa | Modified | Shared table scroll configuration, including separation of vertical page scrolling from horizontal table behavior. | Source/report reviewed; no latest widget execution. |
| `lib/features/returns_quality/data/datasources/returns_quality_local_data_source.dart` | Furnexa | Modified | Warehouse-scope enforcement and verified parent/child relationships for return, receipt and QC queries. | Earlier isolated security/regression tests passed; latest return suite failed before execution. |
| `lib/features/returns_quality/presentation/pages/purchase_returns_page.dart` | Furnexa | Modified | Dedicated vertical scrolling for Purchase Returns content. | Positive-scroll assertion exists; latest suite failed before test entry. |
| `lib/features/returns_quality/presentation/pages/sales_returns_page.dart` | Furnexa | Modified | Dedicated vertical scrolling for Sales Returns content. | Positive-scroll assertion exists; latest suite failed before test entry. |
| `lib/features/sales/data/datasources/sales_local_data_source.dart` | Furnexa | Modified | Delivery history and warehouse reads now enforce authorized warehouse scope. | Earlier security tests passed in isolated copy; current full revalidation blocked. |
| `lib/features/users_roles_permissions/data/datasources/security_local_data_source.dart` | Furnexa | Modified | Exposes current session warehouse grants and existing system-role scope behavior to scoped reads. | Earlier isolated security tests passed; latest test execution blocked. |
| `lib/main.dart` | Furnexa | Modified | Wires AI bridge/runtime, application lifecycle stop behavior and Demand Intelligence navigation/page. | Previous analysis/build passed for an earlier source state; current Release payload predates current lifecycle/chart edits. |
| `pubspec.lock` | Furnexa | Modified | Dependency lock changes, including Windows process/FFI and icon asset integration dependencies. | `flutter pub get` is documented as successful previously; no current dependency resolution run. |
| `pubspec.yaml` | Furnexa | Modified | Registers app icon PNG assets and current package metadata/dependencies. | Prior `flutter pub get` and configuration checks passed; no current run. |
| `test/demo_data_seed_test.dart` | Furnexa | Modified | Verifies idempotent demo seed, historical sales coverage, foreign-key integrity, and administrator password-hash preservation in an isolated test DB. | Not executed in the latest verification; native-assets runner failure prevents claiming current pass. |
| `test/purchase_returns_ui_test.dart` | Furnexa | Modified | Adds Purchase Returns vertical drag/scroll-offset and UI behavior coverage. | Latest run failed before tests due sqlite3.dll copy collision. |
| `test/returns_quality_feature_test.dart` | Furnexa | Modified | Updates return/QC fixture association and return regressions. | Latest run failed before tests due sqlite3.dll copy collision. |
| `test/sales_returns_ui_test.dart` | Furnexa | Modified | Adds Sales Returns vertical scroll-offset assertion and related UI checks. | Latest run failed before tests due sqlite3.dll copy collision. |
| `tool/demo_data_seeder.dart` | Furnexa | Modified | Idempotent synthetic factory dataset generation across master data, purchasing, production, sales history and accounting. | Seed test documents expected invariants, but latest seed test was not run. |
| `tool/phase03_schema_probe/run-1795117398222606/candidate_schema.sql` | Furnexa | Deleted in worktree | Prior generated schema-probe artifact; deletion is present in current Git diff and is preserved as-is. | Not applicable; this handover did not delete it. |
| `tool/phase03_schema_probe/run-1795117398222606/migrated_from_zero.db` | Furnexa | Deleted in worktree | Prior generated schema-probe SQLite artifact; deletion is present in current Git diff and is preserved as-is. | Not applicable; this handover did not open or delete it. |
| `tool/phase03_schema_probe/run-1795117398222606/schema_metadata.json` | Furnexa | Deleted in worktree | Prior generated schema-probe metadata; deletion is present in current Git diff and is preserved as-is. | Not applicable; this handover did not delete it. |
| `tool/phase03_schema_probe/run-1795117398222606/schema_only_candidate.db` | Furnexa | Deleted in worktree | Prior generated schema-only SQLite artifact; deletion is present in current Git diff and is preserved as-is. | Not applicable; this handover did not open or delete it. |
| `tool/phase03_schema_probe/schema_migration_probe.dart` | Furnexa | Deleted in worktree | Prior schema migration probe utility; deletion is present in current Git diff and is preserved as-is. | Not applicable; this handover did not delete it. |
| `windows/runner/Runner.rc` | Furnexa | Modified | Embeds the Furnexa `.ico` resource through the native runner. | Prior executable icon extraction passed; existing Release predates later Dart source edits. |
| `windows/runner/main.cpp` | Furnexa | Modified | Sets the native window title to `Furnexa`. | Prior live title/metadata check passed for earlier Release. |
| `windows/runner/resources/app_icon.ico` | Furnexa | Modified | Multi-resolution Furnexa launcher/executable icon. | ICO asset validation and prior executable icon extraction passed. |

## Furnexa Git Worktree: Untracked/New Files Before This Handover

| File path | Project | Current status | Purpose of changes | Verification status |
|---|---|---|---|---|
| `FURNEXA_APP_RUNTIME_SMOKE.txt` | Furnexa | Untracked evidence log | Direct app + packaged AI smoke: health, inference, app-close, surviving worker/port. | Records forecasts pass and shutdown/port-release failure; process PIDs 20136 and 10100, port 62436. |
| `FURNEXA_BRANDING_ICON_IMPLEMENTATION_REPORT_V1.md` | Furnexa | Untracked report | Branding/icon design, assets, runner resource wiring and checks. | Report records valid icon assets and prior dependency/config checks. |
| `FURNEXA_FINAL_ACCEPTANCE_REPORT_V1.md` | Furnexa | Untracked report | Prior portable extraction/application acceptance checklist. | Records app/runtime startup and inference passes; actual Demand Intelligence UI not tested. Its shutdown PASS conflicts with separate smoke and does not verify current Job Object source. |
| `FURNEXA_FINAL_BUILD_COMPLETION_REPORT_V1.md` | Furnexa | Untracked report | Consolidated build/test/runtime completion and blocker report. | Records build/package passes, native-assets test failures and AI worker leak. |
| `FURNEXA_FINAL_BUILD_VERIFICATION_REPORT_V1.md` | Furnexa | Untracked report | Earlier verification snapshot before successful Release artifacts existed. | Superseded by later build evidence; preserve as historical. |
| `FURNEXA_PYINSTALLER_BUILD.txt` | Furnexa | Untracked build log | PyInstaller packaging transcript. | Prior completion report records exit 0. |
| `FURNEXA_RUNTIME_INFERENCE_SMOKE.txt` | Furnexa | Untracked evidence log | Packaged service health and 7/14/30-day forecast run. | Forecasts pass; service exit code 1 and port 54070 not released in that harness. |
| `FURNEXA_TEST_AI_BRIDGE.txt` | Furnexa | Untracked test log | Latest Flutter AI bridge/payload/runtime test invocation output. | Exit 1 before tests; SQLite native-assets `PathExistsException`/OS error 183. |
| `FURNEXA_TEST_PURCHASE_RETURNS.txt` | Furnexa | Untracked test log | Latest Purchase Returns test invocation output. | Exit 1 before tests; same native-assets failure. |
| `FURNEXA_TEST_RETURNS_WORKFLOW.txt` | Furnexa | Untracked test log | Latest return feature/migration workflow invocation output. | Exit 1 before tests; same native-assets failure. |
| `FURNEXA_TEST_SALES_RETURNS.log` | Furnexa | Untracked binary/Unicode log | Additional Sales Returns test output capture. | Read-only inspection showed the test path; supporting result is the `.txt` log. |
| `FURNEXA_TEST_SALES_RETURNS.txt` | Furnexa | Untracked test log | Latest Sales Returns widget invocation output. | Exit 1 before tests; same native-assets failure. |
| `FURNEXA_UI_AND_RUNTIME_FIX_REPORT_V1.md` | Furnexa | Untracked report | Summarizes Demand Intelligence UI, service startup and Returns scroll changes. | Contains prior analysis/test/build limitation; latest source changes still need validation. |
| `FURNEXA_WINDOWS_BUILD_RELEASE.txt` | Furnexa | Untracked build log | Standard Flutter Windows Release build output. | Records build success, exit 0, on 2026-11-22. |
| `FURNEXA_WINDOWS_RELEASE_BUILD_REPORT_V1.md` | Furnexa | Untracked report | Release layout, packaging command, icon and smoke-test summary. | Historical; partly superseded by later source/runtime evidence. |
| `assets/icons/furnexa_icon_1024_master.png` | Furnexa | Untracked generated asset | 1024px square Furnexa icon master. | Prior Pillow validation reported valid RGBA. |
| `assets/icons/furnexa_icon_transparent.png` | Furnexa | Untracked generated asset | Transparent launcher icon asset. | Prior Pillow validation reported valid RGBA/alpha. |
| `docs/technical/EXPENSE_DATA_READINESS_AUDIT_V1.md` | Furnexa | Untracked documentation | Expense field/schema readiness review. | Documentation only; no real-row access is claimed. |
| `docs/technical/FURNEXA_AI_EXPORT_AUTHORIZATION_DESIGN_V1.md` | Furnexa | Untracked design document | Proposed authorization boundary for AI export. | Design-only; no export implementation implied. |
| `docs/technical/FURNEXA_AI_EXPORT_IMPLEMENTATION_PLAN_V1.md` | Furnexa | Untracked plan | Proposed implementation sequencing for controlled AI export. | Plan only. |
| `docs/technical/FURNEXA_AI_FACTORY_BOUNDARY_CONTRACT_V1.md` | Furnexa | Untracked contract | Defines factory-isolation boundary requirements. | Contract/design evidence; not proof of real-data isolation. |
| `docs/technical/FURNEXA_AI_HISTORICAL_SALES_DATASET_REPORT_V1.md` | Furnexa | Untracked report | Documents allow-listed dataset builder/coverage validation. | Report records 8 Dart and 10 Python focused tests passed previously. |
| `docs/technical/FURNEXA_AI_IMPLEMENTATION_PLAN_V1.md` | Furnexa | Untracked plan | Local AI implementation plan. | Plan only. |
| `docs/technical/FURNEXA_AI_LOCAL_BRIDGE_IMPLEMENTATION_REPORT_V1.md` | Furnexa | Untracked report | Local API, Flutter bridge and Sales payload architecture. | Records earlier focused Python/Flutter tests; later work adds dataset, forecast and UI layers. |
| `docs/technical/FURNEXA_AI_LOCAL_DATA_ACCESS_DESIGN_V1.md` | Furnexa | Untracked design document | Proposed local data access/export boundary. | Design only. |
| `docs/technical/FURNEXA_AI_LOCAL_SECURITY_CONTRACT_V1.md` | Furnexa | Untracked contract | Defines authentication, local permissions, data minimization and lifecycle controls. | Contract only; not a runtime test. |
| `docs/technical/FURNEXA_AI_RETURN_STOCK_RECONCILIATION_REPORT_V1.md` | Furnexa | Untracked report | Exact accepted-return stock transaction reconciliation contract. | Report records 14 focused matcher tests passed previously. |
| `docs/technical/FURNEXA_AI_RUNTIME_BLOCKERS_FIX_REPORT_V1.md` | Furnexa | Untracked report | Development launcher and packaged runtime blocker history. | Historical test evidence; its shutdown claims predate the latest app smoke. |
| `docs/technical/FURNEXA_AI_SALES_DATA_CONTRACT_V1.md` | Furnexa | Untracked contract | Defines authorized Sales payload fields and semantics. | Design/contract; no inference of real-data approval. |
| `docs/technical/FURNEXA_AI_SYSTEM_ADMIN_EXPORT_POLICY_OPTIONS_V1.md` | Furnexa | Untracked policy options | System-admin export approval alternatives. | Options only. |
| `docs/technical/FURNEXA_SALES_FACTORY_EXPORT_BOUNDARY_AUDIT_V1.md` | Furnexa | Untracked audit | Reviews read scopes and factory isolation for Sales data. | Documents limitations; not a blanket isolation certification. |
| `docs/technical/SALES_DELIVERY_RETURN_READ_SCOPE_SECURITY_FIX_V1.md` | Furnexa | Untracked implementation report | SQL warehouse scoping for delivery, return and QC reads. | Report records earlier isolated security/regression tests passed; latest suite blocked. |
| `furnixa-ai/src/api/local_ai_service.py` | Furnexa workspace mirror | Untracked, zero-byte file | Empty mirror file under the app root. The actual service source is in the sibling AI root. | Not a runnable service; do not package or edit based on this mirror. |
| `lib/features/ai/data/historical_sales_dataset_builder.dart` | Furnexa | Untracked source | Builds/validates historical pseudonymized dataset and coverage. | Earlier focused tests/analysis passed; latest tests not run due native-assets crash. |
| `lib/features/ai/data/local_ai_process_bridge.dart` | Furnexa | Untracked source | Authenticated loopback process bridge, health polling, diagnostics and latest Windows Job Object process-tree termination path. | Latest Job Object code not covered by a post-edit release shutdown smoke; latest Flutter test run failed before execution. |
| `lib/features/ai/data/local_ai_runtime.dart` | Furnexa | Untracked source | Locates packaged service relative to app; resolves development Python/venv/script. | Previous source review and earlier packaged test passed; latest source/release parity not established. |
| `lib/features/ai/data/sales_ai_payload_builder.dart` | Furnexa | Untracked source | Permission- and scope-checked Sales/Return payload construction and opaque identity tokens. | Earlier focused tests passed; latest bridge group failed before execution. |
| `lib/features/ai/presentation/pages/demand_intelligence_page.dart` | Furnexa | Untracked source | Filters, horizons, forecasts, errors and Demand Intelligence workflow. | No current native UI acceptance; the current Release bundle predates source timestamp. |
| `lib/features/ai/presentation/widgets/demand_forecast_panel.dart` | Furnexa | Untracked source | Forecast summary, states and custom historical/forecast chart painter. | Widget tests exist but latest test runner failed before execution; actual chart pixels not verified. |
| `test/demand_forecast_panel_test.dart` | Furnexa | Untracked test | Covers chart panel summaries, labels, loading, insufficient and invalid states. | NOT RUN in latest verification; does not itself establish Windows UI rendering. |
| `test/historical_sales_dataset_builder_test.dart` | Furnexa | Untracked test | Dataset validator and coverage behaviors. | Earlier report says 8 passed; not rerun in latest checkpoint. |
| `test/local_ai_bridge_test.dart` | Furnexa | Untracked test | Bridge startup, service unavailable and request behavior. | Earlier reports say focused bridge tests passed; latest group failed before test execution. |
| `test/local_ai_packaged_runtime_test.dart` | Furnexa | Untracked test | Uses the packaged service to test authenticated 7/14/30-day inference and insufficient history. | Earlier packaged run passed; current run failed before test execution and did not verify Job Object shutdown. |
| `test/local_ai_payload_builder_test.dart` | Furnexa | Untracked test | Sales payload authorization, identity, missingness and exact return stock reconciliation. | Earlier reports record 14 focused matcher cases passed; latest run blocked before execution. |
| `test/sales_read_scope_security_test.dart` | Furnexa | Untracked test | Cross-scope delivery/return/QC query security regressions. | Prior security report records 9 tests passed in an isolated copy. |
| `test/synthetic_factory_sales_integration_test.dart` | Furnexa | Untracked test | Disposable SQLite synthetic end-to-end sales-to-history pipeline. | Earlier report records 1 pass; current live database not used or inspected here. |
| `tool/build_windows_release.ps1` | Furnexa | Untracked build script | Builds Windows app, packages one-file AI service, checks DB exclusion/icon/metadata and optionally creates ZIP. | Previous invocations/build outputs are recorded; no script run for this handover. |
| `tool/generate_furnexa_icon.py` | Furnexa | Untracked asset generator | Generates icon PNG/ICO assets from the existing brand. | Prior validation passed; not run now. |
| `tool/seed_developer_synthetic_factory.dart` | Furnexa | Untracked database replacement tool | Backs up and hash-checks the current local DB, builds a synthetic staging DB, preserves auth/access data, validates, then swaps. | Code and isolated seed test reviewed; it was not run in this task and current DB was not opened. |

## Files Created by This Handover

| File path | Project | Current status | Purpose of changes | Verification status |
|---|---|---|---|---|
| `FURNEXA_COMPLETE_PROJECT_HANDOVER.md` | Furnexa | Created for this handover | Full project history, architecture, synthetic database and AI history, UI/runtime, Release state. | Content written from read-only evidence; no post-write command run by instruction. |
| `FURNEXA_CURRENT_CHECKPOINT.md` | Furnexa | Created for this handover | Latest chart/process investigation status, test/build evidence, database and Release state, prioritized next steps. | Content written from read-only evidence; no post-write command run by instruction. |
| `FURNEXA_FINAL_FILE_INVENTORY.md` | Furnexa | Created for this handover | File-level modified/untracked inventory with purpose and verification state. | This file; no post-write command run by instruction. |

## AI Project Files and Evidence (VCS Status Unknown)

The sibling root has no Git metadata. The following entries are confirmed present and relevant, but their modified/new status cannot be distinguished without a baseline:

| File/path | Project | Current status | Purpose and verification boundary |
|---|---|---|---|
| `src/api/local_ai_service.py` | Furnexa AI | Present, VCS status unknown | FastAPI local service and payload/forecast validation; source used by the build script. Python tests pass in the saved 81-test suite. |
| `src/evaluation/sales_forecasting_optimization_v4.py` | Furnexa AI | Present, VCS status unknown | Chronological synthetic model evaluation, guarded ETS and conservative selector used at runtime. Synthetic evidence only. |
| `src/evaluation/demand_intelligence.py` | Furnexa AI | Present, VCS status unknown | Coverage, eligibility and demand-intelligence synthetic analysis. Included tests pass in latest saved suite. |
| `tests/` | Furnexa AI | Present, VCS status unknown | Python unit, API, benchmark, robustness, demand and synthetic pipeline tests; saved suite reports 81 passed, 3 warnings. |
| `FURNEXA_PYTHON_TESTS.txt` | Furnexa AI | Present test output | Full saved Python test output and exit-code marker 0. |
| `FURNEXA_AI_RUNTIME_BLOCKERS_FIX_REPORT_V1.md` | Furnexa AI | Present report | Development and packaged runtime findings; historical scope and test results. |
| `FURNEXA_AI_SYNTHETIC_FACTORY_INTEGRATION_REPORT_V1.md` | Furnexa AI | Present report | Disposable synthetic end-to-end integration evidence; not real-data validation. |
| `FURNEXA_AI_FIRST_FORECASTING_EXPERIMENT_V1.md` | Furnexa AI | Present report | Synthetic rolling-origin comparison for 24 series and three observed-row horizons. |
| `FURNEXA_AI_MODEL_RELIABILITY_REVIEW_V1.md` | Furnexa AI | Present report | Research/product readiness assessment; recommends no operational forecast without real evidence. |
| `FURNEXA_AI_REAL_SALES_DATA_READINESS_REPORT_V1.md` | Furnexa AI | Present report | Says no authorized real snapshot was available; real readiness remains blocked. |
| `FURNEXA_AI_DATA_READINESS_AUDIT_V1.md` | Furnexa AI | Present report | Source/schema-only sales and expense mapping/readiness analysis. |
| `FURNEXA_AI_SNAPSHOT_CONTRACT_V1.md` | Furnexa AI | Present contract | Proposed snapshot schema/privacy contract; no snapshot implementation. |
| `FURNEXA_AI_SHADOW_EVALUATION_READINESS_CHECKLIST_V1.md` | Furnexa AI | Present checklist | P0 authorization, data, evaluation and operations gates; status not ready. |
| `FURNEXA_AI_FORECAST_BUSINESS_READINESS_V1.md` | Furnexa AI | Present report | States sales use cases not ready for operational decisions. |
| `FURNEXA_AI_FORECAST_NEXT_STEP_DECISION_V1.md` | Furnexa AI | Present report | Decision to wait for separately approved, sanitized real factory data. |
| `FURNEXA_DATABASE_VERSION_DOCUMENTATION_CORRECTION_V1.md` | Furnexa AI | Present proposal | Documents app schema target 41 and stale general DB guide reference to 19. |

## Generated Release and Database Artifacts (Outside Git Status)

| Artifact path | Project | Current status | Purpose and verification status |
|---|---|---|---|
| `build/windows/x64/runner/Release/furnexa.exe` | Furnexa | Present generated binary | 70,656 bytes; prior icon/metadata validation; built before current Dart lifecycle/chart changes. |
| `build/windows/x64/runner/Release/data/app.so` | Furnexa | Present generated binary | 12,665,776 bytes, timestamp 2026-11-23 17:34 UTC; predates current chart/bridge Dart sources at 18:06 UTC. |
| `build/windows/x64/runner/Release/ai_runtime/furnexa_ai_service.exe` | Furnexa | Present packaged runtime | 162,104,184 bytes; PyInstaller one-file service, timestamp 18:28 UTC. Prior health/inference passes; post-close tree behavior remains unresolved. |
| `build/windows/x64/runner/Release/ai_runtime/furnexa_ai_service/furnexa_ai_service.exe` | Furnexa | Present duplicate/stale packaged file | 42,698,331 bytes; nested duplicate runtime not part of intended clean layout. |
| `build/windows/x64/runner/Release/ai_runtime/_internal/` | Furnexa | Present generated runtime content | PyInstaller dependencies/runtime content; exact relationship to duplicate layout not independently rebuilt in this checkpoint. |
| `build/release/furnexa-windows-x64-portable.zip` | Furnexa | Present portable archive | 465,989,919 bytes, timestamp 18:42 UTC; 24,488 entries; app, stale Flutter payload, canonical and duplicate AI service; zero DB/backup entries. Not current for the latest Dart source. |
| `%LOCALAPPDATA%\Furnexa\furnexa.db` | Furnexa user data | Present local database | Metadata only: 3,760,128 bytes. Not opened or modified by this handover. |
| `%LOCALAPPDATA%\Furnexa\furnexa.db.pre-synthetic-20261122T180538268306Z` | Furnexa user data | Present displaced database file | Metadata only; prior state preserved by seed workflow. Not opened. |
| `%LOCALAPPDATA%\Furnexa\backups\furnexa-pre-synthetic-20261122T174218Z.db` | Furnexa user data | Present backup | Metadata only; not opened. |
| `%LOCALAPPDATA%\Furnexa\backups\furnexa-pre-synthetic-20261122T180538268306Z.db` | Furnexa user data | Present backup | Metadata only; not opened. |

## Inventory Conclusion

The Furnexa Git delta is exact for the inspected worktree: 18 modified, five deleted, 48 previously untracked, plus these three handover documents. The AI source root's status is inherently uncertain because no Git repository/baseline is present. Generated Release/ZIP files and local database backup artifacts are separately included so they are not lost merely because Git ignores them. No source or data artifacts were altered during this handover.