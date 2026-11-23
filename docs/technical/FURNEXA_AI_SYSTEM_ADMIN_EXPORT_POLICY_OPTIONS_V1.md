# Furnexa AI System Admin Export Policy Options V1

**Status:** Proposed policy alternatives. No policy is implemented.

## Existing System Admin Behavior

Verified in `SecuritySession`:

- `isSystemAdmin` is true for `role.isSystemRole`, not merely role name.
- `can(permission)` returns true for every permission except `SYSTEM_ADMIN` itself.
- `canAccess(type, resourceId)` returns true for every scope/resource pair.
- `authorizedWarehouseIds` derives warehouse scope rows and is empty for admins if they have no warehouse scope rows.
- Prompt 23 deliberately preserves unrestricted warehouse behavior for system roles.
- `ImportExportLocalDataSource` uses `require('SYSTEM_ADMIN')` and exports module tables globally with no factory boundary.

This behavior is appropriate for existing application administration only. It must not be automatically treated as authorization for AI factory export.

## Option A: Explicit Current/Selected Factory

**Policy:** System Admin may export only the factory explicitly selected by the export request. They must pass the dedicated permission check and resolve at least one authorized warehouse in that factory.

**Advantages:**

- Preserves a single-factory contract.
- Uses the existing warehouse/factory relationship for scope proof.
- Avoids implicit cross-factory access.
- Can fit a dedicated `AI_DATA_EXPORT` permission.

**Risks:**

- A factory selection mechanism must be explicit and server-validated.
- System Admin warehouse scope rows must not be inferred or bypassed inconsistently.
- UI selected factory alone is not enough; request factory must be verified against warehouse data.

## Option B: Cross-Factory Permission

**Policy:** A separately named permission, such as `AI_DATA_EXPORT_CROSS_FACTORY`, permits a selected set or all factories. Normal `AI_DATA_EXPORT` remains one-factory. Cross-factory export requires an explicit factory list and per-factory warehouse resolution.

**Advantages:**

- Allows controlled enterprise/central AI operations.
- Separates ordinary factory export from aggregate export.
- System Admin alone does not imply the extra capability.

**Risks:**

- Aggregate facts can be mixed only if factory IDs remain explicit.
- The contract needs a stronger audit and approval model.
- Existing architecture has no direct factory grant; implementation would need request scope plus SQL resolution, not a new scope redesign.

## Option C: No AI Export for System Admin Until Approved

**Policy:** System Admin cannot export AI data by virtue of the role. A non-admin role must receive `AI_DATA_EXPORT`, and the export service must resolve warehouse/factory scope. Any future system-admin AI policy requires product approval and an explicit implementation change.

**Advantages:**

- Safest default.
- Prevents role bypass from turning into a cross-factory export path.
- Maintains least privilege until the data boundary is proven end to end.

**Risks:**

- System Admin cannot use the first export implementation unless it is assigned the dedicated permission and factory scope.
- It may temporarily reduce administrative operational convenience.

## Recommendation

**Recommended initial policy: C, with a future-approved transition to A.**

C is safest because the existing role model treats System Admin as a complete permission and warehouse-scope bypass. Without a dedicated export policy, the role's existing behavior cannot prove factory consent.

Once product owners approve an explicit factory selection workflow, implementation may use A: System Admin can export only a requested, verified single factory, not all factories, and only under `AI_DATA_EXPORT`. B should remain blocked until a cross-factory use case and separate permission are approved.

## Policy Comparison

| Policy | Cross-factory by role alone | Factory selection required | Separate permission | Recommendation |
|---|---|---|---|---|
| A | No | Yes | `AI_DATA_EXPORT` | Suitable after C approval |
| B | No; but explicit cross-factory permission | Yes, per factory | `AI_DATA_EXPORT_CROSS_FACTORY` | Future only |
| C | No | Yes if ever enabled | Dedicated policy grant | Safest now |

## Recommended Implementation Guard

Before implementation:

- Do not infer system-admin export access from `isSystemAdmin`.
- Do not populate all warehouse IDs or factories merely because the role is System Admin.
- Do not reuse `SYSTEM_ADMIN` as the AI export permission.
- Do not treat `getFactory()` or UI selection as authorization.
- Require an explicit request factory and a dedicated export permission, even if role policy later allows the role to hold that permission.
- For C, deny the export unless a concrete non-admin or explicitly configured export grant is approved.

## Decisions Requiring Product-Owner Approval

1. Select A, B, or C for the initial production policy.
2. Decide whether System Admin must receive an explicit `AI_DATA_EXPORT` role mapping or whether a separate policy table/flag will be used.
3. Decide whether a selected factory is a one-time export parameter or persisted in a future user selection model.
4. Decide whether cross-factory aggregate export can exist in any form.
5. Decide whether export denial and authorization attempts are audited under `AUDIT_VIEW`-controlled audit data.

## No Implementation or Schema Change

This document proposes policy only. It does not change `SecuritySession`, `ScopeType`, permissions, role mappings, warehouse scopes, or the existing Import/Export module.