# Furnexa Project Overview

## Purpose
Furnexa is an Arabic-first desktop ERP for a furniture factory. The application tracks the factory structure, inventory, raw materials, production orders, purchasing, sales, accounting, payroll, returns, pricing, and user permissions in a local SQLite database.

## Stack
- Flutter 3.x desktop application
- Dart SDK ^3.10.4
- SQLite via sqflite and sqflite_common_ffi for local persistence
- SharedPreferences for app settings
- Flutter localization for Arabic and English
- Material design theme and custom UI widgets
- Local-first architecture; no remote API layer is present in the project source

## Startup and entry points
- App entry: `lib/main.dart`
- Main app setup: `FurnexaApp`, `_AuthGate`, and `SecurityLocalDataSource`
- Database bootstrap: `FurnexaDatabase.instance.database`
- Startup initialization includes schema setup, admin bootstrap, and settings load

## High-level architecture
The project is organized as a feature-first Flutter app. Shared cross-cutting infrastructure sits under `lib/core/`, while business features sit under `lib/features/<module>/`.

The actual runtime flow is:

```text
UI page / widget
  -> feature repository implementation
  -> local data source
  -> SQLite database
  -> validation / permission checks / transaction logic
```

Authentication and authorization are handled centrally through the security data source and role/permission tables.

## Major modules
The implemented feature set visible in source includes:
- accounting
- backup_restore
- costing
- crm
- dashboard_reports
- documents
- factory_structure
- global_search
- hr
- import_export
- notifications
- pricing
- production
- purchasing
- raw_materials_products
- returns_quality
- sales
- users_roles_permissions
- warehouses_stock

## Current development status
The project is in a partially stabilized state:
- the application structure and feature modules are present and connected to a single local SQLite data store;
- several major workflows are implemented in repository and page layers;
- the codebase is not fully analyzer-clean, but the confirmed runtime-critical error found in the BOM dialog was fixed;
- many style and lint-only diagnostics remain across legacy code; they do not block compilation, but they reflect incomplete cleanup.

This codebase is suitable for continuing future development, but the project still needs targeted cleanup before it can be considered fully polished.
