---
scope: project
alwaysApply: true
description: Package
---

The GitHub Actions workflow at `.github/workflows/package.yml` builds `PicBase64.app` with SwiftPM, copies the `picbase64-mcp` companion binary into the app bundle, copies every `*.lproj` localization directory into the app bundle, signs ad hoc, and uploads `PicBase64-macos.zip`.
