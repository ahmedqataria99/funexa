# Database Schema

## Database overview
- Database name: `furnexa.db`
- Version: `41`
- Bootstrap: `lib/core/database/furnexa_database.dart`
- Foreign keys are enabled with `PRAGMA foreign_keys = ON`.

The database is constructed incrementally through migration steps in `FurnexaDatabase._runMigration()`. The schema is not a generated ORM model; it is a SQLite migration script that creates table definitions and indexes as the app evolves.

## Core schema groups
The main tables created in migration version 2 and later include:

### Factory and structure
- `factories`
- `sections`
- `workshops`
- `production_stages`
- `warehouses`

### Catalog and product data
- `categories`
- `units`
- `colors`
- `raw_materials`
- `products`
- `product_variants`
- `product_dimensions`
- `product_bom_items`
- `product_alternatives`

### Inventory and stock
- `stock_balances`
- `stock_transactions`
- `stock_minimum_levels`

### Procurement
- `suppliers`
- `purchase_requests`
- `purchase_request_items`
- `purchase_orders`
- `purchase_order_items`
- `purchase_receipts`
- `purchase_receipt_items`
- `supplier_payments`

### Sales and delivery
- `customers`
- `quotations`
- `quotation_items`
- `sales_orders`
- `sales_order_items`
- `sales_deliveries`
- `sales_delivery_items`
- `customer_payments`

New deliveries use `sales_deliveries.inventoryPosted = 0` while stock is reserved but not yet deducted. The reservation remains active for `PENDING`, `DISPATCHED`, and `IN_TRANSIT` deliveries, and confirmation changes the marker to `1` with the stock movement and delivered-quantity update. Migration 40 adds the marker with a default of `1` for existing rows; pre-v40 records have no per-delivery evidence showing whether a pending delivery already consumed stock. Treating every legacy row as posted prevents duplicate deductions, but a genuinely unposted legacy delivery will not be counted as an active reservation. Migration 40 does not rewrite stock balances or valuation; any reconciliation must be handled explicitly rather than inferred from status.

Migration 41 adds `sales_order_items.invoicedQuantity` and the `sales_invoices` / `sales_invoice_items` tables. It preserves existing selling-price snapshots and does not change order prices or stock records.

### Production execution
- `production_routes`
- `production_route_stages`
- `production_orders`
- `production_order_stages`
- `production_material_consumptions`
- `production_waste`
- `production_outputs`
- `production_order_bom_items`
- `production_order_labor_allocations`

### HR and payroll
- `workers`
- `shifts`
- `worker_assignments`
- `attendance_records`
- `leave_records`
- `deductions`
- `payroll_periods`
- `payroll_records`

### Accounting
- `accounts`
- `accounting_periods`
- `journal_entries`
- `journal_lines`
- `journal_parties`
- `cashboxes`
- `bank_accounts`
- `expenses`
- `inventory_valuations`

### Security and audit
- `roles`
- `permissions`
- `users`
- `role_permissions`
- `user_scopes`
- `audit_logs`
- `app_setup_state`

### Notifications and documents
- `notifications`
- `document_sequences`
- `document_records`

### Pricing and returns
- `pricing_lists`
- `price_lists`
- `product_prices`
- `pricing_product_prices`
- `customer_price_overrides`
- `customer_prices`
- `price_tiers`
- `pricing_tiers`
- `discount_rules`
- `commercial_discount_rules`
- `price_history`
- `pricing_history`
- `sales_returns`
- `sales_return_items`
- `purchase_returns`
- `purchase_return_items`
- `quality_inspections`
- `quality_inspection_items`

### CRM and costing
- `crm_leads`
- `crm_activities`
- `crm_follow_ups`
- `crm_tasks`
- `crm_notes`
- `costing_overhead_rules`
- `production_other_costs`
- `production_cost_adjustments`
- `production_batch_costs`
- `customer_price_list_assignments`

## Simplified ER overview
```mermaid
erDiagram
    FACTORIES ||--o{ SECTIONS
    FACTORIES ||--o{ WAREHOUSES
    FACTORIES ||--o{ PRODUCTS
    CATEGORIES ||--o{ RAW_MATERIALS
    UNITS ||--o{ PRODUCTS
    PRODUCTS ||--o{ PRODUCT_VARIANTS
    PRODUCTS ||--o{ PRODUCT_BOM_ITEMS
    PRODUCTS ||--o{ PRODUCT_ALTERNATIVES
    PRODUCTS ||--o{ STOCK_BALANCES
    WAREHOUSES ||--o{ STOCK_TRANSACTIONS
    SUPPLIERS ||--o{ PURCHASE_ORDERS
    PURCHASE_ORDERS ||--o{ PURCHASE_ORDER_ITEMS
    CUSTOMERS ||--o{ SALES_ORDERS
    SALES_ORDERS ||--o{ SALES_ORDER_ITEMS
    PRODUCTION_ORDERS ||--o{ PRODUCTION_ORDER_BOM_ITEMS
    USERS ||--o{ AUDIT_LOGS
    ROLES ||--o{ ROLE_PERMISSIONS
    USERS ||--o{ USER_SCOPES
    JOURNAL_ENTRIES ||--o{ JOURNAL_LINES
```

## Migration model
The migration mechanism in `FurnexaDatabase` uses `user_version` and a per-version switch block. The app initializes the database with `onCreate` and upgrades with `onUpgrade` through `migrate()` and `_runMigration()`.

## Integrity notes
- `PRAGMA foreign_keys = ON` is enabled globally.
- Unique constraints exist on business codes such as factory, item, and supplier codes.
- Transaction-oriented persistence is implemented in multiple repository layers, especially around user session setup and stock-sensitive operations.
- This is a local, relational SQLite schema; it is not normalized to a full enterprise data warehouse model.

## Verification status
The schema is source-verified from the database migration file and the app’s repository layer. It is not fully documented in one generated model; the migration source remains the authoritative source of truth.
