# Testing and Quality

## Test structure
The project contains a broad suite under `test/` with feature-focused files such as:
- `production_feature_test.dart`
- `raw_materials_products_feature_test.dart`
- `factory_structure_feature_test.dart`
- `returns_quality_feature_test.dart`
- `returns_quality_migration_test.dart`
- `inventory_identity_migration_test.dart`
- `production_unit_snapshot_migration_test.dart`
- `database_persistence_integration_test.dart`
- `purchasing_feature_test.dart`
- `sales_feature_test.dart`
- `returns_quality_migration_test.dart`
- UI tests such as `purchase_returns_ui_test.dart` and `sales_returns_ui_test.dart`

## Coverage themes
The tests cover:
- database migration and identity changes
- production order lifecycle and BOM snapshots
- purchasing and returns flows
- factory structure and raw material product logic
- UI-level return workflows

## Verification performed in this audit
- `flutter analyze` was run before and after the fix.
- `git diff --check` was run.
- `flutter pub get` was used after adding the missing direct dependency for `collection`.

## Actual quality status
- No Dart analyzer errors remain after the BOM fix.
- The analyzer still reports many info-level diagnostics across older pages, especially style, deprecations, and `BuildContext` async checks.
- Some legacy warnings remain unresolved because they are broad, non-blocking, and would require a large, behavior-neutral cleanup across many files.

## Environment note
The project is testable locally but not every module is equally verified. Some test files are present, but broad runtime verification would require dedicated execution of the full Flutter test suite in the target Windows desktop environment.
