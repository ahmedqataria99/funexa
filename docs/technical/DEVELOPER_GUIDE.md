# Developer Guide

## Setup
1. Install Flutter and the project SDK from the existing environment.
2. Open the workspace root: `d:\avatar\vs code\My APPS\furnexa`
3. Run `flutter pub get`.
4. Run `flutter analyze` for static checks.
5. Start with the app entry point in `lib/main.dart`.

## Project structure
- `lib/core/`: shared infrastructure
- `lib/features/`: module-specific source code
- `test/`: feature and database tests
- `docs/`: project documentation

## Adding a feature
Follow the existing feature pattern:
1. Add a new folder under `lib/features/<feature>/`
2. Create `data/`, `domain/`, and `presentation/` as needed
3. Implement repository interfaces and local data-source classes mirroring the existing pattern
4. Add the page and relevant widgets under `presentation/`
5. Register any needed feature-level access checks and validation in the repository/data-source layer

## Adding database tables and migrations
1. Update the migration switch in `lib/core/database/furnexa_database.dart`
2. Use `PRAGMA foreign_keys = ON` and ensure constraints are explicit
3. Plan upgrades with `onUpgrade` and `migrate()`
4. Preserve backward compatibility where the app already depends on older table shapes

## Implementing repositories and data sources
Use the existing local-first pattern:
- repository interface in `domain/repositories/`
- implementation under `data/repositories/`
- SQLite work in `data/datasources/`
- business validation and permission checks near the data-source boundary

## Adding permissions
- Add or update the permission tables in the database migration layer.
- Enforce checks through `SecurityLocalDataSource` session logic.
- Make sure UI actions and repository functions both respect the same access boundary.

## Adding localization
- Add strings to `AppLocalizations` and the locale mapping.
- Prefer Arabic/English key-based access over hardcoded strings in new code.
- Keep the default locale consistent with the existing Arabic-first setup.

## Writing tests
- Place feature tests in `test/`
- Use real SQLite-backed database tests when validating persistence or migration logic.
- Avoid asserting mock-only behavior; prefer real repository/database scenarios.

## Verification commands
- `flutter analyze`
- `flutter test`
- `git diff --check`

## Audit note
This project remains a legacy ERP with a large existing codebase. Future development is safest when new work follows the existing repository/data-source pattern rather than introducing a new framework or app-wide architecture.
