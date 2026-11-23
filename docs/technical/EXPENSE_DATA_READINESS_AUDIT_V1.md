# Furnexa Database Schema and Expense Data Readiness Audit v1

## Audit Scope and Evidence Level

This is a read-only source audit. No SQLite database file was opened, no SQL was executed against a business database, and no business records were read or exported. No Flutter code, migration, database, or AI experiment was changed. The audit uses the current Furnexa Dart migration/repository source, tests, and documentation. Therefore it establishes the schema the current source will create and the application paths visible in source; it does **not** establish the version, row population, null rates, or historical data quality of any installed database.

The AI workspace also contains a schema report from a fresh disposable database migrated through version 41 with zero business rows. That report corroborates the source shape but is not evidence from a representative or production database: [AI schema report](../../../furnixa-ai/docs/furnexa_database_schema_report.md).

## 1. Authoritative Database Version

### Finding

The current application target database version is **41**. The authoritative source is `AppConstants.databaseVersion`; `FurnexaDatabase._openDatabase()` passes that constant to `openDatabase`. Fresh creation runs migrations 1 through the target version; upgrades run each `_runMigration` from `oldVersion + 1` through `newVersion`. Foreign keys are enabled in both configure/create paths.

- [Database version constant](../../lib/core/constants/app_constants.dart#L6)
- [Open and migration initialization](../../lib/core/database/furnexa_database.dart#L90)
- [Fresh-create and upgrade migration loop](../../lib/core/database/furnexa_database.dart#L120)
- [Migration switch and final v41 case](../../lib/core/database/furnexa_database.dart#L151)
- [v41 schema statements and user_version assignment](../../lib/core/database/furnexa_database.dart#L3252)
- [Migration ALTER helper](../../lib/core/database/furnexa_database.dart#L3311)
- [Startup factory-structure initializer](../../main.dart#L46)
- [Auxiliary factory-structure DDL](../../lib/features/factory_structure/data/datasources/factory_structure_local_data_source.dart#L64)
- [On-demand global-search history DDL](../../lib/features/global_search/data/datasources/global_search_local_data_source.dart#L512)

All **versioned core-schema** DDL is in `lib/core/database/furnexa_database.dart` under `_runMigration` (migration cases 1-41); it is not loaded from a second runtime SQL schema file. The migration history includes direct `CREATE TABLE`, index and trigger statements, direct `ALTER TABLE`, conditional `_addColumnIfMissing`, and a v30 table-rebuild path. Case 5 replays migrations 2-4 for the legacy create path. A source-wide DDL search also found two auxiliary creators outside the migration switch: `FactoryStructureLocalDataSource.initializeSchema()` repeats `CREATE TABLE IF NOT EXISTS` / indexes for the five factory-structure tables, and `GlobalSearchLocalDataSource._ensureHistoryTable()` creates `global_search_history` on demand. `main.dart` invokes the factory initializer; the global-search helper is called by search-history methods. These statements do not modify `expenses` and do not change the `user_version` migration target. The current source ends at case 41; case 41 adds `sales_order_items.invoicedQuantity` and creates `sales_invoices` / `sales_invoice_items`. It does not alter `expenses`.

Expense- and relationship-relevant DDL milestones are:

| Migration | Source-defined change relevant to this audit |
| --- | --- |
| 2 | Creates factories, sections, workshops, production stages, and warehouses. |
| 6 | Creates suppliers, purchase requests/items, purchase orders/items, purchase receipts/items. |
| 9 | Creates workers, assignments, shifts, and HR records; no expense FK is added. |
| 10 | Creates accounts, journal tables, cashboxes, bank accounts, payments, and `expenses`. |
| 11 | Creates roles, permissions, users, `user_scopes`, and `audit_logs`; adds audit-log immutability triggers. |
| 14 | Alters sales-delivery fields; no expense change. |
| 28 | Conditionally adds `purchase_requests.supplierId` and supplier-required insert/update triggers. |
| 29 | Conditionally adds `purchase_receipts.receivedBy`; no user FK is declared by that alteration. |
| 34-40 | Add or rebuild other stock, production, returns, and delivery schema; no `expenses` alteration is present. |
| 41 | Adds sales invoicing schema and invoiced quantity; no expense change. |

Source search found one `CREATE TABLE ... expenses` definition in migration 10 and no `ALTER TABLE expenses`, expense-specific `CREATE INDEX`, or expense-specific trigger in the current migration source. `expenses.id` and `expenseNumber` have primary-key/unique constraints, which SQLite may implement with implicit autoindexes; those are not explicit expense index statements. The actual index list on an installed file was not queried.

### Documentation and test versions

| Source | Version stated | Interpretation |
| --- | ---: | --- |
| `lib/core/constants/app_constants.dart` | 41 | Current application target; authoritative. |
| `lib/core/database/furnexa_database.dart`, case 41 | 41 | Latest migration implemented in source. |
| `docs/technical/DATABASE_SCHEMA.md` | 41 | Consistent with source. |
| `docs/technical/KNOWN_ISSUES_AND_TECHNICAL_DEBT.md` | 41 | Consistent with source. |
| `docs/database.md` | 19 | Stale general guide; conflicts with source and technical docs. |
| `test/sales_delivery_migration_test.dart` | 41 | Explicitly asserts the current constant and fresh/migrated PRAGMA value. |
| Backup/recovery and migration tests with versions 20 or 27 | 20/27 | Historical fixture or old-version migration input, not a declaration of the current application target. |

The v19 versus v41 discrepancy is resolved for **current source**: v41 is authoritative, and `docs/database.md` is out of date. This audit does not edit documentation. A real SQLite file may still have an older `PRAGMA user_version` until the application opens and migrates it; because no database file was opened, the installed-file version remains unknown.

## 2. Database File Resolution and Initialization

The filename constant is `furnexa.db`. The resolver uses the following precedence:

1. Explicit test directory plus filename.
2. Explicit local-development path override.
3. `FURNEXA_DATABASE_PATH` environment variable.
4. On Windows, `%LOCALAPPDATA%\Furnexa\furnexa.db`; if this stable file is absent, source code may copy a non-empty legacy file from the executable directory's `.dart_tool\sqflite_common_ffi\databases\furnexa.db` or from `getDatabasesPath()\furnexa.db`.
5. Platform default `getDatabasesPath()\furnexa.db` on other/fallback paths.

The application creates the parent directory and opens the resolved file as part of normal startup. This audit did not call the resolver or open any of these paths.

- [Database filename and target version](../../lib/core/constants/app_constants.dart#L5)
- [Resolver precedence and Windows path](../../lib/core/database/database_path_resolver.dart#L35)
- [Database open and path resolver call](../../lib/core/database/furnexa_database.dart#L90)

## 3. Exact `expenses` Schema

The table is created in migration 10. Types and constraints below are copied from the current `CREATE TABLE` statement, not inferred from a live file.

| Column | SQLite type | Nullability in DDL | Default | Key / constraint |
| --- | --- | --- | --- | --- |
| `id` | `TEXT` | No explicit `NOT NULL` | None | `PRIMARY KEY` |
| `expenseNumber` | `TEXT` | `NOT NULL` | None | `UNIQUE` |
| `date` | `INTEGER` | `NOT NULL` | None | Stored by writer as `DateTime.millisecondsSinceEpoch` |
| `accountId` | `TEXT` | `NOT NULL` | None | FK to `accounts(id)` |
| `amount` | `REAL` | `NOT NULL` | None | `CHECK(amount > 0)` |
| `cashboxId` | `TEXT` | Nullable | None | FK to `cashboxes(id)` |
| `bankAccountId` | `TEXT` | Nullable | None | FK to `bank_accounts(id)` |
| `description` | `TEXT` | `NOT NULL` | None | Free text |
| `reference` | `TEXT` | Nullable | None | Generic text; no declared invoice/receipt semantics |
| `status` | `TEXT` | `NOT NULL` | None | `CHECK(status IN ('DRAFT','POSTED','REVERSED'))` |
| `createdAt` | `INTEGER` | `NOT NULL` | None | Writer uses epoch milliseconds |
| `updatedAt` | `INTEGER` | `NOT NULL` | None | Writer uses epoch milliseconds |

The `id TEXT PRIMARY KEY` declaration does not spell out `NOT NULL`; this report does not upgrade that declaration into an explicit nullability guarantee. No column has a declared default. The table-level check requires exactly one of `cashboxId` or `bankAccountId` to be non-null. The foreign keys use `ON DELETE RESTRICT` and default update behavior. There are no explicit expense indexes or triggers in source; the primary key and unique expense number create SQLite uniqueness constraints.

Source: [migration 10 expense table](../../lib/core/database/furnexa_database.dart#L1060).

## 4. Verified Relationship Map

### Direct foreign keys from `expenses`

| Expense column | Target | Verified meaning |
| --- | --- | --- |
| `accountId` | `accounts.id` | Expense is posted to an accounting account. The writer validates that the account's type is `EXPENSE`; the schema does not define a separate expense-category field. |
| `cashboxId` | `cashboxes.id` | Optional cashbox relation. |
| `bankAccountId` | `bank_accounts.id` | Optional bank-account relation. |

The table check permits exactly one cashbox or bank-account link. `cashboxes.accountId` and `bank_accounts.accountId` each reference `accounts.id`. These establish a coarse cashbox-versus-bank-account channel, not a complete payment-method taxonomy.

### Application-level and indirect relationships

| Relationship | Evidence | Limitation |
| --- | --- | --- |
| Expense to journal entry | `postExpense` writes a journal entry with `referenceType='EXPENSE'` and `referenceId=expenses.id` in the same transaction. `journal_entries` has `UNIQUE(referenceType, referenceId)`. | `referenceId` has no FK to `expenses`; integrity depends on application code. The unique constraint prevents two journal entries with the same non-null reference pair, not duplicate expense rows. |
| Expense to audit event | `postExpense` writes an audit row with `entityType='Expense'` and `entityId=expenses.id`; the helper records session `userId`, username snapshot, action, module, and timestamp. | `audit_logs.entityId` has no FK to expenses. This is an application-level association and can be absent for rows not created by this path. It records a posting actor, not a separate submitter/approver workflow. |
| Audit event to user | `audit_logs.userId` references `users.id` with `ON DELETE SET NULL`. | Indirect only through matching entity type/ID; username snapshot is identifying text. Do not export it raw. |
| Supplier to purchase order | `purchase_orders.supplierId` references `suppliers.id`. | No expense-to-supplier or expense-to-order FK exists. |
| Purchase order to request and receipt | Orders may reference a request; receipts reference orders and warehouses; request records reference suppliers. | This procurement chain does not join to `expenses` in the reviewed schema or expense writer. A purchase receipt is not a vendor invoice. |
| Factory to workshop | `sections.factoryId` and `workshops.factoryId/sectionId` define structure. | No expense factory/site/section/workshop FK exists. |
| Expense account to journal lines | Journal lines reference account and journal-entry rows. | Journal entries refer to expenses through the application reference pair, not a declared FK. |

### No verified expense relationship

- `suppliers`, `purchase_requests`, `purchase_orders`, and `purchase_receipts` exist, but no direct FK or expense repository join connects them to an expense.
- `sales_invoices` and `sales_invoice_items` are customer/sales-order structures introduced in v41; they are not accounts-payable invoices and do not link to expenses.
- `factories`, `sections`, `workshops`, and `warehouses` exist, but `expenses` has no corresponding foreign key. The schema contains no `departments` or `branches` table by those names.
- `users` and `roles` exist. `expenses` has no `createdBy`, `submittedBy`, `approvedBy`, or reviewer column. The audit relationship above is not a substitute for an expense approval record.
- No budget allocation, remaining-budget, authorization-limit, expense recurring-schedule, or scheduled-payment table/field was found in the expense schema/migration search. Costing/overhead and purchase-request status structures must not be reinterpreted as expense budgets or approvals.

Sources: [factory/workshop DDL](../../lib/core/database/furnexa_database.dart#L157), [procurement DDL](../../lib/core/database/furnexa_database.dart#L437), [accounting and ledger DDL](../../lib/core/database/furnexa_database.dart#L933), [security scopes and audit DDL](../../lib/core/database/furnexa_database.dart#L1141), [v41 sales invoices](../../lib/core/database/furnexa_database.dart#L3252).

## 5. Expense Lifecycle and Accounting Semantics

- The schema allows `DRAFT`, `POSTED`, and `REVERSED`; these are accounting statuses, not expense-review or approval outcomes. The create path shown in source inserts `POSTED`.
- `postExpense` accepts date, account ID, amount, description, optional cashbox or bank-account ID, and optional generic reference. It requires fresh `ACCOUNTING_POST` permission, validates positive amount and expense account type, then in one transaction inserts the expense, posts a two-line journal entry (debit expense account, credit selected money account), and writes an audit event.
- The method takes `DateTime` and stores epoch milliseconds. The source does not establish that the caller supplied a meaningful time-of-day or timezone; no caller of `postExpense` was found elsewhere in `lib/` during this audit.
- Generic `reverseJournal` creates a reversing journal and changes the journal entry status to `REVERSED`. No expense-row status update was found in that path. Do not infer that `expenses.status` tracks journal reversal without a verified call path.
- No expense-specific update/delete/cancel/reject workflow or soft-delete column was found. The schema itself does not prevent duplicate underlying invoices or repeat business expenses: `reference` is nullable and not unique, and the expense table has no operation/idempotency key. Actual duplicate frequency is unknown without authorized data.
- `journal_entries` and `journal_lines` are the basis for accounting statements. The dashboard's financial-total query sums posted journal lines grouped by account type; it is an aggregate ledger query, not an expense-row query.

Source: [expense writer and journal transaction](../../lib/features/accounting/data/datasources/accounting_local_data_source.dart#L837), [generic journal reversal](../../lib/features/accounting/data/datasources/accounting_local_data_source.dart#L570), [dashboard journal aggregation](../../lib/features/dashboard_reports/data/datasources/dashboard_reports_local_data_source.dart#L220).

## 6. Repository and Query Findings

1. `AccountingLocalDataSource.moduleCounts()` runs `SELECT COUNT(*)` for a fixed list including `expenses`; it does not retrieve expense rows or apply a factory/user-scope predicate. The accounting page's “expenses” module card displays that count and is not an expense-list query.
2. Source search found no `SELECT`/`db.query` of expense rows, nor expense-specific update/delete. The only expense-specific SQL write in the app source is the `postExpense` insertion. No caller for `postExpense` was found in `lib/`; its actual use at runtime is therefore unverified.
3. `purchaseCommitments()` joins approved/confirmed/partially received purchase orders to suppliers, but this remains a procurement query and has no expense link.
4. Account ledgers and dashboard financial totals query journal entries/lines. They can provide accounting aggregates and ledger lines, but not reliable supplier/category/site context for an expense row.
5. The Accounting page checks `ACCOUNTING_VIEW` for visibility; source role permissions and `requireFresh` enforce permission freshness. Those checks do not add a row-level factory predicate or an expense scope.

Sources: [module counts](../../lib/features/accounting/data/datasources/accounting_local_data_source.dart#L31), [accounting page module cards](../../lib/features/accounting/presentation/pages/accounting_page.dart#L142), [role permission/scope implementation](../../lib/features/users_roles_permissions/data/datasources/security_local_data_source.dart#L639).

## 7. Data Availability Matrix

“Available” below means the current code declares or writes a field. Because no representative database was opened, presence rates, historic coverage, actual values, and population semantics are unknown.

| Information | Readiness classification | Evidence and caveat |
| --- | --- | --- |
| Expense amount | Available and verified in schema | `expenses.amount REAL NOT NULL CHECK(amount > 0)`; actual populated values not inspected. |
| Expense date | Available and verified in schema; timestamp interpretation limited | `expenses.date INTEGER`; writer stores milliseconds since epoch. Caller/timezone/time-of-day semantics and historic consistency are unverified. |
| Expense category | Available but requires a verified mapping | `accountId` is required and validated as an `EXPENSE` account. No separate category column or approved account-to-category mapping is defined. |
| Department/workshop | Not available on expense rows | Workshops exist but no expense FK/join is defined. No `departments` table was found. |
| Site/factory/branch | Not available on expense rows | Factories exist, but expenses have no factory/site/branch key. |
| Vendor identity | Not available on expense rows | Suppliers exist but are linked to procurement records, not expenses. |
| Document references | Available but requires a verified mapping | `expenseNumber` is a unique internal expense number; nullable `reference` is generic text. Neither is verified as an invoice/receipt ID. |
| Submitter | Derived with a documented application-path assumption; coverage unknown | `postExpense` writes an audit record with session user and matching entity ID. No creator column or verified coverage for all expenses. |
| Approver | Not available | No expense approver field, approval history, or expense approval workflow found. |
| Accounting status | Available and verified in schema | `DRAFT`/`POSTED`/`REVERSED`; lifecycle semantics are accounting-only. Actual row distribution is unknown. |
| Payment method | Derived with a documented assumption | Exactly one cashbox/bank-account FK gives a coarse channel. It does not prove card, transfer, payee, or settlement method. |
| Currency | Not available on expense rows | No currency column or expense-currency mapping found; do not assume one currency. |
| Budget / authorization | Not available | No expense-linked budget or authorization-limit fields/table found. |
| Recurring schedule | Not available | No expense recurring flag, schedule, expected due date, or scheduled-payment relation found. |
| Actual database version and field coverage | Unknown because no representative database was accessed | Application target is 41; installed-file `PRAGMA user_version`, row counts, null rates, and legacy variation remain unknown. |

## 8. Factory Isolation and Privacy

### Isolation

The schema supports role permissions and user scopes for `SECTION`, `WORKSHOP`, `WAREHOUSE`, and `PRODUCTION_STAGE`. `canAccess` checks those scope/resource pairs, and resource tables have their own structure. There is no `EXPENSE` scope type, no factory/site key on `expenses`, and no expense repository query applying factory scope. Accounting access is gated by global accounting permissions in the inspected paths, not by an expense-to-factory association. Therefore factory-level isolation for expense rows **cannot be established from the current expense schema or inspected query paths**.

If future source rows are joined to factory/workshop structures, the relation must be explicit, validated, and effective-dated; similarly named account, supplier, purchase, or workshop data must not be used as a proxy. Until then, a multi-factory export risks cross-factory mixing.

### Sensitive values to exclude or pseudonymize before any AI export

- Exclude raw `expenses.id`, `expenseNumber`, unreviewed `description`, and generic `reference`; tokenize only after semantics are verified.
- Exclude raw account, cashbox, bank-account, supplier, purchase-order, receipt, user, and audit entity IDs. Use study- and factory-scoped pseudonyms only for fields the detector needs.
- Never export bank name, account name/number, supplier name/contact/address/tax number, user name/login/contact details, password hashes, or raw audit `oldValue`/`newValue`/description.
- Date, amount, rare account combinations, and repeated transaction patterns can identify a factory even after IDs are removed. Apply purpose-limited time shifting/coarsening and review quasi-identifier risk. Preserve the minimum timing/calendar features required for the selected detector inside an authorized environment.
- Free-text `description`, `reference`, supplier notes, and audit text are not safe feature columns. Prefer allow-listed structured fields and separate reviewer evidence tokens.

Schema does not imply encryption at rest, cloud synchronization, or cross-device tenancy. The general database guide describes an offline-first local store; export controls and pseudonymization remain necessary.

## 9. Documentation Inconsistencies and Limits

- **Resolved source discrepancy:** `docs/database.md` says database version 19; current source, migration case 41, test assertion, and technical schema documentation say 41. The general guide is stale; no documentation was changed in this audit.
- **Schema evidence boundary:** The prior AI schema report was generated by replaying migrations on a disposable empty database. It is useful corroboration of source DDL, not proof of the current installed file or any factory's data.
- **Test fixture versions:** Tests that migrate from 27/39/40 or encode backup versions 20/41 are fixtures and compatibility inputs. They do not override the `AppConstants.databaseVersion` target.
- **Unverified data reality:** No representative database was supplied or inspected. It is unknown whether a deployed database is currently at v41, whether migrations have succeeded on it, how expense fields are populated, or whether legacy data differs.
- **No runtime execution:** No database resolver, production inspection task, test suite, migration, or repository query was executed during this audit.

## 10. Minimum Snapshot Contract for Future AI Evaluation

Do not build an expense evaluation snapshot from `expenses` alone and label inferred context as fact. A future, separately authorized snapshot should be versioned and include:

1. **Eligibility and time:** pseudonymous expense token; source schema version; as-of/scoring timestamp; transaction date/time with verified timezone/precision; accounting status as of scoring time; exclusion rules for reversed/draft records.
2. **Financial facts:** positive amount, verified ISO currency code, and a pseudonymous account token plus a separately versioned account-to-expense-category mapping. Do not treat the account's `EXPENSE` type as a category.
3. **Organization context:** factory/site, department/workshop, cost center/project only when a validated expense-to-organization relationship exists. Include mapping version and effective dates. Do not infer these from supplier, account, purchase order, or a nearby workshop.
4. **Payment and party context:** coarse cashbox/bank channel if needed; pseudonymous vendor/payee and invoice/receipt/PO tokens only after an authoritative expense linkage is implemented or otherwise verified. Never include bank details or raw document references.
5. **Policy/schedule context:** effective-dated budget, authorization limit/level, recurring schedule, expected due date, timezone/business calendar only if these are actually maintained and available at scoring time.
6. **Features versus labels:** separate immutable keyed outcome data from features. Reviewer dispositions, reasons, policy findings, evidence acquired after score time, approval outcomes, and synthetic scenario/severity labels are label-only and never enter model features. Join labels only after predictions are fixed.
7. **Privacy and isolation:** factory-scoped pseudonyms, removal of direct IDs and free text, an allow-listed feature schema, separate key/re-link storage, access logging, retention/deletion policy, and a test proving no row crosses factory boundaries.

### Readiness blockers before any shadow evaluation

- Reconcile the current database documentation and independently confirm an authorized schema-only version/mapping; do not query or export rows until approved.
- Identify whether `postExpense` is used by a supported UI/workflow and establish the actual eligible expense lifecycle.
- Provide validated currency and account/category semantics.
- Provide a direct, auditable expense-to-site/department and (if needed) supplier/document mapping; current schema does not supply these.
- Define approval, budget, recurring, and policy sources if detectors require them.
- Establish per-factory isolation, privacy authority, review protocol, and sample-selection policy before collecting any human-reviewed labels.

## Verification Record

This audit is based on current source code, current test/document text, and the prior disposable-schema report only. It does not claim verification against a populated or representative SQLite database. No production database access, SQLite reads/writes, schema/migration edits, Flutter changes, AI experiment changes, or tests were performed. Existing datasets, reports, notebooks, and benchmark outputs were left untouched.
