# Furnexa AI Return Stock Reconciliation Report V1

**Status:** Implemented in the Flutter Sales AI payload builder. No business workflow or database schema change.

## Verified Stock Transaction Convention

Accepted Sales Returns create inventory movements in `_postSalesReturnWithinTransaction` using:

```text
SALES_RETURN_ACCEPTED:<salesReturnId>:<salesReturnItemId>
```

The existing warehouse stock implementation writes exactly one `TRANSFER_OUT` in the quarantine warehouse and exactly one `TRANSFER_IN` in the sellable return destination warehouse. Both rows use the same reference and quantity.

Evidence:

- `_postSalesReturnWithinTransaction`: `lib/features/returns_quality/data/datasources/returns_quality_local_data_source.dart`
- `transferQuarantinedSalesReturnWithinTransaction`: `lib/features/warehouses_stock/data/datasources/warehouses_stock_local_data_source.dart`
- `_writeTransaction`: writes the stock transaction fields and reference.

## Required Match

The AI payload builder requires all of the following:

- `sales_returns.status = 'COMPLETED'`.
- Return item belongs to the Sales Return.
- Receipt belongs to the return and receipt item belongs to the return item.
- QC source is `SALES_RETURN`, source ID is the return, and status is `COMPLETED`.
- QC source item is the exact return item.
- Receipt warehouse equals the quarantine warehouse used by the posting workflow.
- Receipt warehouse differs from the return destination sellable warehouse.
- Source delivery belongs to the return order and source warehouse.
- Source delivery is `DELIVERED` and `inventoryPosted = 1`.
- QC accepted/rejected/quarantined quantities reconcile exactly to inspected quantity.
- A reference exactly equals `SALES_RETURN_ACCEPTED:<returnId>:<returnItemId>`.
- Exactly one matching `TRANSFER_OUT` and exactly one matching `TRANSFER_IN` exist.
- Outbound warehouse equals the quarantine warehouse.
- Inbound warehouse equals the authorized sellable return warehouse.
- Both transactions use `itemType = 'PRODUCT'` for product returns.
- Product, variant, inventory identity, and base unit match.
- Both transaction quantities exactly match accepted base quantity.
- Reference is used only once for reconciliation in the payload build.

## Product and Variant Matching

The return query uses verified snapshot fields and falls back only through explicit source relationships. Stock transactions must match:

- `productId`
- `variantId`, including explicit `NULL` for product-level sales
- `inventoryIdentityKind`
- `unitId` matching the verified base unit

No warehouse or identity is inferred from UI context or user selection.

## Duplicate and Partial Return Handling

- Partial accepted quantity is supported: both stock rows must equal the accepted base quantity for that partial event.
- Multiple QC items for one return item are grouped and reconciled before stock matching.
- Repeated use of the same exact reference is blocked by an in-build reconciled-reference set.
- Exactly two stock rows are required for the pair. Additional, missing, or duplicate rows are excluded.
- Only accepted base quantity is subtractable. Rejected and quarantined quantities are counted only as exclusion diagnostics.

## Fail-Closed Exclusion Reasons

The payload coverage metadata may include:

- `missing_stock_transaction`
- `incorrect_stock_transaction_reference`
- `wrong_stock_transaction_product_or_variant`
- `wrong_stock_transaction_warehouse`
- `stock_transaction_quantity_mismatch`
- `duplicate_stock_transaction`
- `duplicate_return_reconciliation`
- `return_qc_reconciliation_mismatch`
- `rejected_or_quarantined_excluded`

An unmatched return adds no accepted quantity to the delivery fact. It does not remove the original valid delivery demand row.

## Existing Implementation Update

Updated `lib/features/ai/data/sales_ai_payload_builder.dart` to:

- Query accepted return IDs and exact item IDs.
- Carry quarantine and sellable warehouse context.
- Carry product, variant, base-unit, and identity fields.
- Query matching stock transactions by exact reference or exact return reference prefix.
- Require exactly one outbound and one inbound transfer pair.
- Validate warehouse, product, variant, identity, base unit, and quantity.
- Prevent duplicate reconciliation by exact reference.
- Record structured exclusion counts.

## Synthetic Tests

Test file: `test/local_ai_payload_builder_test.dart`

Covered:

- Exact stock transaction pair.
- Missing stock transaction.
- Incorrect reference.
- Wrong product or variant.
- Wrong warehouse.
- Quantity mismatch.
- Partial accepted quantity.
- Rejected quantity remains excluded.
- Quarantined quantity remains excluded.
- Duplicate stock transaction pair.
- Duplicate return reconciliation.
- Valid delivery remains included while an unmatched return is excluded.

Final focused result: **14 tests passed**.

## Verification Limitations

- No synthetic SQLite rows were inserted for the expanded stock-matching cases; the matcher is tested directly, while SQL source guards are source-tested.
- The existing database has no unique constraint enforcing exactly one stock reference pair, so the builder performs runtime duplicate detection.
- No production database or business row was accessed.
- No model, UI, schema, migration, or business workflow was changed.
