# Rescue release operations

Status: pending deployment. Repository implementation and local validation do
not change remote services or disposable test state. The game is not live.

The matching release is gameplay `2026.09.8`, rules `rules-v2`, score `score-v2`,
ghost `ghost-v1`, replay/command format 1. It includes the earlier Forest
navigation and Poison Darts changes, plus grounded melee combat holding on
direct walk routes. This combat fix changes replay outcomes and is included in
the still-unpublished `2026.09.8` build; client and worker must use the same Core.
Client issuance, generated content,
Functions board/ticket defaults and replay worker must agree. The new worker
does not run historical Core versions.

- [ ] Stop old ticket issuance and cancel open disposable test runs.
- [ ] Let in-flight validation and settlement finish; reset remaining disposable
  run/board state without bypassing leases, canonical grants or idempotency.
- [ ] Build the matching immutable worker image. Rerun the compiled 36,000-tick
  strict benchmark inside the release container with one CPU and 512 MiB;
  retain its report alongside the local validation evidence.
- [ ] Deploy matching generated content, worker, Functions and client. Remove
  stale supported-version environment overrides. Use the existing validator
  [deployment procedure](../../services/replay_validator/README.md).
- [ ] Enable issuance with fresh boards and tickets. Smoke-test Practice and
  ranked rescue scoring, uploaded replay acceptance, once-only settlement,
  leaderboard totals and generation-pinned ghost playback.
- [ ] Confirm retired gameplay/score tickets are rejected and archive this
  checklist with the deployment evidence.

Cancellation/reset replaces old-run migration or a ticket-lifetime wait for this
pre-live cutover. Historical production replay support is not claimed. Existing
accepted artifacts retain their digest and generation lineage; no remote data
reset is authorized merely by this checklist.
