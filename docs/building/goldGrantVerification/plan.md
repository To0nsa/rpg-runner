# Gold Grant Verification Plan (Refactor-First)

Date: March 17, 2026  
Status: Design-ready, implementation pending

## Summary

We want end-of-run gold to feel instant without giving up backend authority.

Target outcome:

- replay finalize creates a provisional reward immediately
- validator settles that reward to final accepted or final revoked
- ownership reconciliation remains the only place that mutates canonical gold
- Game Over presents reward collection as a smooth local UI interaction, not as a visible verification pipeline
- provisional gold may be visible before verification, but it is not spendable until verified

This plan intentionally favors refactoring existing flows over layering UI-only fixes or temporary shortcuts.

## Why this needs a refactor

Today reward flow is split across three domains:

- submission lifecycle (`run_sessions` / `validated_runs`)
- reward creation (validator)
- reward application (ownership canonical reconciliation)

That works for delayed validated rewards, but it is not a clean base for instant-feeling gold. The fix is to make reward lifecycle explicit and server-owned end-to-end.

## Existing code touchpoints

Backend:

- `functions/src/runs/submission_store.ts` (finalize/load status)
- `functions/src/ownership/reward_grants.ts` (grant reconciliation)
- `functions/src/ownership/canonical_store.ts` (canonical load + reconcile)
- `functions/src/ownership/store_state.ts` (store affordability / spend rules)
- `functions/src/ownership/apply_command.ts` (purchase / refresh entrypoints)

Validator service:

- `services/replay_validator/lib/src/validator_worker.dart`
- `services/replay_validator/lib/src/reward_grant_writer.dart`

Client/UI:

- `lib/ui/state/run_submission_status.dart`
- `lib/ui/state/firebase_run_session_api.dart`
- `lib/ui/state/app_state.dart`
- `lib/ui/runner_game_widget.dart`
- `lib/ui/hud/gameover/game_over_overlay.dart`
- `lib/ui/components/gold_display.dart`

## Locked principles

1. Backend remains source of truth for reward state and effective gold.
2. Every transition is idempotent by `runSessionId`.
3. No direct client-side economy mutation for replay-validated runs.
4. Ownership reconciliation remains the only canonical gold mutation path.
5. No weakening of auth checks, revision checks, or deterministic validation.
6. Only verified gold is spendable; provisional gold is displayable but locked.
7. `progression.gold` remains the verified spendable balance; provisional reward value is modeled separately and never merged into canonical spendable gold.

## Reward lifecycle

Introduce explicit reward lifecycle in `reward_grants`:

- `provisional_created`
- `provisional_visible`
- `validated_settled`
- `revocation_visible`
- `revoked_final`

### Transition table

| Current | Event | Next | Notes |
|---|---|---|---|
| none | finalize accepted | provisional_created | create grant idempotently |
| provisional_created | reward becomes visible to UI | provisional_visible | local/UI-facing settlement only; no spendable gold mutation |
| provisional_created/provisional_visible | validator accepted | validated_settled | verified spendable settlement |
| provisional_created/provisional_visible | validator rejected policy | revocation_visible | only for revocable terminal outcomes |
| revocation_visible | revocation presentation settles | revoked_final | one-time terminal revoked state |
| validated_settled/revoked_final | any duplicate event | unchanged | idempotent no-op |

Forbidden transitions (must no-op + metric):

- `validated_settled -> revocation_visible`
- `revoked_final -> validated_settled`

## Settlement policy

Reward revocation policy (explicit):

- `rejected` => revoke
- `expired` => revoke
- `cancelled` => revoke
- `internal_error` => **do not auto-revoke immediately**; keep provisional and schedule retry until max validator retries are exhausted by policy. Final forced revoke only when run session is terminal rejected/cancelled/expired.

Terminal `internal_error` policy (explicit):

- if a run remains terminal `internal_error` after retry policy is exhausted, reward becomes `revocation_pending_apply` automatically after a grace window
- if a run remains terminal `internal_error` after retry policy is exhausted, reward becomes `revocation_visible` automatically after a grace window
- grace window default: 24h (configurable)
- if incident mode is enabled, auto-revoke is paused and reward remains frozen provisional until operator decision

Rationale: avoid punishing users for transient validator infra failures.

## Spendability policy

This plan explicitly requires a distinction between:

- **displayed gold**: what the player sees in reward UI
- **spendable gold**: what backend store/economy commands may consume

Rule:

- provisional / unverified reward gold must never be spendable
- store purchases, refreshes, and any future gold sinks must validate against **verified spendable gold**, not against optimistic reward presentation

Implementation direction:

- keep spend checks on the backend only
- keep canonical `progression.gold` verified-only
- expose provisional reward separately for reward-context UI composition

Locked decision:

- this rollout uses the verified-only canonical model
- we do **not** allow `progression.gold` to temporarily include provisional reward value

Current code gap to close:

- current store purchase/refresh logic reads `progression.gold` directly, so this area must be refactored as part of the gold verification rollout

## Data and contract shape

### Firestore schema (target)

`reward_grants/{runSessionId}` fields:

- identity: `runSessionId`, `uid`, `mode`, `boardId?`, `boardKey?`
- amount: `goldAmount`
- lifecycle: `lifecycleState`
- timestamps: `createdAtMs`, `updatedAtMs`, `appliedAtMs?`, `validatedAtMs?`, `revokedAtMs?`
- reconciliation guards: `appliedProfileId?`, `appliedRevision?`, `revokedProfileId?`, `revokedRevision?`
- references: `validatedRunRef`
- diagnostics: `settlementReason?`, `lastTransitionBy?`

Ownership balance meaning:

- `progression.gold` = verified spendable gold only
- provisional reward amount lives outside canonical spendable balance and is projected through status/reward payloads for UI

Index/retention:

- keep existing retention cleanup compatibility
- ensure cleanup only deletes terminal settled grants (`validated_final` / `revoked_final`)

### Submission status contract updates

Extend run submission status payload returned by:

- `runSessionFinalizeUpload`
- `runSessionLoadStatus`

Add:

```text
reward:
	status: "none" | "provisional" | "final" | "revoked"
	provisionalGold: int
	effectiveGoldDelta: int
	spendableGoldDelta: int   // 0 until verified; verified settled amount once final
	grantId: string?      // runSessionId for now
	updatedAtMs: int
	message: string?
```

Compatibility:

- new fields are optional at first
- old clients ignore unknown fields
- new client treats missing `reward` as legacy fallback mode

### Reward projection component

Add one explicit reward projection responsibility on the backend:

- a single projection component/module converts `run_session` + `reward_grant` + `validated_run` into the UI-facing `reward` payload
- this projection is the only place that derives reward display state for `runSessionFinalizeUpload` and `runSessionLoadStatus`
- do not duplicate reward derivation rules across callable handlers, validator code, and client parsing logic

## Backend implementation plan

### Phase A - Finalize path owns provisional creation

Move initial grant creation responsibility from validator to finalize path:

- update `functions/src/runs/submission_store.ts` finalize flow to create/upsert provisional grant after replay finalize preconditions pass
- make operation idempotent by document id (`runSessionId`)

### Phase B - Ownership reconciliation supports both apply and revoke

Refactor `functions/src/ownership/reward_grants.ts`:

- keep `progression.gold` unchanged for `provisional_created` / `provisional_visible`
- apply `+goldAmount` only when reward becomes verified spendable (`validated_settled`)
- if reward is revoked before verification, no spendable balance rollback is required
- mark lifecycle transitions atomically in transaction
- preserve bounded tracking (`appliedRewardGrantIds`) and add bounded revoked tracking if needed
- preserve enough state to project provisional reward to UI without contaminating spendable balance

### Phase C - Validator settles state only

Refactor validator:

- `validator_worker.dart` updates lifecycle to `validated_settled` or `revocation_visible`
- remove grant creation responsibility from `reward_grant_writer.dart` (or convert to settlement writer)

### Phase D - Status API includes reward projection

Update `loadRunSessionSubmissionStatus` to include `reward` section from grant document + run state.

Projection precedence (strict):

1. use `reward_grants/{runSessionId}` lifecycle as primary source
2. if grant missing (migration/legacy only), derive temporary fallback from `run_sessions` + `validated_runs`
3. once grant exists, never override reward projection from fallback sources

Implementation note:

- this phase should introduce the single reward projection module/component described above so reward payload logic stays centralized

### Phase E - Economy spend guards use verified spendable gold

Refactor store/economy spending paths:

- update `functions/src/ownership/store_state.ts` purchase and refresh affordability checks
- keep `insufficientGold` based on canonical `progression.gold` only
- apply the same rule to any other gold sink added later in the repo

Future-proof rule:

- every gold sink in the backend must consume only canonical verified gold
- no command may consume provisional reward display value

## Client and UI plan

### App state

- keep `run submission` as authority for reward display
- do not call `awardRunGold` for replay-validated end-of-run flow
- continue canonical ownership refresh for eventual convergence of total gold
- treat reward display and spendability as separate concerns

Cross-screen balance rule:

- hub, town, profile, and any persistent economy screens show verified spendable `progression.gold`
- only reward-context UI may show provisional reward value separately
- shared/global gold UI must not silently include provisional reward in spendable totals

### Run submission models

- extend `RunSubmissionStatus` with reward fields
- parse in `firebase_run_session_api.dart`

### Game Over UI

Goal: the user should not feel backend verification as a separate economy step.

Replace the current reward panel with a simpler reward row built around the
existing `GoldDisplay` widget pattern:

- primary row copy: `Gold earned: <earned> + <actual gold>`
- render the `actual gold` portion using `GoldDisplay`
- keep `earned gold` as a separate transient visual amount until collect

Interaction model:

- when Game Over opens, show `gold earned` as a pending visual amount
- pressing `Collect` empties the pending earned amount into the actual gold display
- perform a small transfer animation from earned amount -> actual gold display
- after collect completes, the pending earned amount becomes `0` / hidden
- the collect animation is local-only and must resolve deterministically even if polling returns stale reward status updates during the animation

Important semantic rule:

- `Collect` is a presentation interaction only
- it must not trigger backend reward mutation
- backend reward state still comes from the server reward payload and ownership reconciliation
- it must not make unverified gold spendable
- it must not mutate canonical `progression.gold`

State mapping:

- `provisional` => row still looks like normal earned gold; no scary verification copy
- `final` => same row stays settled; optional subtle verified affordance is allowed, but no disruptive extra text
- `revoked` => animate earned amount back out or collapse it, then show a concise failure/removal message
- `none` => hide reward row

Copy rules:

- prefer economy-first copy over pipeline-first copy
- avoid exposing verification language unless something failed or reward was revoked
- all visible state still derives from server reward payload, not inferred from submission phase alone
- if another screen exposes spendable balance, it must not silently treat pending reward display as spendable value

Cross-screen consistency:

- leaving Game Over before verification completes must not change spendable balance elsewhere
- if verification later succeeds, verified gold appears through normal ownership refresh/sync
- if verification later fails, no negative-balance recovery path is needed because provisional reward was never spendable

## Coexistence and deprecation

`awardRunGold` command path in ownership remains temporarily for non-replay legacy/debug contexts only.

Exit criteria to deprecate:

1. all replay-validated runs use reward lifecycle payload
2. no production path invokes client `awardRunGold` on run end
3. migration window closes with zero parity regressions

## Migration plan

1. Add lifecycle fields + tolerant readers in backend and client.
2. Backfill legacy `reward_grants` states:
	 - `pending_apply` -> `provisional_created`
	 - `applied` + validated session -> `validated_settled`
	 - `applied` + rejected/expired/cancelled session -> `revocation_visible`
3. Lock the invariant that all newly written canonical state keeps `progression.gold` verified-only.
4. Existing balances are accepted as-is; this rollout does not include historical balance correction unless production data reveals a concrete migration bug.
5. Enable finalize provisional creation (flagged).
6. Enable validator settlement transitions.
7. Switch UI to reward payload as primary source.
8. Remove legacy fallback behavior after stable window.

9. Update cleanup behavior in `functions/src/runs/cleanup.ts` for lifecycle-aware retention:
	- preserve non-terminal lifecycle states (`provisional_created`, `provisional_visible`, `revocation_visible`)
	- only treat `validated_settled` and `revoked_final` as reward-terminal for deletion eligibility
	- keep legacy `applied` handling during migration window only

10. Verify ownership hybrid-write compatibility with `docs/building/ownershipHybridWrite/plan.md`:
	- provisional reward display does not require local ownership mutation
	- hybrid sync timing affects when verified gold appears globally, not whether provisional gold is spendable
	- canonical gold remains stable and verified-only across sync boundaries

## Safety rules

### Transaction and concurrency boundaries

Mandatory transaction zones:

- ownership reconcile apply/revoke + lifecycle transition
- any operation that reads lifecycle then writes transition on same grant

Allowed eventual consistency:

- status projection reads (`runSessionLoadStatus`)
- UI polling refresh

Conflict policy:

- on concurrent transition conflict, retry bounded times then emit structured error and metric

### Hard invariant checks

- exactly one canonical reward document per run session (`reward_grants/{runSessionId}`)
- `reward_grants.uid` must equal `run_sessions.uid` for the same `runSessionId`
- invariant violations must result in transition no-op, structured error logging, and `reward_grant_invariant_violation_total{type}` increment
- no backend gold sink may consume unsettled provisional reward value
- newly written canonical state must never fold provisional reward into `progression.gold`

## Observability and operations

### Metrics and alerts

Add metrics/counters:

- `reward_grant_transition_total{from,to}`
- `reward_grant_idempotent_noop_total{state,event}`
- `reward_grant_apply_total{result}`
- `reward_grant_revoke_total{result}`
- `reward_grant_invariant_violation_total{type}`

Alerts:

- invariant violations > 0 in 10m
- apply/revoke failure ratio > 1%
- grants stuck in pending states > threshold window

### Operator runbook (minimum)

For stuck grants (`provisional_created` / `provisional_visible` / `revocation_visible`):

1. inspect run session terminal state
2. inspect ownership profile revision and last reconcile timestamp
3. trigger safe reconcile read path (canonical load)
4. if still stuck, use admin repair script to reapply transition idempotently

No manual direct gold edits except explicit incident process.

## Testing matrix

### 1) Reward lifecycle tests

Backend unit/integration:

- finalize duplicate calls produce a single `reward_grants/{runSessionId}` record
- finalize idempotently reuses existing `provisional_created` reward state
- transition `provisional_created -> provisional_visible` is idempotent
- validator success settles `provisional_created` / `provisional_visible` to `validated_settled` exactly once
- validator rejection settles `provisional_created` / `provisional_visible` to `revocation_visible` exactly once
- `revocation_visible -> revoked_final` is idempotent
- replayed validator task remains a no-op after terminal reward state is reached
- forbidden transitions remain blocked/no-op with metric
- terminal duplicate events after `validated_settled` or `revoked_final` do not alter persisted state

### 2) Spendability and economy tests

Backend unit/integration:

- provisional states do not mutate `progression.gold`
- validated settlement applies spendable gold exactly once
- revoked path does not require spendable gold rollback when reward never became verified spendable
- purchase/refresh commands reject when only provisional reward would make the action affordable
- purchase/refresh commands succeed once reward is `validated_settled` and canonical verified gold is refreshed/applied
- every backend gold sink uses verified-only `progression.gold`
- no backend command can consume provisional reward display value

### 3) Reward projection tests

Backend unit/integration for the reward projection component/module:

- project from `run_session` + `reward_grant` + `validated_run` into the canonical UI-facing `reward` payload
- project `none` when no reward record exists and no fallback state should surface a reward
- project `provisional` from `provisional_created` / `provisional_visible`
- project `final` from `validated_settled`
- project `revoked` from `revocation_visible` / `revoked_final`
- use fallback derivation only when reward grant is missing during migration window
- stop using fallback once reward grant exists
- malformed or partially missing fields degrade safely without crashing callable responses
- `spendableGoldDelta` stays `0` until verified settlement

### 4) UI interaction and consistency tests

Client/UI tests:

- decode reward payload variants in `RunSubmissionStatus`
- Game Over reward row renders correctly for `none`, `provisional`, `final`, and `revoked`
- `Collect` animation locally empties pending earned amount into displayed gold row without mutating canonical balance
- collect animation remains deterministic under stale polling responses
- polling transition from provisional -> final updates UI without double-adding visual reward
- polling transition from provisional -> revoked collapses/removes reward row cleanly
- leaving Game Over before verification completes does not cause other screens to show spendable provisional gold
- hub/town/profile continue showing verified-only `progression.gold` while Game Over may show separate provisional reward value
- returning to reward-context UI after verification converges shows the correct settled state

### 5) Hybrid ownership sync tests

State/integration tests:

- stale canonical ownership state + fresh reward payload still preserves spendability rules
- delayed ownership sync does not make provisional reward spendable
- verified settlement appears in global balance only through normal ownership refresh/sync
- hybrid write-behind/outbox behavior remains consistent with verified-only canonical gold

### 6) Cleanup and retention tests

Backend unit/integration:

- `functions/src/runs/cleanup.ts` preserves non-terminal lifecycle states (`provisional_created`, `provisional_visible`, `revocation_visible`)
- cleanup deletes only reward-terminal states eligible by retention (`validated_settled`, `revoked_final`)
- legacy `applied` records remain compatible during migration window
- cleanup does not delete records still required for UI projection or pending settlement

### 7) Migration and backfill tests

Backend unit/integration:

- legacy `pending_apply` maps to `provisional_created`
- legacy `applied` + validated session maps to `validated_settled`
- legacy `applied` + rejected/expired/cancelled session maps to `revocation_visible`
- migrated records preserve verified-only canonical gold invariant for new writes
- fallback status derivation behaves correctly before and after reward grant backfill

### 8) Invariant and failure-path tests

Backend unit/integration:

- mismatched `reward_grants.uid` vs `run_sessions.uid` produces no-op + metric
- corrupt/malformed reward records do not break callable responses or reconciliation loops
- duplicate/corrupt transition attempts emit `reward_grant_invariant_violation_total{type}`
- terminal `internal_error` obeys grace-window behavior
- incident mode pauses auto-revoke as specified
- stuck reward states can be safely reprocessed by operator repair tooling without double settlement

### 9) End-to-end scenarios

- run end -> provisional shown in Game Over -> validator success -> final verified balance converges globally
- run end -> provisional shown in Game Over -> validator rejection -> reward removed/revoked cleanly
- app restart during pending verification -> status + balance reconverge correctly
- user visits hub/town/profile while reward is provisional -> sees only verified spendable gold
- user attempts store spend while reward is still provisional -> command is rejected correctly

## Rollout and rollback

Rollout gates:

1. backend fields + status payload (read-only)
2. client parsing + UI fallback
3. finalize provisional creation ON for internal users
4. validator settlement ON
5. deprecate client run-end `awardRunGold`

Rollback:

- disable finalize provisional creation flag
- keep status payload parsing intact
- validator continues without lifecycle settlement writes

## Acceptance criteria

- gold appears immediately at Game Over for successful finalize paths
- final validated runs keep gold with `final` reward status
- invalid terminal runs revoke exactly once with `revoked` status
- duplicate finalize/validate/reconcile events do not alter balance after first settle
- client no longer awards replay-run gold directly at run end
- provisional gold cannot be spent before verification
