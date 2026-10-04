# Testing

The repository contains core, feature-focused, UI, and system integration tests. Database tests reset and close the singleton between cases where required. Serial execution is used for deterministic SQLite verification:

```powershell
flutter test --concurrency=1
```

Focused commands:

```powershell
flutter test --concurrency=1 test/core_foundation_test.dart
flutter test --concurrency=1 test/features/documents/documents_feature_test.dart
flutter analyze
```

## Verified Results

- Core foundation/database test: 8 passed, exit code `0`.
- Documents feature test: 41 passed.
- Earlier development reports include successful full-suite milestones, including a recorded `All tests passed` result with 304 tests. That is historical evidence, not the final recovery result.

## Current Result

The latest full regression is **BLOCKED** before the test suite executes. Flutter fails while installing the Windows native asset:

```text
PathExistsException: Cannot copy file to
D:\avatar\vs code\My APPS\furnexa\build\native_assets\windows\sqlite3.dll
OS Error: Cannot create a file when that file already exists, errno = 183
```

The source path is under `.dart_tool/hooks_runner/shared/sqlite3/.../sqlite3.dll`. Cleanup performed: `flutter clean`, removal of generated `build/` and `.dart_tool/`, and locked `flutter pub get`. This is classified as a Flutter/native-asset/Windows environment issue, not a Furnexa business-logic failure.
