---
scope: project
alwaysApply: true
description: Build
---

```bash
swiftc -O \
  -framework AppKit \
  -framework UserNotifications \
  -framework UniformTypeIdentifiers \
  PicBase64.swift SettingsWindow.swift IconManager.swift main.swift \
  -o PicBase64
```
