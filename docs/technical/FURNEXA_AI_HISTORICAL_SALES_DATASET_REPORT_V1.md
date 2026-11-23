# Furnexa AI Historical Sales Dataset Report V1

**Status:** Implemented at the authorized local data boundary. No model training or business action was implemented.

## Implemented Files

- `lib/features/ai/data/historical_sales_dataset_builder.dart`
- `lib/features/ai/data/sales_ai_payload_builder.dart` (base-unit and duplicate-line evidence added)
- `src/api/local_ai_service.py` (historical dataset endpoint added)
- `test/historical_sales_dataset_builder_test.dart`
- `tests/test_local_ai_service.py` (historical endpoint tests)

## Data Flow

```text
Authenticated Flutter service
  -> existing Sales AI payload builder
  -> exact stock-reconciled Sales observations
  -> HistoricalSalesDatasetValidator
  -> allow-listed JSON historical dataset
  -> loopback FastAPI/Pydantic validator
  -> structured coverage response
```

Python never receives SQLite access, database paths, SQL, or business mutation commands.

## Historical Dataset Structure

Each row contains:

- `date`
- pseudonymous `product_id`
- pseudonymous `variant_id`
- pseudonymous `warehouse_id`
- pseudonymous `base_unit_id`
- `delivered_quantity`
- `accepted_return_quantity`
- `net_demand_quantity`
- `observed_coverage`
- `exclusion_count`
- `data_quality_flags`

Missing observations remain `observed_coverage=false` and `MISSING_PERIOD`; they are not converted to zero.

## Dart Validation

The historical validator rejects or reports:

- Duplicate identity/date rows.
- Negative or impossible quantities.
- Net quantity inconsistent with delivered minus accepted return.
- Missing date/product/warehouse identity.
- Unit mismatch for a warehouse/product/variant identity.
- Unmatched return exclusions from excluded coverage metadata.
- Insufficient observed history at a configurable minimum.
- Out-of-period observations.
- Missing calendar dates.

Rows are sorted by date, warehouse, product, and variant.

## Python Validation

The Python endpoint `/v1/datasets/sales-historical` validates:

- Pydantic schema and allow-listed fields.
- Period consistency.
- Coverage period consistency.
- Duplicate warehouse/product/variant/date rows.
- Unit consistency per warehouse/product/variant.
- Missing-period flags.
- Negative quantities and net quantity consistency.
- Payload authorization through the existing per-process bearer token.

## Duplicate and Reconciliation Evidence

- The Sales payload builder tracks duplicate delivery item IDs.
- Prompt 27 exact stock reconciliation remains mandatory for accepted returns.
- Duplicate exact return references remain excluded.
- Rejected and quarantined quantities remain diagnostic exclusions, not demand reductions.

## Coverage Report

The coverage report includes:

- Period and row counts.
- Identity and observed/missing counts.
- Observed-zero and observed-positive counts.
- Total exclusions.
- Duplicate, negative, missing identity, unit mismatch, unmatched return, missing date, and warehouse-scope counts.
- Insufficient coverage state.
- Structured data-quality flags.

## Test Results

Dart historical dataset tests: **8 passed**.

Python local AI service tests: **10 passed**.

Narrow Dart analysis: **No issues found**.

Python TestClient produced one existing Starlette deprecation warning; it did not fail tests.

## Constraints Verified

- No production database or business rows accessed.
- No SQLite import or database path exists in Python.
- No SQLite schema or migration changed.
- No business record was modified.
- No global Import/Export exporter was used.
- No external network endpoint is used by the Python service.
- No model training or autonomous business action was implemented.
- Existing `.venv` was used; it was not recreated or replaced.
