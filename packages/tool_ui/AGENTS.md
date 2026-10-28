# Shared tool UI

Read [shared tools architecture](../../docs/tdd/admin_tools.md) and
[editor UI contracts](../../docs/tdd/editor_ui_system.md).

- Own neutral Flutter theme/tokens/cards/catalogs/layout only. No filesystem,
  Firebase, authoring documents, session history or Admin delivery state.
- Editor and Admin consume this implementation directly; avoid editor-prefixed
  aliases or copied widgets. Keep domain-specific behavior with its app.
- Preserve responsive subtree state, focus exclusion and scroll ownership.
- Resolve dependencies at the root workspace. Run package tests and the affected
  editor/Admin tests for shared changes; inspect both consumers when changing API.
- Follow [shared tool changes](../../.agent/workflows/change-shared-tools.md).
