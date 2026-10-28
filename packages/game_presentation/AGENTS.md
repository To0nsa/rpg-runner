# Shared game presentation

Read [shared tools architecture](../../docs/tdd/admin_tools.md).

- Own icons, atlas mappings, labels and validated display values for existing
  Core catalog identities. Core remains pure Dart; this package may use Flutter.
- No `rpg_runner`, editor/Admin imports, filesystem traversal, backend calls or
  ownership mutation. Game and Admin supply their own asset bundle.
- Keep canonical asset keys; do not copy artwork into a second package tree.
  Manage image listeners/handles across bundle changes, replacement and disposal.
- Backend gift allowlists remain authoritative. Unknown local display identities
  fail closed; preserve readers for IDs retained in issued messages.
- Resolve dependencies at the root. Verify affected game icon/inbox tests and
  Admin's generated backend-catalog rendering test. Follow
  [shared tool changes](../../.agent/workflows/change-shared-tools.md).
