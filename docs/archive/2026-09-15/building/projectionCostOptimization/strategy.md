# Early-Release Projection Cost Optimization Strategy

Status: proposed and ready for implementation.

Companion checklist:
[implementation-checklist.md](implementation-checklist.md)

## Decision

Keep Firebase and Google Cloud as the early-release backend, including the
event-driven projection path, Cloud Tasks retries, and scheduled recovery.
Replace the current full-board reconciliation every 15 minutes with a bounded
hourly repair sweep, and make unchanged leaderboard materialization a true
no-op.

```text
accepted ranked run
  -> Firestore accepted-run event
  -> idempotent Cloud Task
  -> immediate leaderboard/ghost projection

hourly recovery sweep
  -> next four boards from durable cursor
  -> leaderboard -> ghost -> leaderboard convergence
  -> no writes when materialized content is unchanged
```

This keeps the release reliability model while removing background work that
currently scales with every retained board four times per hour.

## Production baseline

A read-only production inspection on September 1, 2026 found:

| Resource | Observed state |
| --- | ---: |
| Deployed second-generation Functions | 26 |
| Functions with minimum instances | 0 |
| `replay-validator` minimum instances | 0 |
| Enabled Cloud Scheduler jobs | 9 |
| Reconciliation cadence | every 15 minutes |
| Boards scanned per reconciliation | 54 |
| Validator `/tasks/project` requests in 24 hours | 5,128 |
| Expected steady projection tasks per full day | 5,184 |
| Validator projection request time in 24 hours | 1,497.89 seconds |
| Firestore reads in 24 hours | 27,216 |
| Firestore writes in 24 hours | 11,511 |
| Replay bucket data | 331.80 KiB |
| Artifact Registry replay repository | 130.367 MB |

Every observed validator request was a successful `/tasks/project` request.
Recent scheduler logs showed `scannedCount: 54` and `enqueuedCount: 54` on
every 15-minute invocation. The idle workload is therefore caused by the
projection reconciliation policy, not by minimum instances.

At the current board count:

```text
54 boards * 4 cycles/hour * 24 hours = 5,184 projection tasks/day
```

Cloud Tasks and compute remain within current free allowances, but the sweep
uses more than half of the daily Firestore free read and write quotas before
player traffic begins. It also grows linearly as weekly and monthly boards are
retained.

The nine Scheduler jobs create the expected fixed idle bill. Cloud Scheduler
currently includes three jobs per billing account and charges for additional
jobs, including paused jobs. Preserving isolated repair ownership is worth the
approximately USD 0.60 monthly project baseline when the billing account's
three free jobs are available to this project.

## Goals

- Keep accepted ranked runs projected promptly without client involvement.
- Preserve independent retries for optional leaderboard and ghost work.
- Repair a missed event, exhausted task, or partial projection within 24 hours
  during the early-release board population.
- Bound scheduled projection work per invocation rather than per total board
  count.
- Stop rewriting unchanged Top-10 views and player-best eligibility fields.
- Keep Cloud Run and Functions at zero minimum instances.
- Preserve account deletion fencing, replay-generation evidence, ghost
  promotion rules, ranking order, and idempotency.
- Keep the zero-player bill predictable and close to the Scheduler baseline.

## Non-goals

- Removing Firebase, Firestore, Cloud Tasks, Cloud Run, or Play Games.
- Combining unrelated repair jobs merely to eliminate the Scheduler baseline.
- Changing score calculation, board identity, ranking order, reward
  settlement, replay validation, or client-visible protocol payloads.
- Removing full historical-board recovery coverage.
- Introducing a second projection implementation in Functions.
- Relying on a development-only pause that would be unsafe at release.

## Projection delivery model

### Immediate path remains authoritative for normal operation

`runProjectionOnAccepted` continues to react to a durable accepted
`validated_runs/{runSessionId}` record. It enqueues an idempotently named task
whose payload contains only the run-session id. The validator continues to:

1. project a better player result;
2. rebuild the board view;
3. converge ghost artifacts;
4. rebuild the view after ghost availability changes.

The scheduled sweep is a recovery mechanism, not the normal projection path.
Settlement remains independent and must never wait for projection.

### Bounded repair sweep

The early-release defaults are:

- schedule: every 60 minutes;
- enqueue batch size: 4 boards;
- query size: 5 boards, using the fifth document only as end-of-cycle
  lookahead;
- one cursor page per invocation;
- task concurrency: no higher than the existing queue limit of 5;
- task key bucket: one hour, aligned with the scheduler cadence.

The current 54-board population completes a full recovery cycle in 14
invocations, or approximately 14 hours. Four boards per hour supports a
24-hour full-cycle SLO through 96 retained boards.

Each invocation queries up to `batchSize + 1` documents and enqueues only the
first `batchSize`. When the lookahead document exists, the cursor advances to
the fourth, last-enqueued document. When it does not exist, the cursor wraps
to `null` in the same invocation. This prevents an exact multiple of four from
consuming an additional empty hour: 96 boards complete in 24 invocations and
the first page is eligible again on the next hourly invocation.

The cursor advances only after every task in the selected page is durably
enqueued. Its update uses an optimistic Firestore precondition or transaction
that proves the maintenance document still contains the cursor observed at
the start of the invocation. An overlapping or delayed invocation may enqueue
an idempotent duplicate, but it must not overwrite newer cursor progress. A
failed enqueue leaves the page replayable. Exact task names make replaying the
same page in the same hourly bucket harmless; a retry in a later bucket may
create duplicate work, which the convergent worker must tolerate.

The implementation must expose the batch as a bounded deployment setting, but
the checked-in default remains the release authority. An absent or malformed
environment value must resolve to `4`, not the old batch of `64`.

### Board-count release guard

The rollout records the retained-board count and alerts operators when it
reaches 80. Before the count exceeds 96, choose one of:

- archive finalized boards that no longer require ghost or deletion repair;
- increase the bounded page size using measured Firestore and validator cost;
- add a due/dirty-board index while retaining a low-frequency historical
  audit.

Silently allowing the repair SLO to grow beyond 24 hours is not acceptable.

## No-op materialization contract

The current Top-10 writer changes `updatedAtMs` and commits the view on every
reconciliation, even when ranking content is identical. It also rewrites
`ghostEligible` for current Top-10 players without first proving that the
desired value changed.

Add a stable materialized-view revision derived from the exact ordered Top-10
payload persisted for consumers. The canonical revision input includes a
fixed `materializationSchemaVersion` and excludes every top-level and
entry-level timestamp. For the current schema it binds:

- board id;
- entry id and uid;
- run-session id;
- rank and sort key;
- score, distance, and duration fields exposed by the view;
- character and display-name projection;
- ghost eligibility and availability;
- the replay reference, exact source generation, and digest fields persisted
  in each Top-10 entry.

Canonical encoding and SHA-256 follow the existing `run_protocol` digest
utilities. Hidden or independently stored ghost-manifest fields are not added
to the revision unless they also become part of the persisted Top-10 consumer
payload.

The stored authority consists of `materializationSchemaVersion` and
`materializedRevision`. The new writer never uses `sourceRevision` to decide
whether work may be skipped and stops emitting it. A legacy view without the
current version and revision is rewritten once, removes the inert
`sourceRevision` field, and then follows the new no-op path. This is a one-way
migration, not a parallel legacy authority.

For every refresh attempt:

1. load the previous Top-10 view;
2. compute the desired ordered entries and materialized revision;
3. update `ghostEligible` only when the actual player-best field differs from
   the desired value, using the already-listed player-best document for
   retained/current members and a conditional read/write for outgoing members;
4. skip the Top-10 commit when the materialized revision is unchanged;
5. preserve optimistic concurrency when a write is required.

A skipped write must not refresh `updatedAtMs`. That timestamp represents a
materialized-content change, not a health check.

The scheduled worker keeps its leaderboard-before-ghost-after ordering. The
first pass provides the ghost publisher with current Top-10 truth; the second
pass records any ghost-availability change. No-op detection makes both passes
cheap when nothing changed.

## Failure and recovery invariants

- Eventarc, Cloud Tasks, and the scheduled sweep remain at-least-once delivery
  mechanisms.
- Task names remain deterministic within a reconciliation cycle.
- Cursor state advances only after the complete page is enqueued and only when
  its observed cursor precondition still holds.
- Exact-multiple final pages wrap without a separate empty invocation.
- A stale overlapping invocation cannot move the cursor backward.
- A task retry cannot change ranking or ghost outcome after convergence.
- A partial first leaderboard pass remains repairable by the same task retry.
- Missing or legacy revision metadata causes a safe rewrite, not a skip.
- Conflicting view writes retain the existing bounded retry behavior.
- Account deletion fencing remains present on every user-owned projection
  write.
- Empty boards participate in the bounded audit and converge to one stable
  empty materialized view without recurring writes.
- Closed boards remain auditable until a separately reviewed archival policy
  is implemented.

## Observability and cost controls

Retain validator and scheduled-Function error/retry telemetry at full fidelity,
along with native queue backlog/attempt and Cloud Run error metrics. Reduce the
projection queue's Cloud Tasks operation-log sampling from `1.0` to `0.1` after
the new flow is verified. Queue sampling is not assumed to be success-only, so
alerts must not rely on an individual Cloud Tasks operation log surviving the
sample.

The reconciliation result must report:

- queried board-document count, including lookahead;
- selected board count, excluding lookahead;
- successfully enqueued board count;
- completed-page state;
- next cursor;
- whether cursor advancement was committed or rejected as stale;
- scheduler cadence and effective batch size;
- exact retained-board count from one aggregate query per invocation;
- completed full cursor-cycle duration when the final page commits.

The checked-in warning policy matches retained-board values at or above 80,
leaving capacity to choose an archival or scaling action before the default
page reaches its 96-board repair limit.

The validator must distinguish:

- changed materialization;
- unchanged materialization;
- ghost-only change;
- retryable failure;
- optimistic conflict exhaustion.

Release monitoring records daily:

- `/tasks/project` request count and request time;
- Firestore reads, writes, and deletes;
- queue retries and oldest-task age;
- retained-board count;
- full cursor-cycle duration;
- Cloud Run minimum-instance configuration;
- billed cost grouped by service and SKU when billing export is available.

A Cloud Billing budget alert remains required, but it is an alert rather than
a hard spending cap.

Official pricing references checked on September 1, 2026:

- [Cloud Scheduler pricing](https://cloud.google.com/scheduler/pricing)
- [Cloud Tasks pricing](https://cloud.google.com/tasks/pricing)
- [Cloud Run pricing](https://cloud.google.com/run/pricing)
- [Cloud Logging pricing](https://cloud.google.com/logging/pricing)
- [Firestore pricing](https://firebase.google.com/docs/firestore/pricing)
- [Artifact Registry pricing](https://cloud.google.com/artifact-registry/pricing)
- [Cloud Storage pricing](https://cloud.google.com/storage/pricing)
- [Firebase plans and pricing](https://firebase.google.com/pricing)

## Expected early-release envelope

At the currently observed 54-board and ghost-manifest population, with four
boards enqueued per successful hourly invocation:

| Metric | Current | Target steady state |
| --- | ---: | ---: |
| Projection tasks/day | 5,184 | at most 96 in a healthy no-retry window |
| Projection tasks/month | about 155,520 | at most 2,880 in a healthy 30-day window |
| Projection Firestore reads/day | about 27,000 | target below 1,000 for the observed corpus |
| Unchanged Top-10 writes | two passes per board task | zero |
| Full-board recovery cycle | 15 minutes | about 14 hours |
| Missed-event repair SLO | 15 minutes | within 24 hours |
| Minimum instances | 0 | 0 |

The healthy-path task estimate is an upper bound for scheduled invocations,
not retries or authorized manual repair. A 54-board cursor cycle ends after 14
hourly pages and restarts. No-op materialization should make steady-state
writes approach zero after the first post-deployment pass.

The read target is empirical rather than a schema-level guarantee. The current
worker lists all ghost-manifest pages for a board, so per-task reads can grow as
manifests accumulate even when task count stays bounded. Rollout therefore
records reads per reconciled board and per complete cursor cycle. The target of
fewer than 1,000 idle projection reads per day applies to the current observed
corpus; exceeding it triggers investigation and, if manifest growth is the
cause, a separately tested active-manifest query/index or retention change.

## Rollout order

1. Capture a fresh 24-hour baseline and retained-board count.
2. Implement and validate the validator materialized-revision/no-op behavior.
3. Commit the independently validated validator milestone without unrelated
   worktree changes.
4. Implement, validate, and commit the bounded Functions cursor milestone.
5. Implement, validate, and commit logging/operations changes separately.
6. Run the full cross-layer local validation gate.
7. Stop for explicit production-deployment authorization.
8. Deploy the validator materialized-revision/no-op behavior while the old
   scheduler cadence is still active.
9. Prove changed and unchanged board behavior with focused canaries.
10. Deploy the hourly schedule, batch `4`, lookahead query, cursor precondition,
    and hourly task-key bucket.
11. Verify the live Scheduler job, Functions environment, queue, and Cloud Run
   minimum-instance settings.
12. Reduce projection queue operation-log sampling to `0.1`.
13. Observe one complete cursor cycle and then a full 24-hour idle window.
14. Run an authorized missed-event recovery drill and confirm repair within the
   SLO.

Deploying no-op materialization first immediately reduces writes and makes the
old high-frequency sweep a short-lived stress verification of the skip path.

## Rollback

- Restore the previous schedule and batch only if the recovery SLO fails.
- Restore queue log sampling to `1.0` when diagnosing a delivery incident.
- Treat a missing, malformed, or wrong-version materialized revision as stale
  so rolling back and forward cannot suppress required writes.
- Do not disable immediate event projection, task retries, settlement, or
  account-deletion fencing during rollback.
- Do not delete cursor state; older and newer sweep revisions must tolerate it.

Rollback may increase cost, but it must not introduce a second projection
authority or weaken convergence.

## Documentation impact

Implementation updates are required in:

- `docs/tdd/replay_validator_worker.md` for convergence ordering, no-op
  revision, and recovery SLO;
- `docs/tdd/firebase_cloud_functions_overview.md` for scheduler cadence and
  bounded cursor behavior;
- `docs/tdd/ghost_run_flow.md` for ghost-aware materialized revision and audit
  behavior;
- Functions and replay-validator operational documentation for deployment,
  monitoring, and rollback;
- the relevant `AGENTS.md` files if backend ownership or validation guidance
  changes.

No GDD change is required because player-facing ranking, ghost availability,
and score behavior do not change.

## Completion criteria

The strategy is complete only when:

- an accepted ranked run projects through the immediate path without waiting
  for the sweep;
- a deliberately missed immediate delivery converges within 24 hours;
- unchanged and empty boards produce no materialization writes;
- the current board population generates no more than 96 scheduled projection
  tasks in a representative healthy 24-hour window without delivery retries or
  authorized manual repair;
- projection-related Firestore reads remain below 1,000 per idle day for the
  recorded release corpus, reads per board/cycle are recorded, and
  steady-state writes remain near zero;
- all Functions and `replay-validator` services still report zero minimum
  instances;
- queue retries, cursor replay, ghost promotion/demotion, account deletion,
  and optimistic conflicts pass focused tests;
- the actual no-player bill is reviewed by service and SKU and any amount
  above the Scheduler baseline has an explicit explanation;
- rollout and rollback evidence is recorded before this plan is archived.
