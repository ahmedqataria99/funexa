# Features

This document records implemented capability surfaces and their integration boundaries. It does not expand the product scope.

## Factory Setup and Structure

Purpose: maintain factory profile, sections, workshops, production stages, and warehouses. Capabilities include search and active/inactive state management. Hierarchy relationships and factory-code uniqueness are validated. This supplies master data to production, stock, purchasing, and reports.

## Raw Materials and Products

Purpose: maintain categories, units, colors, raw materials, products, variants, dimensions, and BOM items. Required references and active records are validated. BOMs feed production and costing; products and materials feed purchasing, sales, stock, and search.

## Warehouses and Stock Movement

Purpose: maintain balances, stock in/out, transfers, adjustments, ledgers, and valuation. Quantities must be positive and warehouses/items active. Purchasing, sales, production, returns, costing, notifications, and accounting consume stock events.

## Purchasing and Suppliers

Purpose: manage suppliers, purchase requests/orders, receiving, and stock effects. Active suppliers, warehouses, and items are validated; receiving updates quantities and status. Purchasing feeds inventory, valuation, documents, and accounting.

## Sales and Customers

Purpose: manage customers, quotations, sales orders, deliveries, dispatch, and stock/accounting effects. Active customers, items, and warehouses are required; delivery quantities update order status and stock. Sales feeds documents, reports, CRM history, pricing, and audit.

## Production and Manufacturing

Purpose: manage routes, production orders, stages, material requirements/consumption, waste, and output. Lifecycle transitions and stock/valuation effects are enforced. Production consumes BOM materials and produces finished stock for warehouses and costing.

## Workers, Attendance, and Payroll

Purpose: manage workers, shifts, attendance, leave, deductions, payroll periods, and payroll lifecycle. Attendance and payroll statuses, approvals, and deductions are modeled. HR feeds reports, notifications, and costing. Statutory payroll or tax compliance is not claimed.

## Accounting

Purpose: provide accounts, periods, journals, payments, cashboxes, bank accounts, ledgers, trial balance, income statement, balance sheet, and inventory valuation. Draft/post/reverse and posting-date rules are validated. Purchasing, sales, inventory, and production costing integrate with accounting.

## Users, Roles, Permissions, and Audit

Purpose: authenticate users and enforce role permissions and section/workshop/warehouse/stage scopes. Passwords are salted and hashed; active users and roles are required; audit logs record protected operations. The implementation does not claim MFA, rate limiting, encrypted database storage, or persistent credentials.

## Dashboard and Reports

Purpose: expose totals and trends for inventory, purchasing, sales, production, HR, finance, attendance, and audit activity. Access is permission-gated; unavailable permissions can produce empty sections.

## Notifications

Purpose: store user notifications, unread state, archive state, and alert evaluation for stock, purchasing, approvals, sales/production delays, attendance, and payroll. Distribution considers permissions and warehouse scope. This is a local refresh/evaluation mechanism, not push delivery, background scheduling, or real-time notification infrastructure.

## Documents and Printing

Purpose: create numbered drafts, post documents, preserve history, duplicate drafts, generate PDFs, and prepare printing. Numbering is transactional by document type and year; posted documents are protected and access is permission/scope-aware. Supported templates include standard/A4, compact, and thermal; Arabic RTL and English LTR are tested. Printing depends on the renderer/platform implementation.

## Delivery and Dispatch

Purpose: complete the sales fulfillment path and update stock out. Delivery quantities affect order status and warehouse balances. It integrates with customers, sales orders, documents, inventory, valuation, and reports.

## Pricing and Commercial Rules

Purpose: manage price lists, product prices, customer overrides, quantity tiers, discounts, and price history. Resolution precedence is customer override, quantity tier, then list price, with active/date checks. Pricing integrates with customers, products, quotations, and sales. Manual price history is not claimed as an automatic resolver source.

## Returns and Quality Control

Purpose: handle sales returns, purchase returns, and quality inspections. Source orders, active parties, warehouses, and items are validated; approved stock actions and rejected/quarantined inspection quantities are transactional. A complete dedicated approval UI is not claimed.

## CRM

Purpose: manage leads, statuses, conversion, activities, notes, follow-ups, tasks, customer 360 data, and sales history. Conversion can reuse a matching customer by phone, email, or name. CRM data integrates with customers, quotations, and sales orders. The repository surface exists, but no dedicated CRM page is wired into the main shell.

## Costing and Pricing Engine

Purpose: calculate estimated and actual production cost, material/labor/overhead/other-cost components, waste/scrap recovery, variance, unit cost, and gross margin. Finalized batches require positive good quantity and cannot be edited. Labor calculation boundaries mean order-accurate labor costing is not claimed.

## Import and Export

Purpose: provide permission-protected JSON export/import for supported product, raw-material, and warehouse-stock data with mapping/validation/audit behavior in the local data source. Imports are transactional and required fields are validated. CSV/XLSX and a proven direct export-to-import round trip are not claimed unless separately verified; no dedicated import/export page is wired into the shell.

## Global Search

Purpose: search selected products, customers, sales orders, production orders, workers, warehouses, sections, workshops, and production stages with category filters and recent searches. Results are permission-filtered, limited, and de-duplicated. It is not full-system search; documents, suppliers, leads, accounting, returns, and notifications are not claimed as searchable categories.

## Backup and Restore

Purpose: create and restore local `.furnexa` packages with metadata, SHA-256 checksum, validation, history, safety backup, compatibility checks, permission checks, confirmation, and audit events. Restore replaces rather than merges the database. See [backup-restore.md](backup-restore.md).
