Use `.ai/` as the source of truth for AI agent configuration. Run `npm run ai:sync` after changing `.ai/rules/*` so generated files stay aligned across Codex, Claude Code, Cursor, and GitHub Copilot.

Generated target files include `AGENTS.md`, `CLAUDE.md`, `.cursor/rules/*.mdc`, and `.github/copilot-instructions.md`.

---

```bash
swift build -c release --product PicBase64
swift build -c release --product picbase64-mcp
```

---

User-facing text should go through `L("key")` or `LF("key", args...)` and be added to every localization directory:

- `zh-Hans.lproj`
- `en.lproj`
- `ug.lproj`

Do not add hard-coded UI strings in Swift unless they are debug-only.

---

The GitHub Actions workflow at `.github/workflows/package.yml` builds `PicBase64.app` with SwiftPM, copies the `picbase64-mcp` companion binary into the app bundle, copies every `*.lproj` localization directory into the app bundle, signs ad hoc, and uploads `PicBase64-macos.zip`.

---

PicBase64 is a native macOS menu bar app written in Swift and AppKit. It converts screenshots or clipboard images to Base64, previews Base64 image data, and ships a local MCP companion server so host AI agents can call the same local image tools.

---

Do not commit generated build output such as `PicBase64`, `PicBase64.app`, `.build`, or `build/`. Keep secrets out of repository-level AI configuration files.
