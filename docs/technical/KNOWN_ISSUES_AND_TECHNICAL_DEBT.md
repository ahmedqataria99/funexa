# Furnexa Technical Debt Report – Phase A Audit

## Audit scope and baseline

Phase A was a read-only source audit of project structure, database ownership, feature layering, tests, localization, security, backup/restore, and Windows configuration.

Baseline observations:
- The project uses feature-oriented folders with `domain`, `data`, and `presentation` boundaries in most major modules.
- SQLite is the authoritative data store, with versioned migrations in `lib/core/database/furnexa_database.dart` through database version 41.
- The worktree already contains substantial user and implementation changes. This report does not imply that those changes are defective or that they should be reverted.
- Existing technical documentation is maintained under `docs/technical/` and already identifies database version 41, migration mechanics, and major schema groups.

## P0 – Data integrity, security, and critical runtime risks

### P0-1: Database path and legacy migration behavior needs explicit fail-safe validation
- `FurnexaDatabase._resolveDatabasePath()` can copy a legacy database into the stable Windows production path when the stable file is missing.
- This migration path is valuable for preserving existing users, but it creates a risk of silently selecting or rehoming data unless source and destination identity and health are verified before copy.
- Startup currently awaits database open without a localized application-level startup failure screen.

**Required next action:** Add explicit path resolution diagnostics, pre-copy validation, no-fallback guarantees for an environment override, and a startup error state. No real database should be migrated or reset during testing.

### P0-2: Restore implementation replaces data with foreign keys disabled
- `BackupRestoreLocalDataSource.restoreBackup()` deletes all non-audit tables and re-inserts backup rows inside a transaction, but temporarily disables foreign-key enforcement.
- It relies on post-restore checks and transaction rollback for integrity.
- Failure recovery closes the active database and deletes/replaces the live database file, rather than restoring from a verified SQLite snapshot with WAL-aware handling.
- This is a high-risk operation even if protected by backup creation and permission checks.

**Required next action:** Use SQLite snapshot/restoration primitives or a database connection lifecycle that guarantees safe recovery, keep foreign-key validation explicit, and test rollback and restore failure paths against isolated databases.

### P0-3: Backup implementation is JSON table snapshotting rather than SQLite snapshotting
- `BackupRestoreLocalDataSource.createBackup()` reads all tables in one database transaction and serializes them to JSON.
- This is consistent and checksum-protected, but it does not capture SQLite pragmas or independent database engine state and may become brittle as schema complexity grows.
- Restore uses `INSERT ... replace`, so duplicate or conflicting rows depend on application validation and table ordering.

**Required next action:** Preserve compatibility, but introduce an integrity-verified SQLite snapshot format or a clearly specified JSON format with deterministic table ordering and stronger constraint validation.

### P0-4: Security enforcement is not uniform at repository/data-source boundaries
- The security singleton and permission checks exist.
- Data-source coverage is uneven, and direct repository or data-source calls can bypass presentation permissions.
- Permission checks should be evaluated where state changes occur, not only in widgets.

**Required next action:** Inventory writes by module and add focused `require()` checks to repositories/data sources. Preserve system-admin behavior and scope checks.

### P0-5: Startup swallows authentication initialization failures
- `_AuthGate._initialize()` catches initialization failures and still marks the application ready.
- It can therefore expose a login or setup state without a clear database/security diagnostic.

**Required next action:** Separate database failure, security failure, and first-admin setup states, with localized user feedback and developer diagnostics.

## P1 – Architecture and maintainability

### P1-1: Database monolith
- `lib/core/database/furnexa_database.dart` is 3,408 lines and contains path resolution, initialization, 41 migration steps, test hooks, reset logic, and backup-related database operations.
- The migration switch remains the authoritative history and must not be rewritten destructively.

**Recommended extraction:** Keep a single public database class where practical, but extract migration groups, path policy, test configuration, and diagnostics only when responsibilities become independently testable.

### P1-2: Oversized feature implementation files
The largest observed source files include:
- `lib/features/returns_quality/data/datasources/returns_quality_local_data_source.dart` – 3,580 lines
- `lib/features/sales/presentation/pages/sales_page.dart` – 3,229 lines
- `lib/features/production/presentation/pages/production_page.dart` – 2,600 lines
- `lib/features/sales/data/datasources/sales_local_data_source.dart` – 2,075 lines
- `lib/features/production/data/datasources/production_local_data_source.dart` – 1,769 lines
- `lib/features/accounting/data/datasources/accounting_local_data_source.dart` – 1,847 lines
- purchasing, raw-material, warehouse, and returns files also exceed 900 lines.

These files mix entity mapping, validation, SQL, UI state, dialogs, and command feedback. Refactor by responsibility, not merely by line count.

### P1-3: Mixed UI and persistence logic
- Several pages catch raw exceptions, call repositories directly, format database errors, and contain substantial dialogs/state transitions.
- Shared user-facing error normalization is incomplete.

**Recommended extraction:** Introduce a narrow localized domain-error mapping service and keep technical details in diagnostics/logging.

### P1-4: Environment separation is source-visible but should be locked down
- `FURNEXA_DATABASE_PATH`, test database configuration, reset utilities, demo seeding tools, and local development reset are present.
- The normal production executable should have no ambiguity between production, demo, and test paths.

**Required action:** Centralize environment policy and classify demo/reset utilities so they cannot target production or be exposed by normal release builds.

### P1-5: Existing migration schema documentation may drift
- `docs/technical/DATABASE_SCHEMA.md` is documentation, not generated from SQLite.
- The migration file remains authoritative, so future changes need synchronized documentation and version tests.

## P2 – Duplication and code size

- Raw exception handling and `Exception: ` stripping are repeated across presentation files.
- Feature data sources contain repeated mapping, uniqueness checks, permission/session checks, timestamps, and idempotency validation patterns.
- Shared widgets already exist under `lib/core/shared/widgets/`, but some features still maintain local table, form, dialog, and state implementations.
- Duplicate module names such as `returns_quality` and `returns_quality_control` should be reviewed to confirm ownership and avoid split implementations.
- Factory, sales, purchasing, production, warehouse, and accounting SQL contain repeated direct database access patterns that could benefit from small shared utilities only when a real invariant is shared.

**Priority:** Remove repeated data-integrity validation and error normalization first, not presentation markup alone.

## P3 – Cleanup and optimization

- Remove obsolete imports and info-level lints only after correctness refactors.
- Normalize naming and file organization across feature modules.
- Replace broad `catch (_)`, raw `error.toString()`, and English-only exceptions where they leak into localized UI.
- Improve loading, empty, and failure state consistency across desktop window sizes.
- Review public package metadata and description: `pubspec.yaml` still contains template wording.
- Existing `docs/technical/KNOWN_ISSUES_AND_TECHNICAL_DEBT.md` and the technical debt inventory should remain synchronized after future phases.

## Database-specific audit

### Current strengths
- Foreign-key enforcement is enabled through `PRAGMA foreign_keys = ON`.
- The database advances through an explicit version 41 migration chain.
- The migration includes data-preserving checks in critical purchasing status migrations.
- Critical sales, purchasing, production, warehouse, and accounting operations use transactions or idempotency records.
- Test database isolation exists through `resetForTesting()` and a generated database filename.
- Migration 41 has focused tests and data-preserving invoice migration behavior documented by existing code and tests.

### Items requiring verification in later phases
- Concurrent initialization under repeated singleton access.
- Migration upgrade paths for old versions and failed rollback behavior.
- Path isolation for test, demo, and production environments.
- Restore rollback, safety backup, and WAL consistency.
- Foreign-key enforcement after transactions and restore operations.
- Stock, reservation, journal balance, and document transition invariants at database/data-source level.
- Index coverage against high-frequency sales, purchasing, production, and inventory queries.

## Architecture findings

- Major feature folders follow Clean Architecture conventions, but implementation completeness varies.
- Repositories are generally present, though some pages/data sources own more logic than the domain layer suggests.
- Shared localization, theme, shell, table, form, dialog, and status widgets provide a good foundation.
- The app supports Arabic and English locales and already has a Wood/Navy-oriented design foundation.
- Windows release resources contain `app_icon.ico`, but metadata still contains template-like `com.example`, `furnexa`, and copyright values that must be standardized.

## Initial test and quality assessment

- 46 Dart test files are present under `test/`, with 27,536 test-source lines across the suite.
- Tests cover many modules, migrations, integration paths, and UI surfaces.
- Missing or weak areas for explicit audit targets include concurrent initialization, restore failure/recovery, database-path isolation, foreign-key coverage, and stock/accounting invariant edge cases.
- The suite should be used for focused regression after every meaningful refactoring group.

## Priority order

1. Freeze broad refactoring and verify database path identity and startup failure behavior.
2. Harden backup/restore and migration failure recovery against isolated databases.
3. Add missing database invariant and permission tests.
4. Split the database monolith and highest-risk data-source/page files into responsibility-based units.
5. Normalize user-facing errors and localization.
6. Finalize Windows metadata, icon, and release verification.

## Phase A checkpoint

No production, demo, or test database was reset or modified during this audit. No source or migration history was changed by the audit. Existing worktree modifications and untracked files were preserved.

## Phase B checkpoint – database lifecycle

### Implemented
- Serialized concurrent database initialization in `FurnexaDatabase` through an in-flight future so repeated `database` getters share one open operation.
- Updated the path override guard so configuration is rejected after initialization begins, not only after `_database` exists.
- Made `close()` wait for an in-flight open before closing and clearing the singleton.
- Added a concurrent-initialization test in `test/core_foundation_test.dart`.
- Corrected the purchasing status migration test so it validates migration version 30 without incorrectly asserting that the app's current schema remains 30.

### Verified
- `git diff --check` passed for the technical debt report edit.
- Pylance diagnostics reported no errors in the changed database and core-test files.
- Three focused core database tests passed: regular initialization, concurrent initialization, and database version.
- Database reset tests for recreated data and WAL/SHM preservation passed.
- Inventory identity migration tests passed for legacy preservation, key-collision rejection, and transaction rollback.

### Environment and remaining validation
- The backup/restore file progressed through restore and permission cases and was slower than isolated test-window expectations.
- The combined migration run surfaced the stale purchasing status assertion, which was corrected and rerun; terminal integration continued showing other suites and did not yield a clean aggregate exit status in this session.
- Phase B should not be considered complete until backup/restore, migration, and database suites are rerun individually with a clean final exit status.

### Files changed
- `lib/core/database/furnexa_database.dart`
- `test/core_foundation_test.dart`
- `test/purchasing_order_status_migration_test.dart`
- `docs/technical/KNOWN_ISSUES_AND_TECHNICAL_DEBT.md`

No schema migration history or business rules were changed.

## Final Phase B closure – serial validation

### Successful suites
- `test/database_reset_test.dart`: 2/2 passed, exit code 0.
- `test/purchasing_order_status_migration_test.dart`: 1/1 passed, exit code 0.
- `test/inventory_identity_migration_test.dart`: 3/3 passed, exit code 0.
- `test/production_unit_snapshot_migration_test.dart`: 2/2 passed, exit code 0.
- `test/returns_quality_migration_test.dart`: 4/4 passed, exit code 0.
- `test/sales_delivery_migration_test.dart`: 2/2 passed, exit code 0.
- `test/purchasing_supplier_migration_test.dart`: 2/2 passed on the final rerun, exit code 0.
- `test/backup_restore_feature_test.dart`: 12/12 passed, exit code 0.
- `test/backup_restore_ui_test.dart`: 5/5 passed, exit code 0.
- `test/warehouses_stock_feature_test.dart`: 18/18 passed, exit code 0.

`test/purchasing_supplier_migration_test.dart` initially failed because the synthetic legacy `units` table omitted `active`, and a later fixture shape also lacked current purchasing line identity columns. The fixture was corrected to include `active` and the identity columns required by the current repository; migration history and production schema were not changed.

### Runner stalls that are not fully verified
- `test/core_foundation_test.dart`: all 8 assertions reported passed, but the Flutter/Dart runner remained active after the last assertion and was stopped. Aggregate exit code: unavailable. This run is not labeled fully verified.
- `test/database_persistence_integration_test.dart`: 3 assertions reported passed, but the Flutter/Dart runner remained active and was stopped before a final aggregate or exit code. Aggregate exit code: unavailable. This run is not labeled fully verified.

### Final safety checks
- `git diff --check`: exit code 0.
- No production or demo database was modified.
- No Flutter cache, Dart cache, native-assets directory, or SQLite DLL was deleted or replaced.
- No shared build or native-assets cache cleanup was performed.
- Existing worktree modifications and untracked files were preserved.

## Phase C – read-only refactoring preparation

No Phase C refactoring is implemented. The following boundaries are ranked from the highest data-integrity risk to the largest UI/maintainability risk.

1. **P0 – `lib/core/database/furnexa_database.dart` (3,430 lines)**
   - Responsibilities: path resolution, singleton lifecycle, FFI initialization, migrations, reset, test isolation, and reset backup handling.
   - Evidence: the file combines environment policy with all migration steps and process lifecycle behavior. The migration switch is the authoritative history but is expensive to review and test by itself.
   - Proposed extraction: migration registry/groups, path resolver, connection lifecycle/test configuration, and database reset backup helper. Keep the public singleton facade temporarily to preserve callers.
   - Key callers: startup, every local data source, test helpers, and backup restore.
   - Existing coverage: core foundation, reset, purchasing, inventory, production, returns, sales, and warehouse migration tests.
   - Missing coverage: deterministic unsupported-path failure, concurrent close/reset races, migration downgrade behavior, and full fresh-to-v41 upgrade matrix.
   - Risk: P0. Sequence: add lifecycle/path tests, extract path resolution, then extract migration groups behind no-behavior-change entry points.

2. **P0 – `lib/features/returns_quality/data/datasources/returns_quality_local_data_source.dart` (3,580 lines)**
   - Responsibilities: sales/purchase returns, receipts, inspections, handovers, stock postings, and migration-era identity handling.
   - Evidence: SQL, transactions, validation, entity mapping, and stock/accounting invariants are concentrated in one file.
   - Proposed extraction: sales-return, purchase-return, quality-inspection, receipt/handover, and stock posting services while retaining the repository-facing data source facade.
   - Key callers: repositories and both returns pages.
   - Existing coverage: feature, UI, migration, and purchasing/sales returns tests.
   - Missing coverage: interrupted receipt/inspection operations and cross-module rollback edge cases.
   - Risk: P0. Sequence: extract one transaction-oriented service first, then split read mapping and state transitions without changing public APIs.

3. **P0 – `lib/features/sales/data/datasources/sales_local_data_source.dart` (2,075 lines)**
   - Responsibilities: quotations, orders, deliveries, reservations, invoices, payments, and stock/accounting validation.
   - Evidence: transaction and entity-mapping logic are combined; direct SQL is extensive and repeated around delivery state transitions.
   - Proposed extraction: order, delivery/reservation, invoice, customer payment, and shared identity/unit snapshot validators.
   - Key callers: sales repository and sales page; accounting and stock services receive its operations.
   - Existing coverage: sales feature, delivery migration, and invoice/receipt tests.
   - Missing coverage: all interrupted delivery confirmation/retry combinations and invoice idempotency under database reopen.
   - Risk: P0. Sequence: isolate invoice/delivery idempotency helpers, then split delivery reservation/confirmation from order persistence.

4. **P0 – `lib/features/production/data/datasources/production_local_data_source.dart` (1,769 lines)**
   - Responsibilities: routes, BOM snapshots, production orders, consumption, waste, output, stage updates, and costing hooks.
   - Evidence: snapshot validation and stock/accounting operations are transaction-heavy and share identity logic with warehouse and purchasing code.
   - Proposed extraction: snapshot validator, BOM/order service, consumption/output posting service, and stage transition service.
   - Key callers: production repository/page and costing/accounting contracts.
   - Existing coverage: production feature and unit-snapshot migration tests.
   - Missing coverage: interrupted consumption/output replay and cross-module journal rollback cases.
   - Risk: P0. Sequence: extract consumption/output transaction helpers first, then route/BOM mapping.

5. **P0 – `lib/features/backup_restore/data/datasources/backup_restore_local_data_source.dart`**
   - Responsibilities: JSON backup, checksum validation, restore, safety backup, history, and audit.
   - Evidence: foreign keys are disabled for table replacement and live database files are deleted/replaced during failure recovery.
   - Proposed extraction: backup format codec, integrity validator, SQLite snapshot/restore coordinator, and audit/history recorder.
   - Key callers: backup repository/controller/page and security data source.
   - Existing coverage: 12 feature cases and 5 UI cases passed.
   - Missing coverage: interrupted process recovery, real SQLite integrity checks after restore, and WAL/SHM-consistent snapshot validation.
   - Risk: P0. Sequence: add snapshot integrity tests before changing restore mechanics; preserve JSON compatibility during a narrow adapter extraction.

6. **P1 – `lib/features/accounting/data/datasources/accounting_local_data_source.dart` (1,847 lines)**
   - Responsibilities: accounts, periods, journal posting, parties, purchasing receipt entries, payroll, and valuation rules.
   - Evidence: financial and inventory invariants are spread across large private helpers and SQL transactions.
   - Proposed extraction: journal posting, period validation, party/reconciliation, purchasing/HR accounting adapters.
   - Key callers: purchasing, production, HR, and accounting page/repositories.
   - Existing coverage: accounting and integration suites.
   - Missing coverage: failed multi-entry rollback and journal-balance invariants under concurrent postings.
   - Risk: P1. Sequence: extract journal primitives first, then module-specific posting adapters.

7. **P1 – `lib/features/purchasing/data/datasources/purchasing_local_data_source.dart` (1,344 lines)**
   - Responsibilities: suppliers, requests, orders, receiving, payment, stock, and accounting integration.
   - Evidence: request-to-order conversion, state transitions, item identity snapshots, and SQL persistence are coupled.
   - Proposed extraction: supplier validation, request lifecycle, order lifecycle, receipt/reconciliation, and identity/snapshot validators.
   - Key callers: purchasing repository/page/document pages and accounting.
   - Existing coverage: broad purchasing feature and migration suites.
   - Missing coverage: interrupted receipt replay across multiple order lines and cross-request supplier conversion edge cases.
   - Risk: P1. Sequence: extract identity/request validation first, then receipt and order persistence helpers.

8. **P1 – `lib/features/sales/presentation/pages/sales_page.dart` (3,229 lines)**
   - Responsibilities: quotations, orders, delivery, invoicing UI, dialogs, filters, and persistence orchestration.
   - Evidence: presentation state performs searches, validation, repository calls, and raw error formatting.
   - Proposed extraction: sales list/document panels, shared document dialog, state controller for delivery/invoice workflows, and localized error adapter.
   - Key callers: application shell/global search and sales repository.
   - Existing coverage: sales feature and UI/widget tests.
   - Missing coverage: window-resize edge cases and full delivery/invoice failure-state transitions.
   - Risk: P1. Sequence: extract a document/editor widget and narrow delivery controller before touching list/navigation state.

9. **P1 – `lib/features/production/presentation/pages/production_page.dart` (2,600 lines)**
   - Responsibilities: production routes, orders, stages, consumption/output UI, and persistence orchestration.
   - Evidence: UI owns large workflow state and catches raw exceptions; the file is close to 1,600-line data-source complexity.
   - Proposed extraction: route/order editors, stage workflow panel, consumption/output controllers, and shared confirmation/error UI.
   - Key callers: application shell/global search and production repository.
   - Existing coverage: production feature/unit snapshot tests.
   - Missing coverage: interrupted execution UI and partial-output failure-state retries.
   - Risk: P1. Sequence: extract consumption/output panel/controller, then route/order editors.

10. **P1 – `lib/features/purchasing/presentation/pages/purchasing_page.dart` and `purchase_document_pages.dart` (1,334 and 936 lines)**
    - Responsibilities: purchasing lists, dialogs, document editors, PDF/document actions, and persistence orchestration.
    - Evidence: UI calls repositories/data sources and normalizes `Exception: ` text in several methods.
    - Proposed extraction: shared purchase document shell/editor, supplier list/profile integration, and a localized error/feedback helper.
    - Key callers: application shell/global search and purchasing repositories.
    - Existing coverage: strong purchasing feature/widget suite and document lifecycle tests.
    - Missing coverage: larger desktop resize behavior and isolated document validation controller tests.
    - Risk: P1. Sequence: extract document lifecycle controller first, preserving document widgets and PDF APIs.

11. **P2 – `lib/features/raw_materials_products/presentation/pages/raw_materials_products_page.dart` (1,860 lines)**
    - Responsibilities: catalog, BOM, alternatives, profiles, dialogs, and feedback.
    - Evidence: repeated local error handling and UI/data-source orchestration.
    - Proposed extraction: BOM editor, alternative editor, item profile, and feedback/error adapter.
    - Existing coverage: raw-material feature and migration tests.
    - Risk: P2.

12. **P2 – `lib/features/warehouses_stock/data/datasources/warehouses_stock_local_data_source.dart` (1,234 lines)**
    - Responsibilities: warehouse, stock, transfer, adjustment, valuation, permissions, and scope checks.
    - Evidence: validation and SQL transactions are concentrated but the suite is strong.
    - Proposed extraction: stock posting service, warehouse policy validator, transfer/adjustment helpers.
    - Existing coverage: 18 warehouse/stock tests passed in the Phase B run.
    - Risk: P2 because the main invariants are already transaction-focused, but the file remains large.

### Shared duplication and cross-cutting work
- Centralize exception-to-localized-message mapping instead of repeated `error.toString()` and `replaceFirst('Exception: ', '')` calls.
- Centralize stock item identity/unit snapshot validation only when purchasing, sales, production, and warehouse code truly share the same invariant.
- Keep pages thin and preserve existing repository interfaces during extraction.
- Avoid changing migration history or schema until a behavior-preserving refactor is approved.

## Recommended Phase C sequence
1. Add a narrow database lifecycle/path test group and extract path resolution from `furnexa_database.dart`.
2. Extract backup format/restore safety helpers without replacing the public backup implementation.
3. Extract purchasing receipt/identity helpers because the module has strong tests and a low regression surface for the first proof.
4. Split warehouse stock posting helpers from stock catalog/warehouse management.
5. Extract sales delivery/reservation helpers, then invoice helpers.
6. Extract production consumption/output helpers, then route/BOM mapping.
7. Split the largest page files only after their matching workflow controller has tests.

Phase C is intentionally not started by this report.

## Phase C.1 – database path resolution extraction

Database path resolution is now owned by `lib/core/database/database_path_resolver.dart`; `FurnexaDatabase` delegates path selection while retaining SQLite connection lifecycle, migrations, reset behavior, and FFI initialization.

### Actual precedence
1. Test database directory.
2. Local development/database override used by the demo seeder.
3. `FURNEXA_DATABASE_PATH` environment override.
4. Windows stable production path under `%LOCALAPPDATA%\Furnexa`.
5. Platform database directory fallback.

The demo launcher remains isolated by setting `FURNEXA_DATABASE_PATH` to `%LOCALAPPDATA%\Furnexa\demo\furnexa-demo.db`. Test and local-development paths are checked before environment and production paths. An explicitly configured empty `FURNEXA_DATABASE_PATH` is now rejected instead of silently falling back.

### Legacy behavior
On Windows, when the stable production database is missing, the resolver checks the executable-relative legacy database directory and then the platform database directory. It copies only a nonempty source and its WAL file. An existing stable database is never overwritten. Copy operations use temporary files and preserve the source and destination if copy or verification fails.

### Validation
- `test/database_path_resolver_test.dart`: 10/10 passed, exit code 0.
- `test/core_foundation_test.dart`: 8 assertions passed, but the runner stalled after the assertions and has no aggregate exit code.
- `test/database_reset_test.dart`: 2/2 passed, exit code 0.
- `test/sales_delivery_migration_test.dart`: 2/2 passed, exit code 0.
- Scoped `flutter analyze` for the resolver, database integration, and resolver tests: no issues found.
- `git diff --check`: passed, exit code 0.

No migration, schema version, production database, demo database, shared cache, or native asset was changed. Existing worktree changes and untracked files were preserved.
## Phase C.2.A – backup and restore safety audit

### Execution flow

**Backup creation**
1. `security.require('BACKUP_CREATE')` is checked.
2. The active database is read in one transaction.
3. Factory metadata and every nonempty SQLite table are serialized to JSON.
4. A SHA-256 checksum is computed for the sanitized payload.
5. The `.furnexa` file is written.
6. Backup history and an audit event are recorded.

**Validation**
1. Permission checks require `BACKUP_VIEW` or `BACKUP_RESTORE`.
2. File extension, JSON shape, format version, database version, metadata, table payload, and required core tables are checked.
3. The SHA-256 checksum is verified.
4. The backup database version must not be newer than the current application version.
5. Table names must exist in the current database and cannot repeat.
6. Backup JSON is not opened as SQLite and there is no `PRAGMA integrity_check` or `foreign_key_check` on the backup payload before restore.

**Restore**
1. `security.require('BACKUP_RESTORE')` and full validation run before the safety backup.
2. The safety backup closes the active database connection and copies the live database file to a temporary `.db` file.
3. `BACKUP_RESTORE_STARTED` is audited outside the restore transaction.
4. Foreign keys are disabled.
5. Existing tables are deleted in a transaction, except `audit_logs`.
6. Backup table payloads are inserted with `ConflictAlgorithm.replace`; `audit_logs` is skipped.
7. Foreign keys are re-enabled and a required-table, integrity, and foreign-key verification runs.
8. Restore history and success audit records are written.
9. The database connection is closed and the security session is logged out.
10. The safety backup file is deleted after success.

**Failure recovery**
- Validation and pre-restore failures occur before the safety backup and table transaction.
- Transaction exceptions roll back the in-database replacement.
- The catch block closes the database, deletes the live database file, copies the safety database file over it, audits failure, and throws.
- The catch block does not verify the safety copy or reopen the database explicitly.

### Transaction and connection boundaries
- Backup table enumeration and reads are inside one database transaction.
- Backup file writing and audit/history writes happen outside that transaction.
- Safety backup creation closes the active connection outside the restore transaction.
- Table deletion and insertion are inside one transaction.
- Required-table, integrity, foreign-key, history, and audit operations happen after that transaction.
- Safety-file copy and live-file delete/copy recovery happen outside SQLite transactions and are not process-atomic.

### Critical scenario matrix

| Scenario | Current outcome |
|---|---|
| Invalid checksum | Safely rejected before safety backup or database modification; covered by test 13. |
| Corrupted JSON | Rejected during validation before destructive operations. |
| Missing required tables | Rejected during validation before destructive operations. |
| Missing required columns | Not detected in validation; insertion failure rolls back the transaction, safety recovery restores the original database. Covered by test 14. |
| Unsupported schema version | Rejected by format/version validation before destructive operations. |
| Foreign-key violation | Transaction inserts with foreign keys disabled, then `_verifyRestoredDatabase()` detects violations; catch recovery restores the safety database and reopens it with foreign keys enabled. Covered by test 15. |
| Duplicate primary keys | `ConflictAlgorithm.replace` is used for restored rows; duplicate keys in the backup payload are not explicitly rejected. No general duplicate-entity invariant is established beyond individual table replacements. |
| Failure during table insertion | Transaction rolls back; catch restores the safety database. Covered by test 14. |
| Failure after connection close | Unverified. The catch has a safety-copy path, but copy success is not integrity-verified and no explicit reopen occurs. |
| Failure replacing live database file | Potentially leaves the application or database unavailable. The catch deletes the target before copying the safety file and does not guard partial copy success. |
| Failure reopening restored database | Not protected by an explicit reopen operation or post-reopen verification in `restoreBackup`; first subsequent database access determines whether the app recovers. |
| Application termination during restore | Not process-atomic; JSON restore plus live-file delete/copy has no interruption protocol. Potentially unavailable database; not verifiable by an isolated unit test. |
| Existing WAL/SHM files | `_createSafetyBackup()` closes the connection and copies only the live database file, while real WAL behavior is covered by test 17. SHM/WAL loss or corruption during failed file replacement is not explicitly guarded. |
| Safety backup creation failure | Not currently guaranteed. `_createSafetyBackup()` returns a path even when the source database file is missing and creates no file; test 19 confirms this behavior. |
| Audit logging failure | `BACKUP_RESTORE_STARTED` can abort before the transaction. `BACKUP_RESTORE_FAILED` or success audit failures occur during or after restore and are not separately rolled back or verified. |
| Repeated restore | Covered by test 18: factory and stock rows do not duplicate. Restore still logs out after success and requires a new authenticated session for another call. Backup audit rows are not restored. |

### Confirmed invariants
- Invalid checksum and structurally invalid backup payload tests do not alter active factory or stock data.
- A missing-column insertion failure restores the safety copy and leaves the original factory.
- A foreign-key violation is detected after restore and the safety copy reopens with foreign keys enabled.
- Successful restore passes `PRAGMA integrity_check`, `PRAGMA foreign_key_check`, and a reopened foreign-key check.
- WAL-mode committed stock data survives create/modify/restore in the isolated test.
- Repeated restore leaves one factory and one stock row in the tested tables.
- Rejected validation occurs before foreign-key disabling or table deletion.

### Unresolved risks
- Safety backup creation success is not verified by `_createSafetyBackup()`; missing or unreadable source can return a nonexistent safety path.
- Restore recovery deletes the live database file before copying the safety file and does not verify copy integrity or reopen explicitly.
- No backup-payload SQLite integrity or foreign-key preflight exists before table deletion.
- Duplicate primary and business key behavior depends on `INSERT OR REPLACE` semantics and table payload content rather than explicit domain validation.
- Process termination can occur outside SQLite transaction guarantees.
- Existing WAL/SHM sidecars are not independently checkpointed, verified, or snapshotted in `_createSafetyBackup()`.
- Audit logging failure is not an atomic part of the restore transaction.
- The controller swallows detailed restore exceptions and exposes generic localized feedback; technical diagnostics remain in the thrown exception and logs, not a structured restore error type.

### C.2.A test coverage
- `test/backup_restore_feature_test.dart` now contains 19 isolated safety/restore cases.
- Added coverage: invalid checksum no mutation, invalid structure no mutation, foreign-key violation recovery, missing-column transaction recovery, successful integrity/FK reopen, WAL stock preservation, repeated restore, and missing safety-source observability.
- Existing coverage includes metadata, checksum, corruption, missing file, permission, audit, safety backup, history, and invalid restore cases.
- No test changes production/demo paths: setup uses `DatabaseTestHelper.reset()` and a unique test database filename.

### C.2.A validation
- Backup/restore feature suite: 19/19 passed, exit code 0.
- Backup/restore UI suite: 5/5 passed, exit code 0.
- Database reset suite: 2/2 passed, exit code 0.
- Test-only scoped analysis: no issues in `test/backup_restore_feature_test.dart` and `test/backup_restore_ui_test.dart`.
- Scoped implementation analysis reported only eight existing curly-brace info diagnostics in `backup_restore_local_data_source.dart`; no errors or warnings.
- `git diff --check`: passed.

No restore algorithm, backup JSON format, schema, migration, UI, or shared cache was changed by C.2.A. The only implementation work is test hardening in `test/backup_restore_feature_test.dart`.

### Minimal Phase C.2.B extraction plan
Do not implement in C.2.A. A future approval should extract only:
1. Backup payload codec and checksum validation.
2. Safety database snapshot creation and explicit snapshot verification.
3. Restore transaction and required-table/integrity/FK verification.
4. Recovery coordinator that requires a verified safety snapshot and explicit reopen before declaring success or failure.
Keep the public repository/controller contracts and JSON format unchanged during extraction.

## Phase C.2.B – backup payload codec extraction

### Scope and implementation

The smallest independently testable responsibility selected was backup JSON encoding/decoding and checksum calculation/verification. The current worktree already contained this extraction when C.2.B validation began; those existing changes were reviewed and preserved rather than recreated.

- `BackupPayloadCodec` owns JSON root decoding, JSON serialization, and SHA-256 checksum calculation/verification. It accepts and returns explicit payload values and has no database or lifecycle access.
- `BackupRestoreLocalDataSource` remains the repository-facing facade and delegates payload encoding/decoding/checksum work to the codec.
- The checksum representation, sanitized JSON content, table ordering, payload format, validation rules, permission checks, history/audit calls, and public method signatures are unchanged.
- The restore transaction, deletion/insertion ordering, connection close/reopen calls, recovery file delete/copy sequence, and WAL/SHM handling were not changed.

### Files

- Added `lib/features/backup_restore/data/backup_payload_codec.dart`.
- Added `test/backup_payload_codec_test.dart` with five focused codec tests.
- Modified `lib/features/backup_restore/data/datasources/backup_restore_local_data_source.dart` to delegate codec responsibilities. This worktree modification was already present before C.2.B validation.
- Updated this technical debt report with the C.2.B result.

The existing C.2.A additions in `test/backup_restore_feature_test.dart` remain unchanged.

### Validation

All Flutter test suites were run sequentially against the isolated test fixtures/databases:

- `test/backup_payload_codec_test.dart`: 5/5 passed; runner reported success.
- `test/backup_restore_feature_test.dart`: 19/19 passed; runner reported success.
- `test/backup_restore_ui_test.dart`: 5/5 passed; runner reported success.
- `test/database_reset_test.dart`: 2/2 passed; runner reported success.
- Scoped `flutter analyze` for the codec, facade, and affected tests: exit code 1 due to eight `curly_braces_in_flow_control_structures` info diagnostics in the facade; no errors or warnings were reported. The extracted codec and its unit tests had no diagnostics.
- `git diff --check`: exit code 0. Git emitted line-ending conversion warnings for unrelated `.vscode/tasks.json` and `pubspec.lock` worktree changes.

The VS Code test runner reported pass counts but did not expose shell exit codes. The shell invocation of the focused test had no captured output, so only the test runner summaries are treated as verified.

### Remaining risks and plan deviation

This phase extracted only the payload codec and checksum responsibility from the C.2.A preparation plan. Safety snapshot verification, restore transaction verification extraction, and recovery coordination were not undertaken because they intersect the unresolved restore data-loss and lifecycle risks below and would require changing or depending on safety behavior explicitly held constant for this phase.

The C.2.A P0 risks remain unresolved: safety backup creation is not verified; recovery deletes the live database before copying the safety file and does not verify the copy or explicitly reopen it; process interruption and WAL/SHM sidecars are not protected by an atomic recovery protocol. This refactoring does not mitigate those risks. No restore algorithm, schema, migration history, database version, UI, production/demo database, or shared cache was changed. Phase C.2.B is complete; stop here pending approval for further work.

## Phase C.2.C.1 – restore compatibility audit (read-only)

### Scope and method

- Reviewed the versioned schema in `lib/core/database/furnexa_database.dart`, the supplemental factory schema initializer, `BackupRestoreLocalDataSource`, the path resolver, startup ordering, and existing isolated restore tests.
- Ran a disposable schema introspection against a newly created system-temporary database, using the app's migrations through `user_version=41`. The database path was unique and temporary; it was closed and that temporary directory was removed. No production/demo database was opened.
- The fresh migrated schema reported 106 user tables, 158 foreign-key rows, 196 unique indexes (including SQLite-generated constraint indexes), and four triggers. `global_search_history` is created lazily by the global-search feature and is additionally included by restore's runtime table enumeration if it exists.
- The migration history is versions 1–41. The migration source remains authoritative; this audit did not edit or replay any production/demo migration.

### Backup and restore table set

- Backup and restore enumerate every table in `sqlite_master` other than SQLite internal tables and `android_metadata`; this is a runtime set, not a hard-coded allowlist. Backup emits only tables with rows. Restore first deletes all current user tables except `audit_logs`, then inserts only table entries in the backup payload. Omitted/empty tables therefore remain empty.
- The 106-table migrated baseline is: `accounting_periods`, `accounts`, `app_setup_state`, `attendance_records`, `audit_logs`, `bank_accounts`, `cashboxes`, `categories`, `colors`, `commercial_discount_rules`, `costing_overhead_rules`, `crm_activities`, `crm_follow_ups`, `crm_leads`, `crm_notes`, `crm_tasks`, `customer_payments`, `customer_price_list_assignments`, `customer_price_overrides`, `customer_prices`, `customers`, `deductions`, `discount_rules`, `document_records`, `document_sequences`, `expenses`, `factories`, `inventory_valuations`, `journal_entries`, `journal_lines`, `journal_parties`, `leave_records`, `notifications`, `payroll_periods`, `payroll_records`, `permissions`, `price_history`, `price_lists`, `price_tiers`, `pricing_history`, `pricing_lists`, `pricing_product_prices`, `pricing_tiers`, `product_alternatives`, `product_bom_items`, `product_dimensions`, `product_prices`, `product_unit_conversions`, `product_variants`, `production_batch_costs`, `production_cost_adjustments`, `production_material_consumptions`, `production_order_bom_items`, `production_order_labor_allocations`, `production_order_stages`, `production_orders`, `production_other_costs`, `production_outputs`, `production_route_stages`, `production_routes`, `production_stages`, `production_waste`, `products`, `purchase_order_items`, `purchase_orders`, `purchase_receipt_items`, `purchase_receipts`, `purchase_request_items`, `purchase_requests`, `purchase_return_handover_items`, `purchase_return_handovers`, `purchase_return_items`, `purchase_return_receipt_items`, `purchase_return_receipts`, `purchase_returns`, `quality_inspection_items`, `quality_inspections`, `quotation_items`, `quotations`, `raw_materials`, `role_permissions`, `roles`, `sales_deliveries`, `sales_delivery_items`, `sales_invoice_items`, `sales_invoices`, `sales_order_items`, `sales_orders`, `sales_return_items`, `sales_return_receipt_items`, `sales_return_receipts`, `sales_returns`, `sections`, `shifts`, `stock_balances`, `stock_minimum_levels`, `stock_transactions`, `supplier_payments`, `suppliers`, `units`, `user_scopes`, `users`, `warehouses`, `worker_assignments`, `workers`, and `workshops`. `global_search_history` is the observed lazily created table and is included whenever it exists.
- Backup JSON can contain `audit_logs`; restore intentionally skips that table and retains the current audit rows. Successful restore appends history/audit rows. This is a preservation rule, not a full database replacement.
- Table names are enumerated alphabetically. Backup serializes rows in that table order, and restore consumes payload order as supplied. Validation rejects unknown/repeated table names and missing core tables, but does not establish a dependency order, reject duplicate entity keys, or validate required columns before mutation.
- Inserts use `ConflictAlgorithm.replace` (`INSERT OR REPLACE` behavior), which is not an update-in-place contract: unique conflicts can delete the conflicting row and invoke FK actions. The restore result can therefore depend on row contents and unique-index collisions.

### Foreign-key relationship and insertion-order report

All 158 introspected FK rows are immediate: no table DDL declares `DEFERRABLE`. All `ON UPDATE` actions are the SQLite default `NO ACTION`. `ON DELETE` is `RESTRICT`/default `NO ACTION` except the six `CASCADE` relationships listed below and `audit_logs.userId -> users.id ON DELETE SET NULL`.

Parent/child dependencies, grouped by schema area (child -> parent):

- Structure/catalog: `sections -> factories`; `workshops -> factories, sections`; `production_stages -> factories`; `warehouses -> factories`; `raw_materials -> categories, units`; `products -> categories, units`; `product_variants -> colors, products`; `product_dimensions -> products, product_variants`; `product_bom_items -> products, raw_materials`; `product_unit_conversions -> products, units`; `product_alternatives -> products` (source and target).
- Inventory/pricing: `stock_balances`, `stock_minimum_levels -> warehouses`; `stock_transactions -> warehouses, units`; `inventory_valuations -> warehouses`; `pricing_product_prices -> pricing_lists`; `product_prices -> pricing_lists`; `customer_price_list_assignments -> customers, pricing_lists`; `customer_price_overrides`, `customer_prices -> customers`.
- Procurement/returns/quality: `purchase_requests -> suppliers`; `purchase_request_items -> purchase_requests, units`; `purchase_orders -> purchase_requests, suppliers`; `purchase_order_items -> purchase_orders, units`; `purchase_receipts -> purchase_orders, warehouses`; `purchase_receipt_items -> purchase_receipts, purchase_order_items, units`; `supplier_payments -> suppliers, bank_accounts, cashboxes`; `purchase_returns -> purchase_orders, suppliers, warehouses`; `purchase_return_items -> purchase_returns`; `purchase_return_receipts -> purchase_returns, warehouses`; `purchase_return_receipt_items -> purchase_return_receipts, purchase_return_items`; `purchase_return_handovers -> purchase_returns, suppliers, warehouses, journal_entries`; `purchase_return_handover_items -> purchase_return_handovers, purchase_return_items, purchase_return_receipt_items`; `quality_inspections -> purchase_return_receipts` when linked; `quality_inspection_items -> quality_inspections, purchase_return_receipt_items` when linked.
- Sales/delivery: `quotations -> customers`; `quotation_items -> quotations, units`; `sales_orders -> customers, quotations`; `sales_order_items -> sales_orders, units`; `sales_deliveries -> sales_orders, warehouses`; `sales_delivery_items -> sales_deliveries, sales_order_items, units`; `customer_payments -> customers, bank_accounts, cashboxes`; `sales_returns -> sales_orders, customers, warehouses`; `sales_return_items -> sales_returns`; `sales_return_receipts -> sales_returns, warehouses`; `sales_return_receipt_items -> sales_return_receipts, sales_return_items`; `sales_invoices -> sales_orders, customers`; `sales_invoice_items -> sales_invoices, sales_order_items, units`.
- Production/HR: `production_routes -> products`; `production_route_stages -> production_routes, production_stages`; `production_orders -> products, product_variants, production_routes, units`; `production_order_stages -> production_orders, production_stages`; `production_order_bom_items -> production_orders, raw_materials, units`; `production_material_consumptions`, `production_waste -> production_orders, raw_materials, warehouses, units`; `production_outputs -> production_orders, warehouses, units`; `production_other_costs`, `production_cost_adjustments`, `production_batch_costs -> production_orders` (batch costs and adjustments also reference products); `workers -> sections, workshops, production_stages` when assigned; `worker_assignments -> workers, sections, workshops, production_stages`; `attendance_records -> workers, shifts`; `leave_records`, `deductions -> workers`; `payroll_records -> workers, payroll_periods`; `production_order_labor_allocations -> production_orders, attendance_records`.
- Accounting/security/CRM: `accounts -> accounts` (self-reference); `bank_accounts`, `cashboxes -> accounts`; `journal_lines -> journal_entries, accounts`; `journal_parties -> journal_entries`; `expenses -> accounts, bank_accounts, cashboxes`; `users -> roles`; `role_permissions -> roles, permissions`; `user_scopes -> users`; `audit_logs -> users` (nullable, `SET NULL`); `notifications -> users`; CRM activity/follow-up/task/note rows reference `crm_leads` and/or `customers` as defined by their nullable source columns.

There is one composite primary key, `role_permissions(roleId, permissionId)`. No composite FK was found. Composite unique constraints and partial unique indexes do exist, including `idx_dimensions_product_level`, `idx_product_prices_active_base`, `idx_customer_overrides_active_base`, `idx_price_tiers_active_base`, `idx_pricing_one_default`, `idx_customer_payment_operation`, `idx_supplier_payment_operation`, `idx_sales_orders_quotation_id_unique`, `idx_production_consumption_operation`, `idx_production_output_operation`, and the sales-delivery request/operation indexes, plus product/variant and customer pricing keys. Unique constraints must be checked before installation; `REPLACE` can have referential side effects.

Cycles and ordering:

- The only schema cycle found is the self-FK `accounts.parentId -> accounts.id`. `parentId` is nullable. The schema permits self-links and multi-row cycles; there is no DDL-level acyclicity constraint.
- For an immediate-FK insert, every referenced parent must exist before its child row is inserted, except a self-reference to the row being inserted. A data cycle across multiple account rows needs a two-pass insertion (insert account rows with `parentId=NULL`, then update parent links after all IDs exist) or a documented deferred-constraint strategy while `foreign_keys` remains ON.
- The compatible ordinary insertion order is parent-first across the graph; e.g. factories before sections/workshops/warehouses, roles before users, products/units/categories before dependent catalog and production rows, and each document header before its line/receipt/detail rows. Deletion order is the reverse dependency order: children before parents. Cascades can remove the six dependent detail relationships, but do not make arbitrary parent-first deletion safe where `RESTRICT` applies.
- The existing alphabetical deletion/insertion order is not compatible with immediate FK enforcement. Examples include `attendance_records` before `workers`/`shifts`, `audit_logs` before `users`, payment rows before some referenced entities, and header/detail dependencies. The current implementation works around this only by setting `foreign_keys=OFF`; post-restore checks do not make that compatible with FK enforcement throughout.

Triggers and audit preservation:

- `audit_logs` has `BEFORE UPDATE` and `BEFORE DELETE` triggers that abort all changes. The other triggers reject `purchase_requests` inserts/updates whose `supplierId` is null or empty. No other triggers were present in the migrated schema.
- With FK enforcement ON, deleting a user referenced by a retained audit row invokes `ON DELETE SET NULL`; that FK action attempts an audit-row update and the immutability trigger aborts it. `RESTRICT` references can independently block deletes. Therefore retaining audit rows while replacing users cannot be treated as an ordinary child-table delete.
- Any FK-on candidate strategy must retain every user identity referenced by preserved audit rows (and the referenced role), or reject the restore before swapping if that preservation cannot be reconciled with backup uniqueness/business rules. It must not bypass audit triggers or silently rewrite immutable audit rows. This policy needs explicit product approval before implementation.

### Restore compatibility finding and minimal strategy

The current restore cannot run its current delete/insert loops with `PRAGMA foreign_keys=ON` throughout: alphabetic parent deletion encounters `RESTRICT` children, and later inserts encounter children before parents; preserved audit references can make user deletion abort through `SET NULL` plus the immutability trigger. `PRAGMA foreign_key_check` can still be run separately when enforcement is off, but it does not turn the current path into an FK-on operation.

Minimal compatible direction, not implemented:

1. Build the restore in a same-volume candidate database while leaving the live database untouched. Keep `PRAGMA foreign_keys=ON` for the whole candidate restore transaction and verify the setting before and after it.
2. Preflight backup rows, required columns, duplicate PK/business/unique keys, trigger conditions, and audit-referenced user identities before changing candidate data. Reject incompatible audit/user merges rather than dropping or mutating retained audit history.
3. Delete candidate rows in child-first dependency order, with an explicit preservation policy for audit-referenced users/roles. Insert rows in parent-first order. For `accounts`, insert with nullable `parentId` temporarily cleared and restore links after all account IDs exist; check exact values and cycles. Do not rely on alphabetical payload order or `REPLACE` to supply ordering.
4. Run `integrity_check`, `foreign_key_check`, expected `user_version`, required-table checks, and application-specific postconditions on the closed candidate before any live-path operation. JSON backup format/checksum compatibility remains unchanged.

### SQLite, WAL/SHM, connection, and Windows findings

- A fresh migrated database reports `journal_mode=DELETE`; `FurnexaDatabase` does not set a journal mode in `openDatabase`/`onConfigure`. The restore test suite explicitly switches one isolated test database to WAL and verifies committed stock data survives its test restore. That is a useful case, not a general sidecar replacement guarantee.
- The mode of any existing production/demo database is unknown and was intentionally not inspected. Journal mode is a per-database persisted setting and must be queried read-only on the selected database only with explicit authorization; the isolated fresh-database result must not be generalized to existing files.
- `FurnexaDatabase` owns a static singleton connection and in-flight open future; `openDatabase(..., singleInstance: true)` coordinates sqflite's connection instance inside the process. It is not a cross-process lease and does not prevent another app process or a non-cooperating SQLite client from opening the same path.
- The reset path attempts `wal_checkpoint(FULL)` and checks `busy`, then closes and copies/deletes `.db`, `-wal`, and `-shm`. The restore safety path closes the singleton and copies only the main `.db`; restore failure deletes the live main file and copies the safety file without digest verification or explicit reopen. Neither path establishes a process-wide exclusion guarantee.
- A committed WAL frame may be newer than the main database until checkpoint. `-wal` is persistent recovery data; `-shm` is a rebuildable shared-memory index but must not be manipulated while a connection is active. Replacing only the main database while a connection or WAL remains can lose committed work or associate sidecars with the wrong database. A safe candidate/install path must quiesce all participating connections, checkpoint and verify (or use a SQLite backup API), close handles, and treat any leftover sidecar as a recovery condition, not delete it blindly.
- `PRAGMA integrity_check` and `PRAGMA foreign_key_check` are feasible on an opened SQLite candidate; they are independent checks. `integrity_check` does not replace FK checking. The current code runs both after the table transaction, but has no explicit post-install reopen/version verification in `restoreBackup` itself. A future candidate must also verify `PRAGMA user_version` against the expected current schema.
- Windows assumptions requiring fault tests: candidate and rollback files must be siblings on the same volume as the live DB; open handles/AV scanners can prevent rename/delete; cross-volume rename is not atomic; Dart `File.rename` replacement behavior and directory-entry durability must not be assumed. Choose and test the exact Win32 same-volume replacement primitive and its flags (including write-through/durability behavior). Never delete the only valid live/recovery copy before the replacement is verified. Recovery must account for `.db`, `-wal`, and `-shm` as a coherent SQLite lifecycle.

### Proposed recovery journal schema and state machine

Use a private, versioned JSON journal adjacent to the database, independent from the unchanged `.furnexa` backup JSON:

| Field | Type / rule |
|---|---|
| `formatVersion` | Integer; initially `1`; unknown versions fail closed. |
| `operationId` | Random UUID, unique per restore. |
| `state` | One of the explicit states below; reject unknown values/transitions. |
| `createdAtUtc`, `updatedAtUtc` | UTC RFC 3339 timestamps; diagnostic only, never proof of liveness. |
| `databasePath`, `candidatePath`, `rollbackPath`, `backupPath`, `journalPath` | Canonical absolute paths; candidate/rollback/journal are exact operation-specific siblings on the database volume. |
| `backupSha256`, `candidateSha256`, `rollbackSha256` | Lowercase 64-hex SHA-256 of exact file bytes after SQLite handles are closed and required checkpoints are complete. |
| `originalUserVersion`, `candidateUserVersion`, `expectedUserVersion` | Nonnegative integers; candidate/installed version must equal the app's current supported version. |
| `integrityCheck` | Exact verified result `ok` before candidate installation. |
| `foreignKeyViolationCount` | Integer; must be zero before candidate installation. |
| `failureCode` | Optional bounded stable code, not an arbitrary path or unbounded exception/secret. |

Write each journal update to a unique sibling temp file, flush it, replace the journal using a Windows-tested same-volume primitive, and verify the resulting version/state. Never trust paths or digests from the journal until format, state, canonical-path policy, and file hashes have been checked.

Path validation must derive the live path from the configured `DatabasePathResolver`, not from journal input. Candidate, rollback, journal, and journal-temp paths must be generated from the canonical live parent directory and operation UUID, remain sibling files on that same volume, and never alias the live DB, one another, or a sidecar (Windows comparisons are case-insensitive). Reject traversal, unexpected reparse points/junctions, directories, device paths, alternate-stream syntax, and unexpected filename extensions. The selected `.furnexa` backup is canonicalized and hashed as read-only input; it must not resolve to the live DB, candidate, rollback, journal, or their sidecars. Do not follow a journal-provided path outside the allowed generated set.

Allowed normal transitions: `PREPARED -> CANDIDATE_READY -> SWAP_INTENT -> ORIGINAL_MOVED -> CANDIDATE_INSTALLED -> VERIFIED -> COMMITTED`. Pre-swap abort may transition `PREPARED` or `CANDIDATE_READY -> ABORTED`. Recovery may transition any swap-started nonterminal state to `ROLLBACK_INTENT -> ORIGINAL_RESTORED -> RECOVERED`; if neither candidate nor rollback can be proven valid, transition to `FAILED_MANUAL` and preserve every artifact. `COMMITTED`, `ABORTED`, `RECOVERED`, and `FAILED_MANUAL` are terminal. Cleanup is permitted only after `COMMITTED` or `RECOVERED` has itself been durably recorded and the selected live DB has passed verification.

Digest checks must hash the exact backup file bytes and the closed, checkpointed candidate/rollback files before use, then hash again after each copy/move. Digests do not substitute for SQLite integrity/FK/version checks. A mismatch, missing required artifact, malformed/truncated journal, path escape, unexpected sidecar, or unsupported version must block automatic normal DB opening. Preserve artifacts and surface an explicit recovery-required state; do not guess, delete the journal, or open the ambiguous live DB. A valid pre-swap journal can safely discard only its verified candidate while the original live digest still matches. Swap-stage recovery chooses candidate only if its digest and DB checks pass; otherwise it restores the verified rollback copy. Ambiguous cases fail closed for manual recovery.

### Proposed Windows process lease and limits

Use a Windows kernel-managed exclusive byte-range lock (`LockFileEx`) on a deterministic lease file derived from the canonical database path. Acquire it before any SQLite connection is opened and retain the handle for the application process lifetime, including restore and startup recovery. Failure to acquire means do not open the database. Keep owner metadata (PID, process start time, random nonce, executable identity) for diagnostics only.

The OS lock, not the metadata timestamp/PID, is authoritative: a held lock means active ownership; if the exclusive lock can be acquired, any remaining metadata is stale and can be replaced after validating its path. Process termination closes the handle and releases the kernel lock, avoiding timestamp-based stale detection and PID-reuse guesses. Do not delete a lease file merely because its timestamp looks old.

This guarantee applies only to Furnexa processes that use the same canonical lease protocol on a local filesystem with tested Windows lock semantics. It does not prevent older/non-cooperating app versions, external SQLite tools, or filesystems with different locking semantics from opening the DB. `singleInstance: true` alone is not cross-process protection. The lease must be tested across two independent Windows processes, crash/termination, and handle contention before claiming single-instance behavior.

Startup recovery must run after path resolution but before the first normal `FurnexaDatabase.database` open. The lease is acquired first; journal and sidecars are inspected without opening the normal live DB; deterministic candidate/rollback recovery runs; the selected DB is opened only after file-state and SQLite checks succeed. The database-open gate must cover every caller, not only `main()`, so tests/tools and feature data sources cannot bypass recovery. Keep the lease through normal app lifetime and release only after all DB handles are closed.

### Failure-injection matrix for C.2.C.2–C.2.C.4

| Injection point / condition | Required result |
|---|---|
| Invalid backup checksum, malformed payload, duplicate table/key, missing column, invalid trigger-required supplier | Reject before candidate swap; live DB and audit history unchanged. |
| Audit row references a user absent/conflicting in backup; user/role delete restricted | Explicitly merge according to approved preservation rule or reject; never mutate/delete immutable audit rows. |
| Parent/child order reversed; multi-row `accounts` parent cycle | Candidate remains FK-enabled; ordered/two-pass load succeeds only for valid references, otherwise candidate is rejected. |
| Candidate insert, unique-index, trigger, integrity, FK, or `user_version` failure | Candidate is discarded only when verified safe; live DB remains byte-identical and openable. |
| Disk full or access denied during journal temp write, flush, candidate copy, hash, or directory replace | No unverified transition is trusted; retain prior live/recovery artifact and fail closed. |
| Process termination after each journal state and each rename/replacement | Next startup selects a digest-verified candidate or restores digest-verified rollback; never opens an ambiguous DB. |
| Failure after live-to-rollback move but before candidate install | Restore verified rollback before normal DB open. |
| Failure after candidate install but before `VERIFIED`/`COMMITTED` | Verify candidate; complete only if all checks pass, otherwise restore verified rollback. |
| Failure after `COMMITTED` but before cleanup | Keep verified live DB; cleanup is idempotent and never removes the live copy. |
| WAL checkpoint busy, another process holds a connection, or `-wal`/`-shm` remains unexpectedly | Do not snapshot or replace; lease/connection ownership failure is surfaced, sidecars are preserved. |
| Windows rename target exists, open-handle sharing violation, AV scan, or interrupted directory update | Exact chosen Win32 primitive has tested outcomes; no delete-then-copy gap and rollback remains recoverable. |
| Active lease, process crash with abandoned lock, stale metadata/PID reuse, two concurrent starters | Exactly one cooperating process acquires the OS lock; crashed owner releases by kernel close; stale metadata alone never blocks or grants ownership. |
| Truncated/unknown-version journal, escaped path, missing artifact, wrong digest, unexpected sidecar | Do not auto-clean or open normally; preserve evidence and enter recovery-required/manual state. |

### Minimal approved-work sequence proposal

1. **C.2.C.2 – journal and lease primitives:** implement the versioned journal codec/state validator, canonical sibling-path rules, atomic journal update primitive, Windows process lease, and unit/process tests. Keep current restore behavior and JSON payload unchanged until these primitives are verified.
2. **C.2.C.3 – candidate restore:** checkpoint/close and snapshot the live DB safely; construct and validate a separate candidate with FK enforcement on, dependency-aware deletion/insertion, the approved audit-user preservation rule, duplicate/trigger preflight, and integrity/FK/version checks. Add fault injection around every candidate phase; do not install on any failed check.
3. **C.2.C.4 – startup recovery and Windows install:** gate all database opens on lease plus journal recovery; implement/test same-volume candidate/rollback installation with the selected Win32 primitive; verify post-install reopen and sidecars; run crash injection across all state transitions on Windows and isolated SQLite regression tests. Preserve `.furnexa` version 1 compatibility.

### C.2.C.1 checkpoint

Read-only audit complete. Only this technical-debt document was updated. No source, tests, schema, migration history, JSON backup compatibility, production/demo database, cache, or native asset was changed. No implementation is authorized by this phase; stop and wait for approval before C.2.C.2.

## Phase C.2.C.2 – recovery infrastructure (isolated)

### Scope implemented

- Added a versioned recovery journal codec/store under `lib/core/recovery/`.
- Added explicit recovery states and a centrally allowed transition map.
- Added a Windows-compatible OS byte-range lease file scoped by canonical database identity.
- Added a narrow file-operation seam for exclusive creation, copy, SHA-256, identity, no-overwrite rename, flush, and WAL/SHM inspection.
- Added an isolated startup recovery decision component. It is not connected to application startup or `FurnexaDatabase`.
- Added isolated tests using temporary directories and a separate Dart lease probe process.

No staged restore algorithm, live database switch, live database deletion/replacement, foreign-key setting change, audit-trigger change, restore ordering change, JSON format change, schema change, database-version change, startup wiring, cache deletion, or native-asset operation was performed.

### Recovery journal

- Format version: `1`.
- Operation IDs are 32 lowercase hexadecimal characters.
- Journal, safety, candidate, and previous paths are deterministic operation-specific siblings of the canonical database.
- Serialization uses sorted JSON keys and strict field validation.
- Unsupported versions, malformed JSON, missing/extra fields, invalid timestamps, invalid IDs, path traversal, alternate-stream syntax, unexpected paths, ambiguous transitions, and invalid digests are rejected.
- Existing journals are parsed before same-operation replacement. A journal belonging to another operation is never overwritten.
- Updates are written to a unique sibling temporary file, flushed, renamed, and re-read for verification. Windows/SQLite interruption guarantees are limited: the journal flush and directory update do not prove power-loss durability for every filesystem/antivirus configuration; an interruption can leave the previous journal, a temporary file, or an ambiguous state. The infrastructure fails closed instead of repairing such ambiguity.
- The journal stores no secrets or authentication credentials.

### State machine

Normal transitions are:

- `prepared -> safety_copy_created -> safety_copy_verified -> candidate_created -> candidate_verified -> switch_started -> previous_database_preserved -> candidate_placed -> candidate_reopened -> completed`

Rollback may be entered from any nonterminal state where an interrupted operation may require it: `rollback_started -> rollback_completed`, or `rollback_started -> recovery_failed`. Pre/post-switch failures may also enter `recovery_failed` directly. `completed`, `rollback_completed`, and `recovery_failed` are terminal. Repeating the same transition is persisted deterministically; contradictory state/last-transition combinations fail closed.

Every state transition API persists the new state before returning. The infrastructure itself does not execute destructive database operations.

### Process lease

The implementation uses `RandomAccessFile.lock(FileLock.exclusive, 0, 1)` on a deterministic file beside the canonical database. The lease file is derived from the lower-cased canonical Windows path and its SHA-256 identity. The OS lock handle is authoritative; metadata contains canonical identity, operation ID, PID, nonce, and executable path for diagnostics only.

Windows guarantees demonstrated by tests:

- one lease can be acquired for a canonical database;
- a second same-process or independent-process acquisition is rejected;
- normal release closes and unlocks the handle;
- process termination releases the kernel lock and permits a new owner.

Timestamp/PID staleness is never used as proof. The implementation does not steal an active lease. The guarantee is limited to cooperating Furnexa processes using this protocol on a local filesystem with compatible Dart/Windows locking. It does not claim protection from older Furnexa builds, external SQLite tools, remote/network filesystems, or non-cooperating clients.

### File operations and startup decisions

The file seam has no live-database switch behavior and is deliberately injectable. Startup recovery decisions are isolated: missing journal means no recovery; prepared/pre-swap states mean pending; post-switch/rollback states mean rollback required; completed means verification required; missing digests or contradictory states mean fail closed.

### C.2.C.2 validation boundary

The staged restore algorithm remains unimplemented. The current backup/restore implementation remains unchanged. No database file was opened or switched by these infrastructure components.
