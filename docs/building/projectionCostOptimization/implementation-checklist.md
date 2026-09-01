# Early-Release Projection Cost Optimization Implementation Checklist

Status: ready for implementation.

Strategy:
[strategy.md](strategy.md)

## How to use this checklist

- `[x]` means implementation and recorded evidence satisfy the item.
- `[ ]` means work or verification remains.
- Complete phases in order unless a phase explicitly permits parallel work.
- Do not trade projection correctness, deletion safety, or retry behavior for a
  lower idle metric.
- Archive this folder only after production rollout and the 24-hour idle
  observation are complete.

## Locked release outcome

- Normal projection is event-driven and prompt.
- A healthy scheduled invocation enqueues at most four boards; retries remain
  safe and observable.
- A full recovery cycle completes within 24 hours for up to 96 retained boards.
- Unchanged projection content produces no Firestore writes.
- Minimum instances remain zero.
- The expected no-player bill is limited to the Scheduler baseline unless a
  measured SKU explains otherwise.

---

## Phase 0 — Freeze baseline and invariants

Objective:

- preserve evidence and correctness requirements before changing cadence or
  write behavior

Tasks:

- [ ] Record the implementation commit and UTC observation window.
- [ ] Record the live retained-board count.
- [ ] Record the live Scheduler job names, states, and schedules.
- [ ] Record minimum and maximum instances for all Functions and
  `replay-validator`.
- [ ] Record 24-hour counts for:
  - [ ] `/tasks/project` requests by status;
  - [ ] validator projection request seconds;
  - [ ] Firestore reads, writes, and deletes;
  - [ ] Cloud Tasks creation and delivery attempts;
  - [ ] queue retry count and oldest-task age.
- [ ] Record Artifact Registry, Functions source bucket, replay bucket, and
  Hosting storage totals.
- [ ] Record the billing report grouped by service and SKU, or document that
  billing export is unavailable and capture an authorized console report.
- [ ] Freeze the early-release repair SLO at 24 hours.
- [ ] Freeze the checked-in release defaults at hourly cadence and batch `4`.
- [ ] Confirm settlement remains independent of leaderboard/ghost projection.
- [ ] Confirm the existing leaderboard-before-ghost-after ordering remains
  required.
- [ ] Confirm closed and empty boards remain in recovery scope until a separate
  archival strategy is approved.

Gate:

- [ ] baseline evidence is reproducible and every correctness invariant has an
  owner

---

## Phase 1 — Specify materialized-view revision behavior in tests

Objective:

- make no-op semantics executable before changing production writes

Validator tests:

- [x] Add a legacy Top-10 fixture with `sourceRevision` but without the current
  materialization version/revision; verify one safe rewrite adds the current
  fields and removes `sourceRevision`.
- [x] Add an unchanged empty-board fixture; verify both leaderboard passes
  perform zero writes after initial convergence.
- [x] Add an unchanged populated-board fixture; verify:
  - [x] no Top-10 view write;
  - [x] no `ghostEligible` write;
  - [x] no `updatedAtMs` change.
- [x] Add a score/order change fixture; verify one new revision and the expected
  membership/view writes.
- [x] Add a ghost-availability change fixture; verify the second leaderboard
  pass writes a different materialized revision.
- [x] Add a display-name or character projection change fixture if those fields
  are intended to update existing materialized entries.
- [x] Add replay reference, generation, and digest change fixtures; verify the
  revision changes and ghost evidence is not silently retained.
- [x] Add a materialization-schema-version change fixture; verify an old or
  missing version forces one safe rewrite.
- [x] Verify the revision is computed from the exact persisted Top-10 consumer
  payload and excludes all top-level and entry-level timestamps.
- [x] Verify independently stored ghost-manifest metadata that is not persisted
  in the Top-10 payload does not create revision churn.
- [x] Add a player entering and leaving Top 10; verify only changed
  `ghostEligible` values are written.
- [x] Add a stale outgoing-player eligibility fixture; verify its actual
  player-best field is read and a duplicate demotion write is skipped.
- [x] Add an optimistic conflict fixture; verify the existing bounded retry
  behavior remains.
- [x] Add a partial first-pass fixture; verify retry converges rather than
  treating incomplete state as unchanged.
- [x] Prove canonical revision input excludes timestamps and is stable across
  repeated runs.

Gate:

- [x] focused tests fail against the prior unconditional-write behavior and
  encode every required change

---

## Phase 2 — Implement no-op leaderboard materialization

Objective:

- stop Firestore mutations when the consumer-visible view is already correct

Tasks:

- [x] Extend `Top10ViewSnapshot` to retain the stored materialized revision.
- [x] Extend `Top10ViewSnapshot` to retain the stored materialization schema
  version.
- [x] Define one canonical materialized-revision payload equal to the persisted
  Top-10 consumer payload except for explicitly excluded timestamps.
- [x] Set and persist a fixed `materializationSchemaVersion`.
- [x] Compute the revision through existing canonical SHA-256 utilities.
- [x] Persist `materializedRevision` on every changed Top-10 view.
- [x] Treat a missing, malformed, or wrong-version revision as stale and
  rewrite once.
- [x] Stop emitting or consulting `sourceRevision` and remove that inert field
  during the one-way legacy rewrite.
- [x] Compare desired eligibility with the actual current player-best field
  before calling `setPlayerBestGhostEligibleIfChanged`.
- [x] Skip unchanged `ghostEligible: true` writes for retained Top-10 players.
- [x] For players leaving the previous Top 10, use a conditional read/write and
  write `ghostEligible: false` only when the stored value differs.
- [x] Skip `writeTop10View` when the desired materialized revision matches.
- [x] Do not advance `updatedAtMs` on a skipped write.
- [x] Preserve the optimistic update-time precondition for changed views.
- [x] Preserve account-deletion fencing for every user-owned write.
- [x] Emit bounded metrics or structured outcomes for changed, unchanged,
  ghost-only, conflict, and retry results.
- [x] Remove or update stale comments that describe unconditional rebuilding as
  an always-writing operation.
- [x] Keep public/internal API documentation focused on convergence invariants
  and non-obvious side effects.

Focused validation:

- [x] `dart format` changed validator files.
- [x] `dart analyze services/replay_validator`.
- [x] `dart test services/replay_validator/test`.
- [x] Compile the validator executable.

Gate:

- [x] after initial convergence, another reconciliation of the same empty or
  populated board performs the required projection reads but zero writes

---

## Phase 3 — Bound the scheduled recovery sweep

Objective:

- replace the all-board 15-minute fan-out with a measurable 24-hour recovery
  envelope

Functions changes:

- [x] Change `runProjectionReconciliation` to `every 60 minutes`.
- [x] Change the checked-in default batch size from `64` to `4`.
- [x] Query at most `batchSize + 1` board documents and enqueue only the first
  `batchSize` documents.
- [x] Keep a positive bounded environment override for incident response.
- [x] Ensure absent, zero, negative, or malformed overrides resolve to `4`.
- [x] Align reconciliation task-key buckets with the one-hour cadence.
- [x] Keep one page per scheduler invocation.
- [x] Preserve ordered document-id cursor traversal.
- [x] Advance the cursor only after every selected board task is durably
  enqueued.
- [x] Persist cursor advancement with an optimistic precondition or transaction
  that proves the starting cursor is still current.
- [x] If the cursor precondition fails, preserve newer state and report a stale
  overlapping invocation rather than moving the cursor backward.
- [x] Keep the cursor unchanged after any enqueue failure.
- [x] Use the lookahead document to wrap partial and exact-multiple final pages
  to `null` without a separate empty invocation.
- [x] Include effective cadence, batch size, queried count including lookahead,
  selected count, enqueued count, and cursor-commit outcome in the structured
  result, plus retained-board count and completed-cycle duration for the
  operational guardrail.

Functions tests:

- [x] Empty board collection enqueues zero tasks and leaves a valid cursor
  state.
- [x] A four-board page enqueues exactly four deterministic tasks.
- [x] A failed task leaves the page replayable.
- [x] Replaying a page in the same hourly bucket does not duplicate work.
- [x] A partial final page wraps to the beginning on the next cycle.
- [x] An exact-multiple final page wraps in the same invocation and the next
  hourly invocation starts at the first board.
- [x] An overlapping invocation whose cursor becomes stale cannot overwrite
  newer cursor progress.
- [x] A late retry in another hourly task-key bucket may enqueue duplicate work
  but remains convergent and observable.
- [x] Fifty-four boards complete one cycle in 14 successful hourly
  invocations.
- [x] Up to 96 boards satisfy the 24-hour full-cycle SLO.
- [x] A new document inserted before the current cursor is picked up after the
  next wrap.
- [x] Existing projection dispatch, auth, queue identity, and retry tests remain
  green.

Focused validation:

- [x] `corepack pnpm --dir functions build`.
- [x] `corepack pnpm --dir functions test`.

Gate:

- [x] source defaults and tests prove no scheduler invocation can enqueue more
  than four board-reconciliation tasks without an explicit reviewed override

---

## Phase 4 — Tune operational logging without weakening alerts

Objective:

- retain actionable failure evidence while reducing high-volume background
  operation logs

Tasks:

- [ ] Inventory queue-level, request-level, validator, and log-metric output for
  one successful board task.
- [x] Keep application error, retry, resource rejection, and internal-error
  logs unsampled.
- [x] Change projection Cloud Tasks queue operation-log sampling from `1.0` to
  `0.1` in checked-in deployment tooling.
- [x] Verify queue retry and backlog alerts do not depend on sampled queue
  logs.
- [ ] Verify all 11 existing user-defined log metrics still receive the events
  required by their policies.
- [x] Add or update a dashboard view for:
  - [x] changed versus unchanged reconciliation;
  - [x] tasks per reconciliation invocation;
  - [x] full cursor-cycle duration;
  - [x] daily Firestore reads and writes;
  - [x] projection request time;
  - [x] retained-board count.
- [x] Add an automated operator alert at 80 retained boards.
- [x] Document the decision required before 96 retained boards.
- [ ] Confirm a Cloud Billing budget alert and notification channel are active.

Gate:

- [ ] queue operation logs are sampled, independent failure evidence is
  complete, and board-count
  growth cannot silently violate the repair SLO

---

## Phase 5 — Update architecture and operations documentation

Objective:

- make the implemented cadence, no-op contract, and recovery SLO authoritative

Tasks:

- [x] Update `docs/tdd/replay_validator_worker.md`.
- [x] Update `docs/tdd/firebase_cloud_functions_overview.md`.
- [x] Update `docs/tdd/ghost_run_flow.md`.
- [x] Update `services/replay_validator/README.md` deployment and rollback
  guidance.
- [x] Update Functions monitoring/runbook documentation for the new cadence and
  page limit.
- [x] Update `functions/AGENTS.md` if its reconciliation guidance needs the
  bounded-page/no-op invariants.
- [x] Update `services/replay_validator/AGENTS.md` if its projection guidance
  needs the materialized-revision invariant.
- [x] Confirm no GDD text changes because player-facing behavior is unchanged.
- [x] Record current official pricing links and the date they were checked.

Gate:

- [x] no active document still claims that every retained board is reconciled
  every 15 minutes or that unchanged views are rewritten

---

## Phase 6 — Run the full local validation gate

- [ ] `dart analyze services/replay_validator`.
- [ ] `dart test services/replay_validator/test`.
- [ ] `dart compile exe services/replay_validator/bin/server.dart -o
  .tmp/replay_validator_server`.
- [ ] `corepack pnpm --dir functions build`.
- [ ] `corepack pnpm --dir functions test`.
- [ ] Run focused cursor, dispatch, leaderboard, ghost, account-deletion, and
  projection retry tests.
- [ ] Inspect `git diff --check`.
- [ ] Confirm no generated `functions/lib/**` or `functions/lib_test/**` file
  was edited by hand.
- [ ] Confirm no client or shared protocol change is required.
- [ ] Record projection reads per reconciled board and per complete cursor
  cycle for the release fixture/corpus.
- [ ] Verify the `below 1,000 reads/day` target is documented as applying to the
  recorded release corpus rather than as an unbounded schema guarantee.

Gate:

- [ ] every focused milestone commit passes its relevant checks and the full
  committed series passes the cross-layer gate before deployment

Commit sequence:

- [x] Commit validator tests, implementation, and required validator docs as
  one independently validated milestone.
- [x] Commit Functions cursor/schedule tests, implementation, and required
  Functions docs as a separate independently validated milestone.
- [x] Commit logging/monitoring configuration and operational docs as a
  separate independently validated milestone.
- [x] Confirm each commit excludes unrelated pre-existing worktree changes.

---

## Phase 7 — Deploy in the safe order

Authorization gate:

- [ ] Obtain explicit user authorization before changing production Functions,
  Cloud Run, Cloud Tasks, Scheduler, Firestore canary data, logging, monitoring,
  or billing-alert configuration.
- [ ] If authorization is not granted, stop after the committed local
  implementation and provide exact deployment commands and verification steps.

### Validator first

- [ ] Build and push an immutable validator image.
- [ ] Deploy materialized-revision/no-op behavior with minimum instances `0`,
  maximum instances `10`, concurrency `1`, 1 CPU, and 512 MiB memory.
- [ ] Verify readiness and liveness.
- [ ] Reconcile one empty board twice; verify the second pass writes nothing.
- [ ] Reconcile one populated board twice; verify the second pass writes
  nothing.
- [ ] Exercise a ghost-availability change; verify the second leaderboard pass
  writes the new view.
- [ ] Record image digest, revision, UTC timestamps, and focused evidence.

### Functions second

- [ ] Deploy the hourly schedule and default batch `4`.
- [ ] Verify the live Scheduler expression is hourly.
- [ ] Verify the deployed effective batch is `4`.
- [ ] Verify the query uses one lookahead document and the lookahead is never
  enqueued in the current invocation.
- [ ] Verify one invocation queries no more than five documents and selects and
  enqueues no more than four boards.
- [ ] Verify conditional cursor advancement, exact-multiple wrapping, and the
  next hourly page.
- [ ] Confirm all Functions still have minimum instances `0`.
- [ ] Record source hash, revisions, UTC timestamps, and focused evidence.

### Logging last

- [ ] Set projection queue operation-log sampling to `0.1`.
- [ ] Verify retry/error logs and alert delivery remain observable.
- [ ] Confirm both queues are running and empty after canary completion.

Rollback gate:

- [ ] Restore the prior cadence/batch only if the repair or convergence SLO
  fails; do not disable immediate projection or retry ownership

---

## Phase 8 — Prove early-release behavior in production

Normal path:

- [ ] Submit an authorized disposable ranked run.
- [ ] Verify accepted validation enqueues one run-session projection task.
- [ ] Verify leaderboard and ghost state converge without waiting for the
  scheduled sweep.
- [ ] Verify duplicate delivery is idempotent.
- [ ] Delete or disposition canary data through supported cleanup/account
  workflows.

Recovery path:

- [ ] Run an authorized missed-event or suppressed-dispatch drill without
  weakening production auth or validation.
- [ ] Verify the hourly sweep selects the affected board.
- [ ] Verify the board converges within 24 hours.
- [ ] Verify the cursor continues to later boards after recovery.

Idle observation:

- [ ] Observe one complete cursor cycle.
- [ ] Observe a representative 24-hour no-player window.
- [ ] Confirm no more than 96 scheduled `/tasks/project` requests during a
  healthy 24-hour window without delivery retries or authorized manual repair.
- [ ] Confirm projection-related Firestore reads remain below 1,000 for the
  recorded release corpus.
- [ ] Record projection reads per reconciled board and per full cursor cycle.
- [ ] If reads exceed the target, identify whether ghost-manifest pagination is
  responsible and open a focused active-manifest query/index or retention
  change before accepting the idle envelope.
- [ ] Confirm unchanged materialization writes are zero after initial
  convergence.
- [ ] Confirm queue retries and oldest-task age remain healthy.
- [ ] Confirm all minimum-instance values remain zero.
- [ ] Review the billing report by service and SKU.
- [ ] Explain any no-player cost above the expected Scheduler baseline.

Gate:

- [ ] normal and repair paths satisfy correctness while the idle envelope meets
  the strategy targets

---

## Phase 9 — Close and archive

- [ ] Record final commits, deployed revisions, configuration, metrics, costs,
  and rollback state in a rollout note beside these documents.
- [ ] Check every completion criterion in the strategy.
- [ ] Resolve or explicitly disposition every unchecked item.
- [ ] Move this folder to
  `docs/building/archived/projectionCostOptimization/`.
- [ ] Update active links after the move.
- [ ] Commit the closure evidence separately from implementation commits.

## Final acceptance checklist

- [ ] Immediate accepted-run projection remains prompt and client-independent.
- [ ] Settlement remains independent of optional projection.
- [ ] A missed projection delivery repairs within 24 hours.
- [ ] Each healthy scheduled invocation is bounded to four enqueued boards by
  default; retry duplicates are idempotent and separately observable.
- [ ] The retained-board count is below the release limit or has an approved
  scaling adjustment.
- [ ] Empty and unchanged boards produce no materialization writes.
- [ ] Changed ranking and ghost availability produce exactly the required
  writes.
- [ ] Cursor replay, task retry, and duplicate delivery remain idempotent.
- [ ] Account deletion fences and replay-generation evidence remain enforced.
- [ ] Projection requests, Firestore operations, and logs meet the idle target.
- [ ] Functions and Cloud Run minimum instances remain zero.
- [ ] The actual baseline bill is reviewed and understood.
- [ ] Documentation and operational runbooks match deployed behavior.
