# Board lifecycle and account deletion

Owner request, October 27, 2026: remove obsolete pre-release board data in dev,
keep the serving release's current windows, and prevent board growth from
making account erasure take hours. Unrelated Android signing, release guidance,
and privacy-policy edits in the working tree must be preserved.

Acceptance:

- [x] Scheduled erasure performs bounded, checkpointed batches with fair request
  selection, time/step limits, and no spinning on quiet periods or live leases.
- [x] Board provisioning defaults to current windows only.
- [x] Board maintenance retires obsolete partitions and removes their nested
  projections without touching active run sessions or canonical rewards.
- [x] Projection transactions cannot recreate retired/missing boards' children.
- [x] Emulator/worker regressions cover realistic board counts and retries.
- [ ] Authorized dev cleanup keeps the three current `2026.10.21` boards;
  inventory, removals, remaining boards and deletion progress are verified live.
- [ ] Deployment status and remaining release gates are explicit.

The serving project is `rpg-runner-d7add` (dev). Initial read-only inventory:
184 boards across 22 gameplay versions; 107 past, 44 current, 33 future. One
account deletion was on final reconciliation with no retryable failures.
No application deployment is claimed by this checklist.

## Validation and live checkpoint

- Targeted Functions emulator checks: 27 passed, including 184-extra-board
  erasure, per-stage failure replay, lease serialization, retirement and grace.
- Worker: `dart analyze` passed; `dart test test` passed all 298 tests.
- Read-only dev preview: 181 removal candidates; exactly three current
  `2026.10.21` boards protected. Projection queue had zero pending tasks.
- Dev board-maintenance scheduler and projection queue temporarily paused for
  authorized cleanup. Queue must be restored; legacy board provisioner remains
  paused until the current-window implementation is deployed, to prevent it
  recreating the three future windows. Current windows still provision on demand.
- Runtime changes and alert policy have not been deployed.

Live cleanup completed October 27, 2026 around 15:51 UTC: 181 board parents and
160 nested leaderboard documents deleted; zero ghost objects existed under the
removed board prefixes. Three current `2026.10.21` board parents remain, all
active. Projection queue restored to RUNNING. The legacy board provisioner is
still PAUSED until deployment of current-window provisioning. No run sessions,
canonical accepted runs, grants or ownership documents were targeted.

Final local verification from the repository root: `corepack pnpm --dir
functions build` and `build:test` passed; `corepack pnpm --dir functions test`
passed all 266 tests. Worker verification from `services/replay_validator`:
`dart analyze`, `dart test test` (298 tests), and `dart compile exe bin/server.dart
-o ../../.tmp/board_lifecycle_replay_validator.exe` all passed. Runtime source
was unchanged after these checks; later edits were tooling/documentation only.
The final transactional parent/child deletion guard additionally passed all 11
board provisioning/retention tests before live use.

Root-checkout release Plan reported a simulation digest mismatch with the live
baseline despite no simulation source differences from deployed `a4f99b89`.
Resolve this in the canonical clean LF checkout; do not bypass the gate or bump
gameplay merely to hide a line-ending/input-provenance difference.
