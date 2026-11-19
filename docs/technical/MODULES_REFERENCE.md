# Modules Reference

## Core modules

### 1. Users and roles
- Path: `lib/features/users_roles_permissions/`
- Key files: `security_local_data_source.dart`, login page, users/roles page
- Responsibilities: authentication, setup, roles, permissions, session scopes, audit logging
- Main classes: `SecurityLocalDataSource`, `SecuritySession`, `SecurityUser`, `SecurityRole`
- Status: implemented and source-verified

### 2. Factory structure
- Path: `lib/features/factory_structure/`
- Responsibilities: factories, sections, workshops, production stages, warehouses
- Status: implemented

### 3. Raw materials and products
- Path: `lib/features/raw_materials_products/`
- Responsibilities: categories, units, colors, raw material catalog, product master, variants, BOM, alternatives, dimensions
- Key page: `raw_materials_products_page.dart`
- Status: implemented; BOM/profile dialog logic was corrected after analyzer validation

### 4. Warehouses and stock
- Path: `lib/features/warehouses_stock/`
- Responsibilities: warehouse listings, stock positions, movement processing, stock integrity checks
- Status: implemented

### 5. Purchasing
- Path: `lib/features/purchasing/`
- Responsibilities: suppliers, requests, purchase orders, receipts, payments
- Status: implemented

### 6. Sales
- Path: `lib/features/sales/`
- Responsibilities: customers, quotations, sales order creation, fulfillment and payment flows
- Status: implemented

### 7. Production
- Path: `lib/features/production/`
- Responsibilities: production routes, order lifecycle, material consumption, output, waste, BOM snapshot logic
- Status: implemented; major production workflows are present and heavily exercised in tests

### 8. Returns quality
- Path: `lib/features/returns_quality/`
- Responsibilities: purchase returns, sales returns, quality inspections
- Status: implemented with dedicated UI and tests

### 9. Accounting
- Path: `lib/features/accounting/`
- Responsibilities: accounts, journal entries, ledger, payments, expenses, valuation
- Status: implemented

### 10. Payroll / HR
- Path: `lib/features/hr/`
- Responsibilities: workers, attendance, shifts, payroll periods and records
- Status: implemented

### 11. Pricing
- Path: `lib/features/pricing/`
- Responsibilities: price lists, product prices, customer price overrides, tiers and rules
- Status: implemented

### 12. CRM
- Path: `lib/features/crm/`
- Responsibilities: leads, tasks, notes, follow-ups, activities
- Status: implemented

### 13. Dashboard and reports
- Path: `lib/features/dashboard_reports/`
- Responsibilities: business reports and KPI panels
- Status: implemented, but less fully audited in this pass

### 14. Notifications
- Path: `lib/features/notifications/`
- Responsibilities: notification records and badge display
- Status: implemented

### 15. Backup and restore
- Path: `lib/features/backup_restore/`
- Responsibilities: local database backup and restore workflows
- Status: implemented in source

### 16. Documents and history
- Path: `lib/features/documents/`
- Responsibilities: document tracking and history pages
- Status: implemented

### 17. Global search
- Path: `lib/features/global_search/`
- Responsibilities: cross-feature search over the local database
- Status: implemented

### 18. Import/export and costing
- Additional modules are present in the feature directory tree but are not treated as primary app entry points in the current shell. They are source-visible and appear to be integrated to varying degrees.

## Module status by capability
For a practical development handoff, each feature folder is best treated as follows:
- Fully connected at source level: factory structure, purchasing, sales, production, raw materials, users/security, accounting
- Partially integrated or legacy: some pricing, reporting, notifications, and costing areas
- Source-visible but not fully cleaned: older pages still contain style and lifecycle warnings

## Architectural conclusion
The application is feature-based and data-centric. Individual module pages are not isolated from the database; they directly call repository implementations that operate on the local SQLite store. This makes the app powerful but also means that validation and permission enforcement must be preserved in the repository/data-source boundary.
