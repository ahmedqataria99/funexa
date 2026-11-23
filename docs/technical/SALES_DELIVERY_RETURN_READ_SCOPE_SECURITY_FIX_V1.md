# Sales Delivery and Return Read-Scope Security Fix V1

## Scope and Findings

The delivery-history method `SalesLocalDataSource.deliveries(orderId)` required `SALES_VIEW` but queried `sales_deliveries` only by `salesOrderId`. The same order can have delivery rows from multiple warehouses/factories, so the method returned out-of-scope rows. Its callers are the Sales order delivery history (initial load and refresh) and customer-profile delivery aggregation; all use the same repository method.

Sales Return listing and source-delivery selection queried broadly and filtered warehouse access after retrieval in Dart. Return details checked the header warehouse before reading items, receipts, receipt items, and QC data, but several child queries did not independently enforce that relationship or scope. Generic QC inspection reads also fetched inspection items by inspection ID without binding non-null return-item references to the scoped return.

Authorization is sourced from `SecurityLocalDataSource`'s active `SecuritySession`: the operation permission is required and non-admin warehouse access comes from that session's explicit `ScopeType.warehouse` grants. `SecuritySession.canAccess` already grants system roles unrestricted access; the fix preserves that existing behavior. `ScopeType` has no factory scope, and `sales_returns` has no invoice foreign key.

## Changes

- [`lib/features/users_roles_permissions/data/datasources/security_local_data_source.dart`](../../lib/features/users_roles_permissions/data/datasources/security_local_data_source.dart): exposes the authenticated session's authorized warehouse IDs and its existing system-role unrestricted rule.
- [`lib/features/sales/data/datasources/sales_local_data_source.dart`](../../lib/features/sales/data/datasources/sales_local_data_source.dart): scopes `deliveries(orderId)` in SQL through the delivery warehouse and factory; scopes the Sales warehouse picker; checks warehouse authorization in shared delivery-warehouse validation.
- [`lib/features/returns_quality/data/datasources/returns_quality_local_data_source.dart`](../../lib/features/returns_quality/data/datasources/returns_quality_local_data_source.dart): moves return listing, source delivery/line selection, details, receipt and receipt-item, and Sales Return QC reads behind warehouse predicates and verified return/delivery relationships. Child QC links must belong to the same return and authorized source warehouse. A historical null QC item-source link remains supported when its parent return and inspection warehouse are authorized.
- [`test/sales_read_scope_security_test.dart`](../../test/sales_read_scope_security_test.dart): adds isolated synthetic cross-factory tests for authorized/unauthorized delivery and return reads, empty scope, order-based lookup, warehouse picker, source-line selection, return items/receipts, QC children, malformed links, and system-role administrator behavior.
- [`test/returns_quality_feature_test.dart`](../../test/returns_quality_feature_test.dart): associates the legacy null-source QC fixture with a real synthetic return so the test retains its compatibility purpose while orphan inspections fail closed.

No database migration, stock movement, accounting behavior, AI export, or historical AI data was changed.

## Authorization Before and After

Before, delivery-by-order used a permission check followed by an order-only query. Return list/source queries fetched cross-warehouse rows and relied on client-side filtering; some return detail children were keyed only by parent IDs.

After, list and detail queries use SQL predicates bound to the active session's warehouse grants. Empty warehouse scope yields no listed rows. Order-based delivery lookup cannot widen the authorized set. A supplied warehouse ID is not treated as authorization: shared delivery warehouse validation checks the session grant, while the picker itself lists only authorized warehouses. Return child reads require the authorized return and receipt warehouses; non-null source links must match the return's order and warehouse. Missing or inconsistent non-null delivery links are excluded or rejected.

System-role administrator behavior remains the existing unrestricted warehouse behavior, still subject to the existing permission checks for each operation.

## Verification

All tests used the test helper's synthetic `furnexa_test_*.db` databases. The focused run was executed from a temporary copy of Furnexa because an existing workspace Sales test process and the shared Windows native-asset cache caused Flutter to fail copying `sqlite3.dll` into the repository build directory.

- `sales_read_scope_security_test.dart`: 9 passed.
- Legacy null-source QC test: 1 passed.
- Existing Sales Return receipt and QC-approval regressions: 2 passed.
- Existing Sales delivery posting/idempotency regressions: 2 passed.
- Dart diagnostics for all changed Dart files: no errors reported.
- `git diff --check`: clean.
- Full test suite: not run; a separate Sales test process was already active in the workspace, and the repository build cache produced a native-asset collision. Focused tests ran successfully in the isolated copy.

## Remaining Limitations

- The authorization model has warehouse scopes only, not a distinct factory scope. Factory membership is verified through the persisted `warehouse.factoryId` relationship; users must have explicit warehouse grants. No factory-wide grant is inferred or added.
- `sales_returns` has no invoice foreign key, so invoice-based scope cannot be safely derived. Return scope is enforced through its persisted `warehouseId`, with any non-null original delivery checked against the same order and warehouse.
- The dashboard Delivery report already applies warehouse scope. Order-level Sales summaries/reports are separate reads over `sales_orders`, which have no warehouse/factory relationship in the current schema; they remain outside this fix and require a separate authorization/data-model audit before export use.
- The Sales delivery/return paths covered here are not a certification of all Sales data reads. Future export design must separately scope order-level reports and establish whether warehouse grants are the intended factory boundary.
