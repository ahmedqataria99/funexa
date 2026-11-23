# Furnexa Branding and Icon Implementation Report V1

## Project scope

- Root: `d:\avatar\vs code\My APPS\furnexa`
- Existing branding was preserved: `assets\logo.png` remains the full Furnexa wordmark/brand master.
- Enabled Flutter platform: Windows only.
- No database, AI, Python service, business logic, screen, or application architecture changes were made.
- No Windows Release build or installer was created in this phase.

## Icon design

The Furnexa application icon uses a geometric letter-F/manufacturing silhouette inspired by furniture joinery and wood craftsmanship.

- Navy primary identity.
- Wood tones provide a recognizable split-spine/jointed-wood accent.
- Strong vertical and horizontal silhouette remains recognizable at taskbar sizes.
- No tagline or fine text is used in the launcher symbol.
- Transparent launcher variant is provided for Windows and future platform use.

## Generated assets

- Existing brand master: `assets/logo.png`
- Generated 1024 px square master: `assets/icons/furnexa_icon_1024_master.png`
- Transparent launcher PNG: `assets/icons/furnexa_icon_transparent.png`
- Windows ICO: `windows/runner/resources/app_icon.ico`
- Icon generator: `tool/generate_furnexa_icon.py`

## Windows ICO

The generated ICO contains:

- 16 x 16
- 32 x 32
- 48 x 48
- 256 x 256

Pillow validation reported RGBA PNG assets and an RGBA ICO containing the required entries.

## Flutter launcher integration

No `flutter_launcher_icons` package existed before this phase, and only Windows is enabled. A launcher package dependency was not added because it would be unnecessary for the direct Windows runner resource integration.

`pubspec.yaml` now registers:

- `assets/logo.png`
- `assets/icons/furnexa_icon_1024_master.png`
- `assets/icons/furnexa_icon_transparent.png`

The generated PNG assets are therefore real Flutter assets, while the Windows executable uses `windows/runner/resources/app_icon.ico` directly.

## Windows Runner changes

- Replaced `windows/runner/resources/app_icon.ico` with the Furnexa multi-resolution icon.
- Preserved `IDI_APP_ICON` as resource ID `101`.
- Preserved `Runner.rc` icon reference:
  `IDI_APP_ICON ICON "resources\\app_icon.ico"`
- Preserved `resource.h` and the existing window-class `LoadIcon` implementation.
- Changed the native window title from `furnexa` to `Furnexa` in `windows/runner/main.cpp`.
- Package identifier and existing Windows platform configuration were not changed.

## Commands

Icon generation:

```powershell
& 'd:\avatar\vs code\My APPS\furnixa-ai\.venv\Scripts\python.exe' tool\generate_furnexa_icon.py
```

Dependency and asset refresh:

```powershell
C:\flutter\bin\flutter.bat pub get
```

No launcher-package generation command was needed because Windows is integrated directly through its runner resource and no package was previously configured.

## Validation

- Existing worktree state was inspected and existing changes were preserved.
- Only the Windows platform folder is present.
- The 1024 px master PNG is valid RGBA.
- The 1024 px transparent PNG is valid RGBA with a `(0, 255)` alpha range.
- ICO validation found 16, 32, 48, and 256 px entries.
- `flutter pub get` completed successfully.
- VS Code reported no errors for `pubspec.yaml`, `Runner.rc`, or `main.cpp`.
- Generator Python validation reported no issues.
- No final Windows Release build was run.
- No installer was created.

## Remaining work

- Final Flutter icon embedding should be confirmed in the next standard Windows Release build.
- The next phase may package the Python runtime and run `flutter build windows --release`.
