# Architecture

## Actual folder structure
```text
lib/
  core/
    constants/
    database/
    error/
    localization/
    result/
    shared/
    theme/
    widgets/
    usecase/
    utils/
  features/
    accounting/
    backup_restore/
    costing/
    crm/
    dashboard_reports/
    documents/
    factory_structure/
    global_search/
    hr/
    import_export/
    notifications/
    pricing/
    production/
    purchasing/
    raw_materials_products/
    returns_quality/
    sales/
    users_roles_permissions/
    warehouses_stock/
  main.dart

test/
  *.dart

docs/
  architecture.md
  ...
```

## Layer responsibilities
### Core layer
The `lib/core/` folder provides the shared operating environment:
- database management (`furnexa_database.dart`)
- app settings and localization
- theme and shared widget infrastructure
- global error/result helpers
- app-wide constants and diagnostics

### Feature layer
Each feature directory typically includes:
- `data/` for DAO-like local data sources and repository implementations
- `domain/` for entities, repository contracts, and use case logic
- `presentation/` for pages, dialogs, forms, and feature UI widgets

### State management pattern
The project uses a direct stateful widget pattern rather than a separate framework like Bloc, Riverpod, or Provider. Screen state and dialog state are kept in `StatefulWidget` classes and loaded from repositories through asynchronous methods like `_load()`, `_save()`, and feature-specific form handlers.

### Repository and data-source pattern
Typical flow:

```text
Widget / Page
  -> Repository interface
  -> Repository implementation
  -> Local data source
  -> SQLite database
```

The repository classes work as the domain boundary, while the local data source handles the actual raw SQL, validation, and transaction coordination.

## Dependency flow
The application is intentionally local-first. The actual on-disk persistence is SQLite, and the app is built around a single database instance (`FurnexaDatabase.instance`). Feature pages load data through repository implementations and perform writes through them. The lowest-level layer owns data integrity and database transactions, while the page layer handles user interaction and UI feedback.

## Navigation architecture
The app shell and route selection are centralized in `lib/main.dart` and the app shell widgets. The security gate resolves authentication state before showing the main ERP shell. Feature pages are then presented directly as tabbed or routed pages rather than a deep route table.

## Shared infrastructure
- `SecurityLocalDataSource` handles login, admin setup, role checks, permissions, and session state.
- `AppLocalizations` provides Arabic and English translation entries for the UI.
- `AppTheme` centralizes color and theme configuration.
- `FurnexaDatabaseDiagnostics` captures startup validation and runtime database diagnostics when enabled.

## Audit note
The architecture is coherent but not uniformly layered. Some feature modules still mix UI logic, validation, and persistence logic within page classes. The code remains functionally connected, but several modules show evidence of accumulated legacy implementations instead of a strict clean architecture boundary.
