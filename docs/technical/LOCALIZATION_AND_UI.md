# Localization and UI

## Localization architecture
The app uses Flutter localization and a custom delegate architecture:
- `AppLocalizations`
- `AppLocalizationsDelegate`
- `supportedLocales` includes Arabic and English

The app is configured in `lib/main.dart` with:
- Arabic as the default locale
- English as the secondary locale
- material and Cupertino delegates enabled

## RTL support
The project is Arabic-first and uses right-to-left behavior through the locale and Material widgets. The user interface consistently uses Arabic labels in many page classes and the global app shell.

## Theme system
The theme layer is centralized in `lib/core/theme/app_theme.dart`.
- light and dark themes are defined
- app colors and success/error surfaces are reused within UI feedback
- theme toggling is persisted through `AppSettings`

## Shared UI components
The codebase includes shared widgets such as:
- `FurnexaAppShell`
- `FurnexaLogo`
- `FurnexaForm`
- `FurnexaDetail`
- `FurnexaInfoSection`
- shared form field wrappers

## Known localization gaps
- Several pages still use hardcoded Arabic strings rather than localized keys.
- Some `TextField` code in older pages still uses deprecated `value` properties, which is a lint warning rather than a functional blocker.
- The user interface is localized, but it is not fully centralized through a single translation source for all strings.

## Implementation status
Localization is present and functional in the app shell and major features, but it remains partially inconsistent across the older UI code.
