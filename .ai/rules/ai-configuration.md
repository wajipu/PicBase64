---
scope: project
alwaysApply: true
description: AI Configuration
---

Use `.ai/` as the source of truth for AI agent configuration. Run `npm run ai:sync` after changing `.ai/rules/*` so generated files stay aligned across Codex, Claude Code, Cursor, and GitHub Copilot.

Generated target files include `AGENTS.md`, `CLAUDE.md`, `.cursor/rules/*.mdc`, and `.github/copilot-instructions.md`.
