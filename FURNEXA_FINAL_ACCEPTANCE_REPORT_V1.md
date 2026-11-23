# Furnexa Final Windows Application Acceptance Report V1

## Acceptance scope

- Exact Release folder: `d:\avatar\vs code\My APPS\furnexa\build\windows\x64\runner\Release`
- Exact application executable: `d:\avatar\vs code\My APPS\furnexa\build\windows\x64\runner\Release\furnexa.exe`
- Exact packaged AI executable: `d:\avatar\vs code\My APPS\furnexa\build\windows\x64\runner\Release\furnexa_ai_service.exe`
- Exact portable ZIP: `d:\avatar\vs code\My APPS\furnexa\build\release\furnexa-windows-x64-portable.zip`
- No rebuild was performed in this acceptance phase.
- No database, credentials, AI model, forecast algorithm, or application source were modified.

## Acceptance checklist

| Acceptance item | Result | Evidence / limitation |
|---|---|---|
| Portable ZIP extraction | PASS | ZIP extracted successfully to `C:\Users\ahmed\AppData\Local\Temp\furnexa-final-acceptance` outside the source workspace. |
| Extracted application startup | PASS | `furnexa.exe` opened directly from the extracted temporary folder. |
| No source-project dependency | PASS | Application was launched only from the extracted folder. |
| Python installation/JupyterLab dependency | PASS | The extracted AI executable started without a Python terminal command, JupyterLab, or source-project launch. |
| Application login | NOT TESTED | The live app reached the login screen, but Flutter controls were not exposed as accessible Windows UI Automation elements, and credentials were not entered. |
| Main factory modules load | NOT TESTED | No safe UI automation was available beyond the native Flutter window. |
| Existing synthetic records appear | NOT TESTED | Live database/UI record visibility was not automated. Existing synthetic database state was not modified. |
| Demand Intelligence UI | NOT TESTED | The page could not be safely opened or verified through accessible UI automation. |
| Product selection UI | NOT TESTED | No accessible Flutter product control was exposed. |
| Variant selection UI | NOT TESTED | No accessible Flutter variant control was exposed. |
| Warehouse selection UI | NOT TESTED | No accessible Flutter warehouse control was exposed. |
| Horizon selection UI | NOT TESTED | No accessible Flutter horizon control was exposed. |
| 7-day UI inference | NOT TESTED | The packaged runtime test passed 7-day authenticated inference, but the Furnexa UI trigger was not automated. |
| 14-day UI inference | NOT TESTED | The packaged runtime test passed 14-day authenticated inference, but the Furnexa UI trigger was not automated. |
| 30-day UI inference | NOT TESTED | The packaged runtime test passed 30-day authenticated inference, but the Furnexa UI trigger was not automated. |
| Changing product/variant/warehouse filters | NOT TESTED | UI controls were not accessible for safe automation. |
| Insufficient-data UI message | NOT TESTED | API behavior was previously verified; the UI message was not recorded. |
| Invalid-request UI handling | NOT TESTED | Source validation is implemented, but live UI behavior was not exercised. |
| Actual forecast response through Flutter bridge | PASS | The existing packaged-runtime test passed against the final packaged executable, with 7-, 14-, and 30-day responses and insufficient coverage. |
| Historical chart | NOT TESTED | The actual UI chart was not exercised. |
| Python startup | PASS | The extracted app automatically started `furnexa_ai_service.exe` from the temporary extraction folder. A loopback listener was observed on `127.0.0.1`. |
| Python health | PASS | The final packaged runtime test and bridge startup health checks passed. |
| Authenticated inference | PASS | The existing packaged runtime test completed with `All tests passed!` against the packaged executable. |
| Python shutdown | PASS | The extracted app and its app-owned AI child ended; no AI process or loopback listener remained after cleanup. |
| No orphaned AI process | PASS | Final process/listener checks found no running Furnexa or AI process. |
| Explorer icon | PASS | Windows extracted an icon from the compiled executable. The ICO is embedded through `Runner.rc`, not merely stored as an asset. |
| Taskbar icon | NOT TESTED | The live window appeared with the Furnexa title and icon; taskbar appearance was not captured separately. |
| Application title | PASS | Live window title was reported as `Furnexa`. |
| Default Flutter icon absent | PASS | The live application icon was the Furnexa/F letter symbol rather than the default Flutter icon. |
| Database isolation | PASS | No `.db`, `.sqlite`, or `.sqlite3` business database was present in the extracted folder or Release package. |

## Automated runtime evidence

- The extracted application launched directly from the temporary folder.
- Process inspection confirmed `furnexa.exe` and `furnexa_ai_service.exe` started in the extracted location.
- A loopback listener was observed for the extracted AI process on `127.0.0.1`.
- The final packaged-runtime test reported:

```text
00:00 +0: packaged Python service runs real 7, 14, and 30 day forecasts
00:43 +1: All tests passed!
```

- The compiled executable metadata reported:

```text
ProductName=Furnexa ERP
FileDescription=Furnexa ERP
ProductVersion=1.0.0+1
```

- Windows icon extraction from `furnexa.exe` succeeded.
- A live 1600 x 900 screenshot was captured and showed the Furnexa login screen with the application title `Furnexa`.

## UI automation limitation

Flutter's native window exposed only `ControlType.Pane | FLUTTERVIEW` through Windows UI Automation. Individual login fields, buttons, navigation items, dropdowns, charts, and Demand Intelligence controls were not available as accessible AutomationElements.

Because no safe credentials or UI interaction script was available, the following require manual acceptance:

- Login.
- Factory module navigation.
- Synthetic record visibility.
- Demand Intelligence navigation.
- Product, variant, and warehouse filtering.
- Live 7-, 14-, and 30-day UI forecast execution.
- Historical chart and forecast quantity visual verification.
- Insufficient-data and invalid-request UI messages.
- Taskbar icon appearance.

## Database safety

- The portable extraction contained no database file.
- No database reseed or migration was run.
- No administrator credentials or permissions were changed.
- The developer synthetic database was not replaced or modified.

## Remaining blockers

- Full manual Windows UI acceptance is the remaining blocker.
- The taskbar and individual Demand Intelligence UI interactions could not be verified automatically because Flutter controls were not exposed through Windows UI Automation.
- No installer or additional Release build was created.

## Final status

The portable application and packaged AI runtime operate together at the process and inference level. Full manual Furnexa workflow and UI acceptance remain NOT TESTED and should be performed interactively using the existing populated synthetic database.
