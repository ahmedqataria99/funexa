# Furnexa Windows Release Build Report V1

## Project roots

- Flutter project: `d:\avatar\vs code\My APPS\furnexa`
- Python project: `d:\avatar\vs code\My APPS\furnixa-ai`
- Existing Python environment: `d:\avatar\vs code\My APPS\furnixa-ai\.venv\Scripts\python.exe`

## Icon resource

- Windows ICO: `d:\avatar\vs code\My APPS\furnexa\windows\runner\resources\app_icon.ico`
- Runner resource script: `d:\avatar\vs code\My APPS\furnexa\windows\runner\Runner.rc`
- ICO resource reference: `IDI_APP_ICON ICON "resources\\app_icon.ico"`
- Native window title: `Furnexa`
- Windows metadata: Product name `Furnexa ERP`, file description `Furnexa ERP`, version `1.0.0+1`
- The compiled executable exposed an extracted icon with Windows icon API validation.

## Flutter build

Exact command:

```powershell
C:\flutter\bin\flutter.bat build windows --release
```

Build result:

- Standard Flutter Windows Release build succeeded.
- Final output: `d:\avatar\vs code\My APPS\furnexa\build\windows\x64\runner\Release\`
- Executable: `d:\avatar\vs code\My APPS\furnexa\build\windows\x64\runner\Release\furnexa.exe`
- Executable size: `70,656` bytes.

One attempted rebuild exposed an unsupported `AppExitResponse` API from the experimental close-lifecycle edit. That edit was removed and the standard build succeeded with the existing lifecycle implementation.

## Python packaging

Existing virtual environment interpreter used:

```text
.venv\Scripts\python.exe
```

Packaging command used:

```powershell
.\.venv\Scripts\python.exe -m PyInstaller --clean --noconfirm --onefile --noconsole --name furnexa_ai_service --hidden-import uvicorn.lifespan.on --hidden-import uvicorn.lifespan.off --hidden-import uvicorn.protocols.http.auto --hidden-import uvicorn.protocols.http.h11_impl --hidden-import uvicorn.protocols.websockets.auto --hidden-import uvicorn.loops.auto --collect-all fastapi --collect-all pydantic --collect-all uvicorn --collect-all pandas --collect-all numpy --distpath <Release> --workpath <work> --specpath <spec> src\api\local_ai_service.py
```

Packaging result:

- Success.
- Packaged executable: `d:\avatar\vs code\My APPS\furnexa\build\windows\x64\runner\Release\furnexa_ai_service.exe`
- Packaged executable size: `162,103,851` bytes.
- The executable is beside `furnexa.exe`, matching `LocalAiRuntime.start`.

## Database isolation

Final Release database-file count: `0`.

No `.db`, `.sqlite`, or `.sqlite3` file was found in the Release folder or portable ZIP. The developer synthetic database was not copied, replaced, reseeded, or modified.

## Portable ZIP

- ZIP: `d:\avatar\vs code\My APPS\furnexa\build\release\furnexa-windows-x64-portable.zip`
- Size: `179,731,540` bytes.
- ZIP entry count: `25`.
- Verified entries include `furnexa.exe` and `furnexa_ai_service.exe`, plus Flutter runtime and assets.

## Release smoke test

Direct launch:

- Launched `furnexa.exe` from the Release directory without `flutter run`.
- The Furnexa process started.
- `furnexa_ai_service.exe` started automatically beside it.
- Application process and AI child were both observed running.
- The direct launch used the existing local process bridge and loopback authentication mechanism.

Inference:

- Existing packaged-runtime test passed against the final Release AI executable.
- Horizons 7, 14, and 30 passed.
- Insufficient 179-row coverage returned `insufficient_data`.
- Final test log: `All tests passed!`.

Shutdown:

- A normal Windows close message was sent to the application window.
- `furnexa.exe` exited.
- The application-owned `furnexa_ai_service.exe` child exited.
- Remaining child process was from the separate packaged test and was cleaned up explicitly.
- No Furnexa or AI process remained.
- No AI loopback listener remained.

## Static and asset validation

- The compiled executable metadata was correct.
- Windows icon extraction returned an icon from `furnexa.exe`.
- Targeted Dart analysis reported only two existing single-statement `if` formatting infos in `lib/main.dart`; no AI bridge/runtime errors were reported.
- `flutter pub get` was completed earlier during icon integration.

## Verification boundaries

### Verified

- Standard Flutter Release build succeeded.
- Furnexa executable starts directly from Release.
- Packaged AI runtime starts automatically beside the executable.
- Authenticated packaged inference executes.
- App-owned AI child closes with the app.
- No SQLite database is bundled.
- Portable ZIP contains the complete Release runtime folder.

### Not claimed

- Full application UI was not manually exercised for every screen.
- The entire Demand Intelligence UI workflow was not recorded through a GUI automation session.
- No installer was created.
- No commercial forecasting validation was performed.

## Remaining limitation

The direct smoke test confirms application startup and automatic AI startup, and the existing Flutter packaged-runtime test confirms real forecast execution. Full manual UI verification remains for the user.
