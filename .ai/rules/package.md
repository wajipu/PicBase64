---
scope: project
alwaysApply: true
description: Package
---

The GitHub Actions workflow at `.github/workflows/package.yml` builds `PicBase64.app`, copies every `*.lproj` localization directory into the app bundle, signs ad hoc, and uploads `PicBase64-macos.zip`.
