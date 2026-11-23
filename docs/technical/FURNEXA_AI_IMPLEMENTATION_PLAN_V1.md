# Furnexa AI Implementation Plan V1

**Status:** Local implementation-ready design. No implementation is approved or started by this document.

## 1. Smallest Implementation Sequence

```text
1. Approve the permission and forecast-contract decisions.
2. Add a fixed Sales demand extraction method behind the existing authorized data layer.
3. Transform extracted delivery/return facts into an allow-listed Flutter-owned JSON payload.
4. Launch the existing Python .venv interpreter with one fixed local analysis entrypoint.
5. Bind Python to loopback and require a per-process secret.
6. Send the approved Sales contract to Python.
7. Return validated forecast/results JSON to Flutter.
8. Display results without mutation controls or auto-apply.
9. If an operation is proposed later, require explicit confirmation and reuse existing mutation services.
10. Add audit, timeout, cleanup, and synthetic integration tests.
```

## 2. Phase 1: Contract Decisions

Before coding, the product owner should approve:

- Gross delivered demand or net accepted-return demand as the primary target.
- Return date semantics.
- Warehouse versus factory-wide forecast grain.
- Observed-zero and missing-period rules.
- Stockout feature inclusion, initially no.
- Minimum permission: existing `SALES_VIEW`/`RETURNS_VIEW`/`QUALITY_VIEW`, or a later dedicated `AI_ANALYZE` permission.

No `AI_DATA_EXPORT` permission is recommended for the first local implementation.

## 3. Phase 2: Flutter Authorized Extractor

Add no direct AI database access. Add a read-only service that:

- Requires the active session.
- Requires existing Sales/Return/QC view permissions.
- Uses Prompt 23 delivery/return warehouse predicates or existing warehouse filtering patterns.
- Runs fixed parameterized queries.
- Excludes `orders`, `invoices`, quotations, and global summaries.
- Reconciles verified delivery and accepted-return facts.
- Converts source IDs to opaque local analysis keys or excludes them.
- Creates an `observedCoverage` and missing-period manifest.

The extractor should operate behind the existing repository/service boundary and not expose raw SQL or arbitrary table names.

## 4. Phase 3: Local Process Bridge

Implement a minimal Flutter process bridge:

- Resolve the project/runtime Python executable from the packaged application configuration.
- Use the existing `.venv` interpreter for development runs only after runtime packaging is designed.
- Start one fixed Python entrypoint.
- Bind to `127.0.0.1` on an ephemeral port.
- Generate a per-process secret.
- Limit payload bytes and history length.
- Set startup, request, and shutdown timeouts.
- Stop the process on Flutter shutdown.

Do not add a general remote API, service broker, or external AI gateway.

## 5. Phase 4: Python Analyzer

Reuse only the existing demand preprocessing and forecasting modules that operate on tabular data.

Python entrypoint responsibilities:

- Validate the Sales contract version.
- Validate allowed fields and finite values.
- Build calendar coverage with explicit missing states.
- Run the existing demand forecasting functions.
- Return result and diagnostic JSON.

Python entrypoint restrictions:

- No database imports or SQLite path arguments.
- No file paths supplied by the network request.
- No external network calls.
- No mutation or business operation API.
- No persistent business-row payload storage.

## 6. Phase 5: UI and Approval

Add read-only analysis UI:

- Show analysis status and coverage summary.
- Show forecast and uncertainty only after validation.
- Show missing-period and excluded-row counts.
- Label predictions as recommendations, not confirmed Sales facts.
- No auto-apply action.
- Any future action uses the existing authorized UI/business workflow and explicit confirmation.

## 7. Phase 6: Audit and Cleanup

Add audit entries for:

- Request denied.
- Analysis requested and started.
- Input validation failure.
- Successful completion.
- Timeout or process failure.
- Temporary resource cleanup.

Use the existing `audit_logs` schema and `SecurityLocalDataSource.audit()` pattern.

Avoid temporary files. If temporary files are unavoidable:

- Use OS temp storage.
- Restrict permissions.
- Delete on all exits.
- Do not audit file contents or database paths.

## 8. Phase 7: Focused Tests

The implementation should be covered by synthetic tests:

- Authorized delivery extraction succeeds.
- Empty warehouse scope fails closed.
- `inventoryPosted = 0` is excluded.
- Undelivered delivery is excluded.
- Unverified identity is excluded.
- Cross-warehouse source delivery/return chain is rejected.
- Accepted, rejected, and quarantined quantities remain separate.
- Missing dates remain missing and are not converted to zero.
- Observed zero dates remain observed zero.
- Orders and invoices do not enter the payload.
- Python rejects unknown fields and malformed quantities.
- Python cannot open an SQLite path or write a business operation.
- Loopback-only binding and per-process token checks pass.
- Timeout and process shutdown clean up correctly.
- Audit attempts include no raw payload.

Use synthetic databases and synthetic payloads only. Do not access production business data.

## 9. Existing AI Components to Reuse

- Existing demand calendar-grid preprocessing.
- Existing observed/missing/observed-zero semantics.
- Existing sales forecasting modules and benchmark code.
- Existing synthetic data and synthetic validation utilities.
- Existing project `.venv` interpreter for local development.

Do not create or replace `.venv`.

## 10. Components Not to Reuse

- `ImportExportLocalDataSource.exportData()` for AI payload generation.
- `SYSTEM_ADMIN` as the normal AI authorization check.
- Global Sales order queries.
- Invoice or quotation quantities.
- Dashboard or global-search summaries.
- Direct Python SQLite access.
- Cross-factory authorization because one installation owns one factory database.

## 11. Verification Gates

Before implementation approval:

- Product decisions in Phase 1 are documented.
- Prompt 23 security tests have definitive pass status.
- Data contract is accepted by Sales/Operations and AI owners.
- Existing synthetic sales validation passes.
- No production business-row access is used in tests.
- No schema or migration change is planned.

## 12. Implementation Status

This plan creates no source code, Python process, API, snapshot, database row, migration, or permission. Implementation begins only after explicit approval.