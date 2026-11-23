# Furnexa AI Runtime Blockers Fix Report V1

## Scope and state

- Furnexa root: `d:\avatar\vs code\My APPS\furnexa`
- Furnexa AI root: `d:\avatar\vs code\My APPS\furnixa-ai`
- Existing Furnexa worktree changes were preserved. The Furnexa AI root is not a Git repository.
- No synthetic database was reseeded, replaced, migrated, or modified for this phase.
- Verification used the existing `d:\avatar\vs code\My APPS\furnixa-ai\.venv\Scripts\python.exe`.
- No Flutter Windows Release build was started.

## Python child-process exit

### Evidence

- Direct development launch of `src\api\local_ai_service.py` with the existing venv stayed running and `/health` returned `{"status":"ready"}` on loopback.
- The Python implementation and forecasting implementation executed in 80 passing source tests.
- The Flutter bridge previously launched `python` in development mode without an explicit working directory and without prioritizing the project venv.
- It lacked process stdout/stderr and exit-code diagnostics.
- The packaged executable was built independently, listened on `127.0.0.1:18767`, authenticated `/health` returned ready, and accepted packaged forecasts.

### Root cause

The direct Python service implementation was healthy. The remaining development launcher blocker was unreliable executable resolution and missing launch context/diagnostics. The packaged process required successful cold extraction and process monitoring; an independently captured launch remained alive and passed health.

### Correction

- Development runtime now prefers `FURNEXA_PYTHON_EXECUTABLE`.
- Otherwise it uses `<furnixa-ai>\.venv\Scripts\python.exe`.
- It falls back to `python` only if the venv cannot be found.
- The AI project root is set as process working directory.
- The bridge captures bounded stdout/stderr and startup exit code.
- PyInstaller declares Uvicorn and web-stack hidden imports and collects FastAPI, Pydantic, Uvicorn, pandas, and NumPy.

The 60-second startup timeout remains justified for cold packaged extraction and startup.

## Warehouse anonymization

The synthetic integration test incorrectly compared opaque warehouse, product, and variant fields with raw database IDs. The security contract is that raw IDs remain in Flutter SQL/authorization, while HMAC-SHA256 opaque tokens are sent to Python.

Updated test assertions now derive tokens from the payload and verify:

- The sellable warehouse maps consistently to one opaque token.
- The raw sellable and quarantine IDs do not appear in payload/dataset warehouse fields.
- Product and variant identities are also compared using payload-derived tokens.
- Authorization scope violations remain zero.

## Verification results

### Python

- `80 passed, 3 warnings` using the existing `.venv`.

### Flutter

- Synthetic integration test: `1 passed`.
- Bridge, payload, historical dataset, and synthetic test set: `26 passed`.
- Packaged runtime test: `All tests passed` for 7, 14, 30, and insufficient 179-row coverage.
- Targeted Dart analysis: no errors or changed-file warnings; 12 fixture-only interpolation infos remain.

### Packaged service

- Independent PyInstaller build produced `build\phase1-python-service\furnexa_ai_service.exe`.
- Loopback-only health succeeded with authentication.
- Authenticated 7-, 14-, and 30-day forecasts passed through the Flutter bridge.
- Insufficient data returned `insufficient_data`.
- The independent service was terminated and the loopback port was released.

## Files changed

- `src\api\local_ai_service.py`
- `tool\build_windows_release.ps1`
- `lib\features\ai\data\local_ai_runtime.dart`
- `lib\features\ai\data\local_ai_process_bridge.dart`
- `test\synthetic_factory_sales_integration_test.dart`
- `FURNEXA_AI_RUNTIME_BLOCKERS_FIX_REPORT_V1.md`

## Remaining boundaries

- Windows application Release build and icon work remain for the next phase.
- No synthetic database replacement or reseed occurred.
- This report does not claim commercial forecasting validation or Windows application Release verification.
