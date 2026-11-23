# Furnexa AI Sales Data Contract V1

**Status:** Design contract for local Sales forecasting. No snapshot or database export is created.

## 1. Objective

Define the smallest local dataset that can represent observed physical Sales demand for one local factory database.

The primary fact is completed physical delivery line quantity in a verified base unit. Accepted return quantities may subtract from that fact only after receipt, QC, and posting relationships are verified.

## 2. Eligible Delivery Data

Include a delivery fact only when all of the following are true:

- `sales_deliveries.status = 'DELIVERED'`.
- `sales_deliveries.inventoryPosted = 1`.
- Delivery warehouse resolves to the installation's local factory context.
- Delivery item exactly belongs to the delivery.
- Delivery item order line exists and belongs to the delivery order.
- Product/variant/base-unit identity is verified.
- `identitySnapshotStatus = 'VERIFIED'`.
- Base quantity and conversion fields are finite and consistent.
- The delivery is not cancelled or replaced by an unresolved correction.

## 3. Required Delivery Fields

Recommended local analysis fields:

- Delivery date.
- Warehouse token or warehouse pseudonymous key.
- Product token or verified product key.
- Variant token or nullable/explicit product-level variant state.
- Source unit quantity.
- Verified base unit ID/token.
- Unit conversion factor.
- Base quantity.
- Delivery line count.
- Inventory-posted flag.
- Delivery status.
- Observed coverage flag.
- Data mapping and contract versions.

Raw IDs are not required by the Python model and should be removed or tokenized by Flutter.

## 4. Accepted Returns

Accepted return quantities are eligible only when:

- `sales_returns` links to the delivery or a verified source delivery item for the local factory database.
- Return item belongs to the return.
- Return receipt belongs to the return.
- Receipt warehouse equals the return warehouse.
- Source delivery warehouse equals the return warehouse.
- Source delivery belongs to the return order.
- QC inspection is completed.
- Inspection warehouse matches the receipt/return chain.
- QC inspection item links exactly to the return item.
- Accepted, rejected, and quarantined base quantities reconcile to inspected base quantity.
- Existing Sales Return posting has completed the accepted transfer or another product-approved accepted-posting definition is satisfied.

Only accepted base quantity enters net demand adjustment. Rejected and quarantined quantities remain separate diagnostic fields and never reduce demand.

## 5. Return Data Fields

Where accepted returns are included:

- Accepted return date or posting/receipt date according to the approved demand definition.
- Source delivery identity token.
- Warehouse token.
- Product/variant tokens.
- Accepted return base quantity.
- Rejected return base quantity for diagnostics only.
- Quarantined return base quantity for diagnostics only.
- Inspection/receipt completion status.
- Return posting status.
- Mapping and contract versions.

The local model may receive only accepted quantity, not return request quantity or pending/rejected quantity.

## 6. Net Demand Rule

At the approved grain:

```text
net_delivered_base_quantity = gross_delivered_base_quantity - accepted_return_base_quantity
```

The implementation must reject negative observed net demand if invalid source reconciliation would otherwise produce it.

Gross delivered and accepted-return quantities should be retained separately in the local payload, if net demand and source auditability are required. Do not replace the gross source fact with only an aggregate net number.

## 7. Observed Zero vs Missing

A date is `observed_zero` only when the governed coverage rules prove that the identity should have an observed target of zero for that date.

A date is `missing` when:

- No source coverage exists.
- Identity mapping was not verified.
- Required data was unavailable or quarantined.
- The row failed source validation.
- A historical period is not represented by verified source coverage.

Do not convert missing data to zero.

For calendar grids:

- Preserve `observed_coverage = true` for observed rows.
- Preserve `observed_coverage = false` for missing dates.
- Preserve `demand_state = observed_zero`, `observed_positive`, or `missing`.
- Set the target only for observed coverage; leave missing target unavailable.

## 8. Excluded Entities

The minimum demand contract does not use:

- Sales quotations.
- Sales orders as demand quantities.
- Sales order totals or remaining quantities.
- Sales invoices.
- Delivery or order dates as demand dates instead of the actual delivery date.
- Customer-level Sales totals.
- Global product summaries.
- Rejected or quarantined returns.
- Pending, cancelled, or draft returns.
- Accounting journal entries or inventory valuation totals.
- Stock balances as historical demand unless separately approved.

## 9. Stockout and Unavailability

No stockout status is included by default.

A stockout period may be included only after a verified time-bounded stock ledger or availability policy is approved. Absence of deliveries is not evidence of stockout or missing demand.

## 10. Identity and Unit Rules

- Use product and variant snapshots when available.
- Keep variant explicit for variant sales; do not infer variant from product catalog context.
- Use base quantity and base unit for aggregation.
- Exclude `UNVERIFIED` or `LEGACY_UNASSIGNED` identities until mapping is approved.
- Do not infer missing variant identity from the UI.
- Aggregate only after identity and unit conversion validation.

## 11. Data-Quality Manifest

The Flutter extraction result should include aggregate counts for:

- Eligible delivery lines.
- Excluded undelivered deliveries.
- Excluded not-inventory-posted deliveries.
- Excluded unverified identities.
- Accepted return lines.
- Rejected/quarantined return quantities.
- Excluded orphan or inconsistent links.
- Missing historical periods.
- Observed positive days.
- Observed zero days.
- Missing target days.
- Duplicate or corrected record count.

## 12. Prohibited Payload Fields

Do not send to Python:

- Customer names, IDs, contact data, or tax numbers.
- Employee or approver identities.
- Delivery destination, driver, or vehicle fields.
- Free-text notes and reasons.
- Raw order, delivery, return, invoice, warehouse, factory, product, or variant IDs unless separately approved and pseudonymized.
- Unit prices and financial values.
- SQL or database paths.

## 13. Existing AI-Code Compatibility

The existing AI workspace already contains a calendar-grid and demand-state model that preserves missing versus observed zero. The implementation should reuse those concepts, but no real database snapshot or model export has been approved.

Existing synthetic sales code and benchmark artifacts remain preserved and separate from runtime local business data.

## 14. Product-Owner Decisions

- Net demand versus gross delivered demand as the default forecast target.
- Accepted-return date: source delivery date, receipt date, posting date, or separate event model.
- Whether to export separate gross and accepted quantity fields or net only.
- Historical period minimum and missing-period policy.
- Observed-zero definition and coverage source.
- Whether warehouse level is included in every identity or product demand is factory-wide.
- Whether exact stock transaction matching is required in addition to `inventoryPosted = 1`.