---
description: "Change shared editor/Admin presentation or the Admin gift workflow across its owners."
---

# Change shared tools

1. Read [tool UI](../../packages/tool_ui/AGENTS.md),
   [game presentation](../../packages/game_presentation/AGENTS.md),
   [Admin](../../tools/admin/AGENTS.md) and the affected consumer's instructions.
   Inspect [architecture](../../docs/tdd/admin_tools.md) and current implementations.
2. Keep presentation in shared packages and app/domain state with its owner.
   Migrate real consumers together; avoid wrappers or a second catalog/asset tree.
   Editor authoring authority and Admin credentials must remain separate.
3. For gift contract changes, compose the
   [cross-layer workflow](change-cross-layer-contract.md): update the backend
   producer, validation/grant path, native review, game decoder/UI, retention and
   tests together. Preserve legacy hashes and retained gift compatibility.
4. Build Functions before refreshing the generated Admin catalog fixture. Verify
   catalog parity, shared icons, responsive/focus behavior, durable uncertain
   retries, explicit environment isolation and game claims. Use the emulator for
   authoritative grant tests; fixture UI success is not backend/cloud evidence.
5. Update TDD/GDD, guides and routing when ownership changes. Record exact local
   evidence and activation prerequisites. Gate activation, deployments and real
   player deliveries require explicit authorization; do not perform them as tests.

For milestones use [coordination](coordinate-work.md). This workflow routes work;
it does not create agents, grant delegation or replace session permissions.
