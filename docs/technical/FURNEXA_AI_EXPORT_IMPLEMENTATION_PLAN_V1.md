# Furnexa AI Export Implementation Plan V1

**Status:** Implementation-ready design only. Coding and database changes require approval after product-owner decisions are closed.

## 1. Implementation Goal

Add a purpose-specific Sales Fact export boundary that:

- Authenticates an active user.
- Requires `AI_DATA_EXPORT` unless an approved alternate policy replaces it.
- Accepts one explicit factory request.
- Resolves authorized warehouses and proves warehouse-to-factory membership.
- Queries Sales facts only through SQL-time predicates.
- Rejects ambiguous parent/child relationships.
- Separates delivered demand, accepted returns, and rejected/quarantined quantities.
- Writes an audit manifest for every attempt.

This plan intentionally does not modify existing Sales business operations or existing permissions until approved.

## 2. Implementation Sequence

### Phase 1: Permission and Policy Decision

1. Product owner approves the initial System Admin policy.
2. Product owner approves `AI_DATA_EXPORT` as a permission code or approves a different identifier.
3. Product owner approves single-factory versus cross-factory exports.
4. Product owner approves fail-whole-snapshot versus partial-with-exclusion-manifest behavior.

**Database change later:** add the permission seed and role mapping through the existing migration mechanism. No `ScopeType.factory` redesign is proposed.

### Phase 2: Authorization Contract Unit

Add or update a service in the existing users/security feature if implementation is approved.

Responsibilities:

- Validate active authenticated session.
- Validate `AI_DATA_EXPORT` independently of UI state.
- Validate explicit factory ID exists and is unique.
- Resolve warehouse scopes.
- Query warehouse/factory joins.
- Return a frozen resolved export scope containing:
  - factory ID
  - authorized warehouse IDs
  - authorization mode
  - request user/role

Fail if:

- No active session.
- Permission missing.
- Factory missing or unknown.
- No warehouse scope for a normal user.
- No warehouse in the requested factory.
- Warehouse/factory joins are inconsistent or ambiguous.

### Phase 3: Sales Delivery Query

Build the export query in the Sales data-source/repository boundary or a dedicated read-only export service approved for that responsibility.

The query must:

- Require `sd.status = 'DELIVERED'`.
- Require `sd.inventoryPosted = 1`.
- Join `warehouses` and `factories`.
- Filter `f.id = requestedFactoryId`.
- Filter `w.id IN resolvedAuthorizedWarehouseIds`.
- Join `sales_delivery_items` and exact `sales_order_items`.
- Require exact order-line consistency.
- Require verified identity fields.
- Exclude or block invalid rows according to the approved ambiguity policy.

Do not use `sales_orders.quantity`, invoice quantity, or UI order quantity as the demand fact.

### Phase 4: Accepted Return Query

Join only the verified chain:

- `sales_returns -> warehouses -> factories`
- `sales_return_items -> sales_returns`
- `sales_return_items.sourceDeliveryItemId -> sales_delivery_items`
- source delivery item -> source delivery
- return receipt -> receipt items -> return item
- Sales Return quality inspection -> inspection items -> source return item

Require:

- Exact return, source delivery, receipt, and inspection warehouse consistency.
- Exact source order and return order consistency.
- Completed and reconciled quality evidence.
- Accepted transfer/posting evidence under existing Sales Return business semantics.

Return only accepted quantity as a negative demand adjustment. Keep rejected and quarantined quantities as separate fields/status facts.

### Phase 5: Coverage and Identity Manifest

Include a manifest separate from the facts:

- Export contract version.
- Requested factory.
- Resolved warehouse IDs.
- Observation start/end period.
- Delivered-row count.
- Accepted/rejected/quarantined row counts.
- Excluded delivery/return counts by reason.
- Missing identity count.
- Missing historical-period identifiers.
- Verifiable stockout-period count if later approved.
- Authorization decision.
- Query/contract timestamp and audit ID.

Missing periods must be explicit. Do not serialize them as observed zero values.

### Phase 6: Audit

Use or extend the existing `SecurityLocalDataSource.audit()` pattern.

At minimum:

- Action: `AI_EXPORT_ATTEMPT` or `AI_EXPORT_SUCCESS`/`AI_EXPORT_DENIED` as approved.
- Module: `AI`.
- Entity type: `SalesFactExport`.
- Entity ID: export request ID or audit ID.
- Description: sanitized scope summary, period, contract version, and counts.

Avoid raw payload values and customer PII in audit text unless explicitly approved.

### Phase 7: Focused Tests

Add synthetic cross-factory tests only after implementation approval:

1. Normal user authorized to one warehouse/factory succeeds only for that factory.
2. Normal user has no warehouse scope and is denied.
3. Normal user requests a factory outside their warehouses and is denied.
4. Delivery order spans two warehouses/factories; each fact resolves only to its own delivery warehouse.
5. Cross-factory delivery item/order mismatch is rejected.
6. Return with cross-warehouse source delivery is rejected.
7. Return receipt in wrong warehouse is rejected.
8. QC inspection/item belongs to a cross-factory return and is rejected.
9. Accepted/rejected/quarantined quantities remain separate.
10. `inventoryPosted = 0` delivery is excluded.
11. Unverified identity is excluded or blocks the snapshot under approved policy.
12. System Admin follows the approved Option A or C policy and cannot bypass the factory contract.
13. Missing scope produces no export payload and an audit denial.

## 3. Existing Components to Reuse

- `SecurityLocalDataSource.require()` and session data.
- `authorizedWarehouseIds` for warehouse scope discovery.
- Existing immutable `audit_logs` and `SecurityLocalDataSource.audit()`.
- Prompt 23 warehouse and parent-chain SQL patterns.
- Existing permission/role seed and role-permission mapping architecture.
- Existing migration mechanism for the future `AI_DATA_EXPORT` permission seed.

## 4. Components Not to Reuse

- `ImportExportLocalDataSource.exportData()` as the Sales AI exporter.
- `orders()` or order-level reports as demand facts.
- Invoice or quotation quantities.
- Dashboard product/customer totals.
- Global search Sales order results.
- Dart post-query filtering as the export authorization boundary.
- System Admin auto-bypass as export permission or factory authorization.
- UI selected factory without server-side validation.

## 5. Recommended Implementation Sequence

```text
1. Approve policy and export scope
2. Add AI_DATA_EXPORT permission (future implementation only)
3. Add export-scope resolver
4. Add SQL delivery fact query
5. Add accepted-return fact and rejection manifest
6. Add audit attempt/result records
7. Add synthetic export/security tests
8. Run focused diagnostics/tests
9. Implement no snapshot generation or external AI call until audit passes
```

## 6. Exact Product-Owner Decisions Before Coding

1. Initial System Admin policy: C recommended, A after explicit approval, B deferred.
2. Whether to export a partial snapshot or reject the whole snapshot on ambiguous records.
3. Whether `inventoryPosted = 1` plus delivery status is sufficient, or exact stock transaction matching is mandatory.
4. Exact completed/accepted return status and posting evidence.
5. Whether historical null QC source links remain read-compatible but export-blocked.
6. Whether the export is Sales only or includes a future consolidated AI module contract.
7. Period granularity and exact missing-period representation.
8. Audit retention and which manifest fields are permitted.
9. Dedicated cross-factory permission name and policy, if any.

## 7. Verification Gates Before Implementation

- Existing Prompt 23 focused security tests must have a definitive pass/exit status.
- Prompt 24 remains the accepted export-boundary source.
- No production database access or business-row reads in export test setup.
- Synthetic test databases only.
- No schema or migration change until the permission seed decision is approved.
- No export payload or AI snapshot is created during implementation verification.

## 8. Deliverable Status

This plan is complete as design. It does not implement code, permissions, migrations, audit records, or snapshots. Implementation starts only after explicit approval.