# Furnexa AI Local Bridge Implementation Report V1

**Status:** First production boundary implemented at design/spec level, without model training or autonomous actions.

## Implemented

### Python local API

- Added `src/api/local_ai_service.py`.
- Uses FastAPI and Pydantic in the existing Furnexa AI `.venv`.
- Binds Uvicorn exclusively to `127.0.0.1`.
- Uses an ephemeral port supplied by Flutter at process startup.
- Requires `FURNEXA_LOCAL_AI_TOKEN` on health and analysis endpoints.
- Rejects oversize requests with the HTTP 413/400 paths.
- Validates Sales payload fields, date ranges, duplicate identities, state semantics, finite quantities, and missing/zero distinctions.
- Provides `GET /health` and `POST /v1/analyze/sales-demand`.
- Contains no SQLite import, database path, file access, business mutation, or external network call.

### Flutter bridge

- Added `lib/features/ai/data/local_ai_process_bridge.dart`.
- Starts a fixed Python entrypoint only through `start(...)`.
- Prevents duplicate starts with a `_startFuture` guard.
- Chooses an unused loopback port.
- Creates a cryptographically random per-process bearer token.
- Performs a readiness health check.
- Applies startup and request timeout handling.
- Stops the process on app detached/dispose lifecycle events.
- Returns structured `LocalAiBridgeException` states for unavailable and timeout conditions.

### Flutter Sales payload builder

- Added `lib/features/ai/data/sales_ai_payload_builder.dart`.
- Requires fresh `SALES_VIEW`, `RETURNS_VIEW`, and `QUALITY_VIEW` permissions.
- Uses fixed parameterized SQL against the local database.
- Includes only `DELIVERED` and `inventoryPosted = 1` deliveries.
- Joins delivery items to exact order items.
- Requires `identitySnapshotStatus = 'VERIFIED'` and verified base-unit/conversion fields.
- Filters to authorized warehouses for normal users.
- Adds missing calendar observations as `demand_state=missing` rather than zero.
- Aggregates observed dates as positive or observed-zero.
- Keeps accepted return quantity separate and removes rejected/quarantined quantity from net demand.
- Does not include quotations, orders, invoices, customer data, or global summaries.
- Does not reuse the Import/Export exporter.

### Lifecycle and dependencies

- Wired the singleton `FurnexaApp.aiBridge` into app lifecycle stop handling.
- Added FastAPI, Uvicorn, and Pydantic to the AI workspace requirements.
- Did not recreate or replace `.venv`.

## Focused Verification

### Python

Command used:

```text
.venv/Scripts/python.exe -m pytest -q tests/test_local_ai_service.py
```

Result: **7 passed**.

Covered:

- Loopback host source check.
- Unauthorized health request rejection.
- Unknown payload field rejection.
- Missing versus observed-zero distinction.
- Payload-size limit is explicit.
- Rejected/quarantined diagnostics remain separate.
- No SQLite or business mutation API is present in the service source.

The FastAPI TestClient warning is a dependency deprecation warning; it did not fail tests.

### Flutter

Command used:

```text
flutter test test/local_ai_bridge_test.dart test/local_ai_payload_builder_test.dart
```

Result: **6 passed**.

Covered:

- Service unavailable handling.
- Timeout/unavailable exception distinction.
- Missing versus observed-zero state separation.
- Unauthorized payload builder denial.
- Fail-closed source eligibility for delivered/inventory-posted/verified identity rows.
- Missing versus observed-zero source states remain separate.

VS Code diagnostics and a narrow `dart analyze` pass reported no issues in the new AI source and test files.

## Remaining Relationship Blocker

The accepted-return reconciliation code is implemented as a proposed fail-close query, but the exact existing posting evidence remains an implementation contract decision:

- The payload currently accepts completed Sales Return status, completed QC, receipt reconciliation, source delivery match, `sourceDelivery.inventoryPosted = 1`, and an accepted/rejected/quarantined-to-inspected quantity reconciliation.
- Identity tokens are HMAC-SHA-256-derived local payload tokens; a per-builder random HMAC key prevents reversible export of source IDs.
- The return date is chosen as receipt date where available, otherwise return date.
- Product owner approval is still required for the exact accepted-return posting date and whether exact stock transaction/reference matching is mandatory in addition to delivery/receipt return posting evidence.

Rows outside this verified chain are excluded and not silently converted into accepted demand.

## Security Boundaries Verified

- Python has no SQLite dependency or database path argument.
- Python has no business mutation method.
- Flutter remains the only source of SQLite data.
- Loopback binding is explicit.
- Every HTTP endpoint uses a per-process bearer secret when configured.
- The payload builder requires existing read permissions.
- Missing warehouse scope fails closed for normal users.
- Rejected/quarantined quantities do not reduce demand.
- Missing target dates remain missing.

## Not Implemented

- No model training.
- No AI forecast algorithm execution in the local API.
- No UI AI page or recommendation workflow.
- No automatic purchase, sales, production, accounting, or inventory action.
- No production database access.
- No snapshot creation.
- No AI result persisted in the business database.
- No schema or migration change.
- No global Import/Export exporter reuse.

## Files Added or Changed

### Furnexa

- `lib/features/ai/data/local_ai_process_bridge.dart`
- `lib/features/ai/data/sales_ai_payload_builder.dart`
- `test/local_ai_bridge_test.dart`
- `test/local_ai_payload_builder_test.dart`
- `lib/main.dart`

### Furnexa AI

- `src/api/__init__.py`
- `src/api/local_ai_service.py`
- `tests/test_local_ai_service.py`
- `requirements.txt`
