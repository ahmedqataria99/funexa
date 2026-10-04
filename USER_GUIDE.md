# Furnexa User Guide

## 1. What is Furnexa?

Furnexa is an Arabic-first, offline-first ERP for furniture factories. It connects factory structure, materials, products, purchasing, stock, production, sales, delivery, workers, accounting, costing, documents, CRM, reports, and local backup/restore through a Windows desktop application.

The application stores operational data in a local SQLite database. It does not provide cloud synchronization.

## 2. Starting Furnexa

For a development checkout, install Flutter and run:

```powershell
flutter pub get
flutter run -d windows
```

For a release build, run `flutter build windows --release`. The executable is produced at:

```text
build\windows\x64\runner\Release\furnexa.exe
```

The repository does not contain an installer. Launch the executable directly from the release folder, or use the shortcut created by your organization's deployment process.

On launch, Furnexa initializes the local database and then displays the login screen. A login is required on every application launch because sessions are held in memory and are not persisted.

## 3. Login

Enter a username and password on the login screen. Invalid or inactive credentials are rejected, and successful and failed login attempts are audited.

A new development database creates the initial administrator account:

- Username: `admin`
- Password: `admin`
- Display name: `System Admin`

These are initial development credentials, not a production secret. Change the username and password immediately after the first login. Passwords are stored as salted hashes; Furnexa does not save an active login between launches.

The System Admin can manage users, roles, permissions, and access scopes. The system administrator has full access; other users see only the areas allowed by their permissions and section, workshop, warehouse, and production-stage scopes.

## 4. First-Time Setup

There is no setup wizard. Create master data in this practical order:

1. Factory, sections, workshops, production stages, and warehouses.
2. Categories, units, colors, raw materials, products, variants, dimensions, and BOMs.
3. Suppliers and customers.
4. Production routes and related production configuration.
5. Users, roles, permissions, and access scopes.
6. Price lists and commercial rules.
7. Purchasing, sales, stock, production, HR, and accounting transactions.

The order matters because later records refer to earlier master data. For example, a BOM needs a product and materials, receiving needs a supplier and warehouse, and production needs a product, route, stages, and material stock. Furnexa validates these relationships, but it does not force this sequence as a formal wizard.

## 5. Main Daily Workflow

A typical factory day can follow this chain:

```text
Raw material -> Purchasing -> Receiving -> Warehouse -> Production
-> Finished product -> Warehouse -> Sales -> Delivery -> Accounting -> Costing
```

For example, to produce 100 tables, confirm the table product, variant, BOM, route, stages, and material quantities. Purchase or receive the required wood, hardware, and finishing materials into a warehouse. Create the production order, consume materials as stages progress, record waste and completed quantity, and move finished tables into finished-goods stock. Create a quotation or sales order, deliver the tables, record stock out, and review the accounting and costing results.

## 6. Factory Structure

**Purpose:** Define the factory hierarchy used throughout the system.

**Normal work:** Create the factory, sections, workshops, production stages, and warehouses. Keep inactive structures inactive rather than deleting records that are still referenced.

**Rules:** Relationships and factory-code uniqueness are validated. Scopes can later limit users to selected sections, workshops, warehouses, or stages.

**Result:** Other modules can select valid locations and production stages, and reports can group activity by factory structure.

## 7. Raw Materials and Products

**Purpose:** Maintain the catalog used by purchasing, stock, production, sales, and costing.

**Normal work:** Create categories, units, colors, raw materials, products, variants, dimensions, and BOM items. Add the quantities of materials required to make each product.

**Rules:** Required references must exist and active records are used for transactions. BOMs provide production requirements and estimated material costing.

**Result:** Users can purchase, store, manufacture, sell, and cost consistent items.

## 8. Warehouses and Stock

**Purpose:** Track stock balances and every stock movement.

**Normal work:** Receive stock, issue stock, transfer items between warehouses, make permitted adjustments, and review ledgers, balances, valuation, and minimum-stock alerts.

**Rules:** Quantities must be positive where required, items and warehouses must be active, and permission and warehouse scope apply.

**Result:** Warehouse balances and stock ledgers reflect approved purchases, sales, production, transfers, returns, and adjustments.

## 9. Purchasing and Suppliers

**Purpose:** Manage the supply process and bring materials into stock.

**Normal work:** Create suppliers, purchase requests, purchase orders, and receiving records. Select the supplier, items, quantities, prices, and receiving warehouse.

**Rules:** Active suppliers, warehouses, and items are required. Receiving changes quantities and document status; it is the point at which purchased material becomes warehouse stock.

**Result:** The purchase trail is recorded and received quantities are available to production or other stock operations.

## 10. Sales and Customers

**Purpose:** Manage customer demand from quotation through fulfillment.

**Normal work:** Create customers, quotations, sales orders, deliveries, and dispatch records. Select products, variants, quantities, prices, discounts, and the warehouse supplying the order.

**Rules:** Active customers, products, and warehouses are required. Delivery quantities update order status and create stock and accounting effects.

**Result:** The customer order is traceable from offer to delivery and stock out.

## 11. Production

**Purpose:** Turn materials into finished furniture through controlled stages.

**Normal work:** Define a BOM and route, create a production order, record material consumption, move work through production stages, record waste, and record good finished quantity.

**Rules:** Lifecycle transitions and stock effects are validated. Material consumption must be supported by available stock and finished output moves to a warehouse.

**Result:** The order records consumed materials, stage progress, waste, completed quantity, and finished-product stock.

## 12. Workers and Attendance

**Purpose:** Manage the workforce data used by HR and costing.

**Normal work:** Maintain workers and shifts, record attendance, leave, and deductions, then manage payroll periods through their lifecycle.

**Rules:** Attendance and payroll statuses and approvals are enforced. Access is permission-controlled.

**Result:** Attendance and payroll records support HR reporting and the available labor-cost calculations.

## 13. Accounting

**Purpose:** Record and report financial activity connected to factory operations.

**Normal work:** Maintain accounts and periods, create journals and payments, manage cashboxes and bank accounts, and review ledgers, trial balance, income statement, balance sheet, and inventory valuation.

**Rules:** Draft, post, and reverse states and posting-date rules are validated. Integrated purchasing, sales, inventory, and costing effects should be reviewed before posting.

**Result:** Posted entries contribute to financial reports and remain subject to the document and audit rules.

## 14. Users, Roles, and Permissions

**Purpose:** Control who can see and perform each operation.

**Normal work:** Create users, define roles, grant permissions, and assign section, workshop, warehouse, and production-stage scopes. Review audit logs for protected operations.

**Rules:** Active users and roles are required. A user's visible data and actions are filtered by permission and scope. The system administrator has full access.

**Result:** Each user receives the minimum operational access appropriate to their job, with protected activity recorded in the audit log.

## 15. Dashboard and Reports

**Purpose:** Provide an operational view of inventory, purchasing, sales, production, HR, finance, attendance, and audit activity.

**Normal work:** Open the dashboard after login, review totals and trends, then open the relevant module or report for detail.

**Rules:** Report sections are permission-gated. A user without access can see an empty or unavailable section rather than data outside their scope.

**Result:** Managers can monitor activity without bypassing normal permissions.

## 16. Documents and Printing

**Purpose:** Produce controlled business documents and preserve their history.

**Normal work:** Create a draft, preview it, edit it while it is a draft, post it, and use preview, PDF generation, or printing as needed. Review document history or duplicate a document as a new draft.

**Rules:** Numbering is transactional by document type and year. Posted documents are protected and access is permission-aware. Available templates include standard/A4, compact, and thermal; Arabic RTL and English LTR are supported.

**Result:** The system retains numbered document history and produces printable or PDF output. Printing depends on the installed platform renderer.

## 17. Delivery and Dispatch

**Purpose:** Complete the physical fulfillment of a sales order.

**Normal work:** Select the sales order, confirm deliverable quantities and warehouse, create the delivery or dispatch record, and complete the handover.

**Rules:** Delivery quantities cannot exceed the valid order and stock rules. Delivery creates the corresponding stock-out and order-status effects.

**Result:** The delivered quantity is traceable and warehouse stock is reduced correctly.

## 18. Pricing

**Purpose:** Resolve commercial prices for products and customers.

**Normal work:** Configure price lists, product prices, customer overrides, quantity tiers, and discounts, then use the resolved price in quotations and sales.

**Rules:** Resolution precedence is customer override, quantity tier, then list price, subject to active and date checks. Manual price history is not claimed as an automatic resolver source.

**Result:** Eligible quotations and sales use the applicable configured price.

Pricing logic is implemented and tested, but there is no dedicated Pricing page wired into the main shell.

## 19. Returns and Quality Control

**Purpose:** Handle returned goods and decide what can return to stock.

**Normal work:** Start from the delivery or receiving record, create a sales or purchase return, record the inspection, and separate accepted, rejected, or quarantined quantities.

**Rules:** Source documents, parties, warehouses, and items must be valid. Only approved stock actions should change balances.

**Result:** Accepted quantities can return to stock and rejected or quarantined quantities remain separated according to the inspection result.

The return and quality data logic is implemented and tested, but a complete dedicated approval page is not wired into the main shell.

## 20. CRM

**Purpose:** Track leads and customer relationships before and after a sale.

**Normal work:** Record leads, statuses, activities, notes, follow-ups, and tasks. Convert a lead to a customer and continue to quotation and sales order.

**Rules:** Conversion can reuse a matching customer by phone, email, or name. Follow-up data remains connected to the customer history.

**Result:** The team can move a lead through follow-up and conversion without duplicating an existing customer.

CRM data logic is implemented and tested, but no dedicated CRM page is wired into the main shell.

## 21. Costing

**Purpose:** Calculate estimated and actual production cost and margin.

**Normal work:** Review BOM/material cost, record production consumption, include labor, overhead, other production costs, and waste or scrap recovery, then review total cost, unit cost, variance, and gross margin.

**Rules:** Finalized batches require a positive good quantity and cannot be edited. The implementation does not claim order-accurate labor costing for every production order.

**Result:** The batch has a cost breakdown and the available unit-cost and margin calculations.

Costing logic is implemented and tested, but no dedicated Costing page is wired into the main shell.

## 22. Import and Export

**Purpose:** Move supported master and stock data in and out of the local system.

**Normal work:** Select a supported entity, prepare JSON data, map columns or fields, preview the records, validate them, review errors and duplicates, and confirm a transactional import. Export filtered supported data when needed.

**Rules:** JSON is the supported format. The implemented data source supports products, raw materials, and warehouse stock or transaction data. Required fields are validated, existing records are matched by ID where applicable, and the operation requires the system-admin permission and creates an audit entry.

CSV and XLSX are not supported. Transaction import coverage is intentionally limited to the documented supported entities. There is no dedicated import/export page wired into the main shell, and a complete direct export-to-import round trip is not claimed as verified.

## 23. Global Search

**Purpose:** Find permitted records quickly from the shell.

**Normal work:** Open Global Search, choose a category if needed, enter a name, code, number, or other supported text, and select a result to open its destination. Recent searches appear when the query is empty and can be cleared.

**Rules:** Search supports products, customers, sales orders, production orders, workers, warehouses, sections, workshops, and production stages. Results are permission-aware, scope-aware where applicable, limited to 20 by default, de-duplicated, and up to 10 recent searches are retained. Documents, suppliers, leads, accounting, returns, and notifications are not search categories.

**Result:** A permitted result opens its relevant application destination without exposing records outside the user's access.

## 24. Backup and Restore

**Purpose:** Protect and recover the local database.

**Creating a backup:** Open Backup & Restore and create a backup when the data is in a known good state. Backup creation requires the `BACKUP_CREATE` permission.

**File format and history:** Backups use the `.furnexa` extension. The package contains a JSON payload with metadata, database version, record count, table data, and a SHA-256 checksum. Backup history is recorded locally.

**Validation:** Before restore, Furnexa checks the extension, JSON structure, format version, checksum, database compatibility, and factory metadata.

**Restore:** Select a validated `.furnexa` file, review the confirmation, and approve the restore. Restore requires `BACKUP_RESTORE` permission. Furnexa creates a safety database backup before replacement and can use it if replacement fails. Restore operations are audited.

**Important:** Restore replaces the current local database; it does not merge records. Confirm that the selected backup is correct and keep a separate safety copy. Backup and restore are local-only; cloud storage, encryption, scheduling, and background synchronization are not provided.

## 25. Common User Journeys

### Buying Materials

```text
Supplier -> Purchase Request -> Purchase Order -> Receiving -> Warehouse
```

Create or select the supplier, request the materials, approve the purchase order, receive the actual quantities into the chosen warehouse, and verify the stock ledger.

### Selling Products

```text
Customer -> Quotation -> Sales Order -> Delivery -> Stock Out -> Accounting
```

Prepare the quotation, confirm the sales order, reserve or verify stock, deliver the approved quantity, and review the resulting stock and accounting entries.

### Manufacturing

```text
Product -> BOM -> Production Order -> Stage Processing
-> Material Consumption -> Finished Quantity -> Warehouse
```

Confirm the BOM and route, create the order, record consumption and stage progress, record good and waste quantities, and move finished products into stock.

### Customer Return

```text
Delivery -> Sales Return -> Quality Control -> Accepted Quantity -> Stock
```

Reference the delivery, record returned quantity, inspect it, and return only the accepted quantity to stock. Keep rejected or quarantined quantity separated.

### Supplier Return

```text
Receiving -> Purchase Return -> Quality Control -> Accepted Quantity -> Stock
```

Reference the receipt, record the return, inspect the material, and apply the approved stock action for accepted quantity.

### Cost Calculation

```text
Material + Labor + Overhead + Other Production Costs + Waste/Scrap
-> Actual Cost -> Unit Cost -> Margin
```

Review the material basis, add the available labor, overhead, and other cost inputs, account for waste or scrap recovery, and review the resulting actual cost, unit cost, variance, and margin.

## 26. UI Language and Theme

Furnexa starts in Arabic with right-to-left layout. English with left-to-right layout is available from the shell language control. Light mode is the default and dark mode is available from the theme control.

Language and theme changes apply during the current run. They are runtime choices and are not persisted as user settings.

## 27. Troubleshooting

**The application does not start:** Confirm that the Windows executable is complete and that the required release files are beside it. For a development run, use `flutter pub get` and `flutter run -d windows`. Developer build and native-asset problems are covered in [docs/release.md](docs/release.md), not treated as normal user data errors.

**Login fails:** Check spelling, capitalization, active status, and the current user's assigned permissions. On a new development database, use the initial `admin` / `admin` credentials, then change them immediately.

**Data is missing or inconsistent:** Check the active warehouse, scope, document status, and user permissions first. Review stock ledgers, document history, and audit records before changing data.

**Backup validation or restore fails:** Check that the file has the `.furnexa` extension and was not modified or truncated. Use a compatible backup, ensure the user has restore permission, and do not interrupt the restore confirmation.

**A page or result is unavailable:** The current user may lack the required permission or scope. Some implemented logic, including CRM, costing, pricing, returns/quality, and import/export, does not have a dedicated page in the main shell.

**Release/build problems:** Developers should follow [docs/release.md](docs/release.md) and run the documented Flutter verification commands. Do not delete the local database as a first troubleshooting step.

## 28. Scope Notes

Furnexa does not claim persistent login credentials, MFA, rate limiting, encrypted database storage, cloud backup, scheduled backup, background synchronization, CSV/XLSX import, full-system search, or push notifications. The available Notifications area is a local refresh/evaluation mechanism rather than push, real-time, or background notification delivery.
