# Release

## Intended Windows Process

1. Resolve the native SQLite asset issue and obtain a complete green serial regression.
2. Run static analysis and address only blocking errors.
3. Build the release artifact:

```powershell
flutter build windows --release
```

4. Verify `build/windows/x64/runner/Release/` contains the Furnexa executable, required DLLs, assets, and packaged `sqlite3.dll`.
5. Run the executable smoke test: startup, login, dashboard, SQLite initialization, navigation, and clean close.
6. Exercise a safe local workflow using test data: Login -> Product -> Customer -> Sales Order -> Delivery -> Dispatch.
7. Package the verified output with an external Windows installer such as Inno Setup. The installer should provide the executable, DLLs, assets, icon, shortcuts, version information, and uninstaller.

## Current Status

The final release build and executable smoke test have not been completed. Full regression is blocked during Flutter native asset installation by `PathExistsException` for `sqlite3.dll` (Windows errno 183). Therefore the factual status is:

**RELEASE VERIFICATION BLOCKED**

This is an environment/toolchain limitation. No application-code workaround or dependency upgrade is justified by the current evidence.
