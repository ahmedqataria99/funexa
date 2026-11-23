# Furnexa AI Export Authorization Design V1

**Status:** Design-only. No implementation, schema change, permission change, database access, or snapshot generation.

## Existing Architecture

### Authentication

- `SecurityLocalDataSource` holds one static active `SecuritySession`.
- Login requires an active user and active role and loads role permissions and user scope rows.
- `SecuritySession.can(permission)` allows system roles automatically; otherwise it requires the permission code and rejects `SYSTEM_ADMIN` by name from normal permission sets.
- `require(permission)` checks active session, active user, active role, and permission.

**Verified existing behavior.**

### Permission model

- Permissions have `id`, unique `code`, `module`, and `action`.
- Role permissions are many-to-many through `role_permissions`.
- System Admin is seeded with the initially known permissions and later permission codes are inserted and added to the System Admin role in migrations.
- Existing modules follow codes such as `SALES_VIEW`, `SALES_EDIT`, `SALES_DELIVER`, `RETURNS_VIEW`, `QUALITY_VIEW`, and `AUDIT_VIEW`.

A dedicated permission can fit this model. Proposed identifier: **`AI_DATA_EXPORT`**, module `AI`, action `EXPORT`.

This document proposes the identifier only. It does not alter permissions or role mappings.

### Scope model

- `ScopeType` is `section`, `workshop`, `warehouse`, or `productionStage`.
- There is no `ScopeType.factory`.
- `canAccess` is an exact scope match, except system roles bypass scope checks.
- `authorizedWarehouseIds` derives only warehouse scope rows from the active session.
- The warehouse table has `factoryId -> factories.id`.
- Factory structure data exposes `getFactory()`, which reads the first factory row rather than a persisted active-factory/session selection.

**Verified existing behavior.**

### Existing authorization patterns

- Repository/data-source operations call `security.require(...)` for operation permission.
- Resource mutations call `requireResourceScope(ScopeType.warehouse, warehouseId)`.
- Prompt 23 Sales/Return reads use SQL-level warehouse predicates and fail closed for empty non-admin scope.
- `audit_logs` exists and is immutable for update/delete. `SecurityLocalDataSource.audit()` provides a standard audit entry API.
- Existing `ImportExportLocalDataSource.exportData()` requires `SYSTEM_ADMIN`, reads selected module tables globally, and does not use a factory boundary. It is not suitable for AI Sales export and must not be reused as an authorization precedent.

## Authorization Contract

Before any AI Sales snapshot is generated, the export service must require all of the following:

1. **Authenticated active session**
   - Session exists.
   - `SecurityUser.active == true`.
   - `SecurityRole.active == true`.

2. **Dedicated export permission**
   - Require `AI_DATA_EXPORT` explicitly.
   - The dedicated permission check must not rely on `SecuritySession.can()` alone if System Admin auto-bypass is retained, because that would make the AI policy implicit.
   - Require an actual role-permission grant unless an approved, separate cross-factory policy says otherwise.

3. **Factory selection**
   - Accept an explicit `factoryId` argument.
   - Reject a missing, unknown, inactive, or ambiguous factory selection.
   - Do not derive export scope from UI context or `getFactory()` unless it is the explicitly approved and validated request parameter.

4. **Factory and warehouse verification**
   - Resolve all authorized warehouse IDs.
   - Query `warehouses` for `warehouse.id IN (...) AND warehouse.factoryId = requestedFactoryId`.
   - Reject no-warehouse scope, no resolved factory, and no authorized warehouses in the requested factory.
   - Query each candidate row with a warehouse/factory join; never use the warehouse ID alone as authorization.

5. **SQL-level filtering**
   - Apply factory and warehouse predicates inside SQL before materializing export rows.
   - Filter child rows through already scoped parents.
   - Do not fetch cross-factory rows and remove them in Dart.

6. **Parent-child consistency**
   - Delivery item: exact delivery and order-line parent.
   - Return: exact return warehouse, order, and optional source delivery relationship.
   - Receipt: receipt belongs to the return and receipt warehouse matches the authorized return chain.
   - QC: inspection belongs to the authorized Sales Return chain and source return item; a non-null source link must resolve exactly.

7. **Ambiguity rejection**
   - Reject or exclude inconsistent, orphan, cross-factory, cross-warehouse, duplicate, or unverifiable records.
   - Never infer a variant, factory, source delivery, or accepted quantity from UI state.

8. **Audit event**
   - Record a manifest/attempt before or atomically with export generation.
   - Record user ID/username snapshot, permission decision, requested factory, resolved warehouse set, row counts, excluded-record counts, contract version, and start/end period.
   - Do not record raw customer or row payloads unless separately approved.
   - Use `audit_logs` and immutable-log expectations already in the schema.

9. **Fail closed**
   - Any missing prerequisite returns no export payload.
   - Empty warehouse scope returns zero allowed rows and no cross-factory fallback.
   - Ambiguity or inconsistent parent data blocks the affected fact or the full export. The proposed implementation plan recommends block the full snapshot unless a product-approved partial-export manifest is defined.

## Existing Checks versus Missing Checks

| Check | Existing | Missing |
|---|---|---|
| Authentication | Yes | AI-purpose validation |
| Dedicated AI export permission | No | `AI_DATA_EXPORT` and role mapping |
| Explicit active factory | No factory scope/session field | Validated request factory |
| Warehouse-to-factory proof | Schema and joins exist | Service-level factory resolver |
| Prompt 23 Sales/Return warehouse filtering | Partial: deliveries and returns | AI export-specific SQL contract |
| Parent/child consistency | Prompt 23 partial coverage | Complete Sales fact validation |
| Ambiguity rejection | Partial for return/delivery | Export manifest and fail-closed fact rules |
| Audit event | Generic `audit_logs` and `audit()` | Export-specific action and manifest |
| Empty scope | Prompt 23 Sales/Return paths | Dedicated export denial |
| Cross-factory policy | No | Explicit approved policy and optional separate permission |

## Required Permission Semantics

The proposal is:

- `AI_DATA_EXPORT`: permission to request and create a factory-scoped Sales snapshot.
- `AI_DATA_EXPORT_CROSS_FACTORY`: separate permission for a multi-factory request; not recommended until product approval.

Permission architecture supports these codes without redesign. The implementation should not grant cross-factory capability merely because the user is System Admin or because the permission code exists in `SALES_VIEW`.

## Product-Owner Decisions Required

1. Exact scope of `AI_DATA_EXPORT`: Sales only, or all future AI modules.
2. Whether one factory only is the initial contract.
3. Whether System Admin requires C, A, or B policy.
4. Whether a partial export with an exclusion manifest is permitted or whether any ambiguity rejects the entire snapshot.
5. Which audit fields and retention policy are required.
6. Whether raw export files remain on disk or are returned only to approved UI/process contexts.

## Design Boundary

No implementation was made. This design does not authorize the existing `ImportExportLocalDataSource`, does not add a factory scope enum, and does not change the permission table or system-admin behavior.