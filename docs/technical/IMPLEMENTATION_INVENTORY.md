# Implementation Inventory

## Application shell
- File: `lib/main.dart`
- Main classes: `FurnexaApp`, `_AuthGate`, `_FurnexaAppState`, `_AuthGateState`
- Responsibilities: app startup, database initialization, localization, theme, security gate, login
- Status: implemented and active

## Core database layer
- File: `lib/core/database/furnexa_database.dart`
- Main members: `FurnexaDatabase`, `_openDatabase()`, `_resolveDatabasePath()`, `_runMigration()`, `migrate()`
- Responsibilities: database creation, path resolution, SQLite migrations, foreign key setup
- Status: implemented

## Security layer
- File: `lib/features/users_roles_permissions/data/datasources/security_local_data_source.dart`
- Main members: `SecurityLocalDataSource`, `SecuritySession`, `login()`, `setupInitialAdmin()`, `require()`, `canAccess()`
- Responsibilities: auth, permissions, audit, session-scoped access
- Status: implemented

## Factory structure
- Files: `lib/features/factory_structure/**`
- Responsibilities: factory, departments, workshops, production stages, warehouses
- Status: implemented

## Raw materials and products
- Files: `lib/features/raw_materials_products/**`
- Key page: `raw_materials_products_page.dart`
- Key responsibilities: catalog CRUD, product profile, variants, dimensions, BOM, alternatives
- Status: implemented; BOM/profile dialog state corrected for missing method call

## Warehouses and stock
- Files: `lib/features/warehouses_stock/**`
- Responsibilities: warehouse data and stock balance operations
- Status: implemented

## Purchasing
- Files: `lib/features/purchasing/**`
- Responsibilities: requests, orders, receipts, supplier payments
- Status: implemented

## Sales
- Files: `lib/features/sales/**`
- Responsibilities: quotations, orders, delivery, customer payments
- Status: implemented

## Production
- Files: `lib/features/production/**`
- Responsibilities: route, order execution, material consumption, output, waste, cost adjustments
- Status: implemented and heavily represented in test files

## Returns and quality
- Files: `lib/features/returns_quality/**`
- Responsibilities: sales returns, purchase returns, inspection workflows
- Status: implemented

## Accounting
- Files: `lib/features/accounting/**`
- Responsibilities: ledgers, journal entries, expenses, payments, valuations
- Status: implemented

## HR and payroll
- Files: `lib/features/hr/**`
- Responsibilities: workers, shifts, attendance, payroll calculation
- Status: implemented

## Pricing and commercial rules
- Files: `lib/features/pricing/**`
- Responsibilities: price lists, rules, overrides, tiers
- Status: implemented

## CRM
- Files: `lib/features/crm/**`
- Responsibilities: leads, tasks, notes, follow-ups
- Status: implemented

## Dashboard and reports
- Files: `lib/features/dashboard_reports/**`
- Responsibilities: KPI reports and dashboard data
- Status: implemented

## Notifications
- Files: `lib/features/notifications/**`
- Responsibilities: notification generation and UI badge state
- Status: implemented

## Backup and restore
- Files: `lib/features/backup_restore/**`
- Responsibilities: local backup/restore operations
- Status: implemented

## Documents
- Files: `lib/features/documents/**`
- Responsibilities: document history and document records
- Status: implemented

## Global search
- Files: `lib/features/global_search/**`
- Responsibilities: broad repository search across the ERP data model
- Status: implemented

## Tests
- Directory: `test/`
- Coverage themes: migration tests, production workflow tests, feature tests, UI tests, persistence tests
- Status: present but uneven across modules

## Implementation summary
The actual ERP implementation is broad and feature-rich. The strongest and most coherent areas are the core ERP data model, security, stock, purchasing, sales, production, and accounting. The highest-risk issue in the current codebase is not missing functionality but the accumulated legacy cleanup burden: broader lint cleanup, aging UI patterns, and inconsistent repository enforcement.
