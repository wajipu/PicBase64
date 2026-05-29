# PicBase64 Agent Notes

## Project

PicBase64 is a native macOS menu bar app written in Swift and AppKit. It converts screenshots or clipboard images to Base64 and previews Base64 image data.

## Build

```bash
swiftc -O \
  -framework AppKit \
  -framework UserNotifications \
  -framework UniformTypeIdentifiers \
  PicBase64.swift SettingsWindow.swift IconManager.swift main.swift \
  -o PicBase64
```

## Package

The GitHub Actions workflow at `.github/workflows/package.yml` builds `PicBase64.app`, copies every `*.lproj` localization directory into the app bundle, signs ad hoc, and uploads `PicBase64-macos.zip`.

## Localization

User-facing text should go through `L("key")` or `LF("key", args...)` and be added to every localization directory:

- `zh-Hans.lproj`
- `en.lproj`
- `ug.lproj`

Do not add hard-coded UI strings in Swift unless they are debug-only.

## Repository Rules

Do not commit generated build output such as `PicBase64`, `PicBase64.app`, `.build`, or `build/`. Keep secrets out of repository-level Vibe Code config.
