# Gold Grant Verification Implementation Checklist

Date: March 17, 2026  
Status: Ready for implementation

This checklist turns [docs/building/goldGrantVerification/plan.md](docs/building/goldGrantVerification/plan.md) into an execution sequence.

## Definition of done

- provisional reward is created at replay finalize time
- provisional reward is visible in Game Over UI but not spendable
- canonical `progression.gold` stays verified-only
- validator settles reward to `validated_settled` or `revocation_visible`
- reward projection drives UI-facing reward payloads
- store and other gold sinks use verified spendable gold only
- Game Over `Collect` is local-only and deterministic under polling
- cleanup, migration, and tests cover the new lifecycle

## Phase 0 - Prep and alignment

- [ ] Re-read [docs/building/goldGrantVerification/plan.md](docs/building/goldGrantVerification/plan.md) and confirm state names/contract fields before editing code.
- [ ] Cross-check hybrid write assumptions in [docs/building/ownershipHybridWrite/plan.md](docs/building/ownershipHybridWrite/plan.md).
- [ ] Confirm no other active work depends on legacy `reward_grants` state names.
- [ ] Decide whether `services/replay_validator/lib/src/reward_grant_writer.dart` is renamed or repurposed as a settlement writer.

## Phase 1 - Backend schema and lifecycle constants

### Reward lifecycle constants

- [ ] Update lifecycle/state constants in [functions/src/ownership/reward_grants.ts](functions/src/ownership/reward_grants.ts):
	- [ ] add `provisional_created`
	- [ ] add `provisional_visible`
	- [ ] add `validated_settled`
	- [ ] add `revocation_visible`
	- [ ] keep `revoked_final`
- [ ] Remove or migrate legacy assumptions around `pending_apply` / `applied` in backend reads.
- [ ] Keep backward-compatible read support during migration window.

### Reward grant schema support

- [ ] Update reward grant read/write helpers in [functions/src/ownership/reward_grants.ts](functions/src/ownership/reward_grants.ts) to support:
	- [ ] `runSessionId`
	- [ ] `uid`
	- [ ] `mode`
	- [ ] `boardId` / `boardKey` as applicable
	- [ ] `goldAmount`
	- [ ] `lifecycleState`
	- [ ] timestamps (`createdAtMs`, `updatedAtMs`, `validatedAtMs`, `revokedAtMs` as needed)
	- [ ] diagnostics (`settlementReason`, `lastTransitionBy` as needed)

## Phase 2 - Finalize path creates provisional reward

### Finalize upload flow

- [ ] Update [functions/src/runs/submission_store.ts](functions/src/runs/submission_store.ts) finalize path to create or upsert a provisional reward grant after replay finalize preconditions pass.
- [ ] Make creation idempotent by `runSessionId` document key.
- [ ] Ensure duplicate finalize calls do not create duplicate reward state or duplicate visible earned gold.
- [ ] Ensure reward grant `uid` matches the run session owner.

### Validation of finalize behavior

- [ ] Verify finalize response still returns submission status successfully when reward grant already exists.
- [ ] Verify finalize does not mutate canonical `progression.gold`.

## Phase 3 - Reward projection module

### Create projection responsibility

- [ ] Add a single reward projection module in `functions/src/runs/` or another clearly owned backend location.
- [ ] Projection input sources:
	- [ ] `run_session`
	- [ ] `reward_grant`
	- [ ] `validated_run`
- [ ] Projection output fields:
	- [ ] `status`
	- [ ] `provisionalGold`
	- [ ] `effectiveGoldDelta`
	- [ ] `spendableGoldDelta`
	- [ ] `grantId`
	- [ ] `updatedAtMs`
	- [ ] `message`

### Wire projection into status endpoints

- [ ] Update [functions/src/runs/submission_store.ts](functions/src/runs/submission_store.ts) status loading to use the projection module.
- [ ] Ensure `runSessionFinalizeUpload` uses the same projection path as `runSessionLoadStatus`.
- [ ] Keep legacy fallback derivation only when reward grant is absent during migration.
- [ ] Once reward grant exists, never derive reward payload from fallback paths.

## Phase 4 - Verified-only canonical gold enforcement

### Ownership reward reconciliation

- [ ] Refactor [functions/src/ownership/reward_grants.ts](functions/src/ownership/reward_grants.ts) so provisional states do not mutate `progression.gold`.
- [ ] Apply spendable gold only on `validated_settled`.
- [ ] Ensure revoked-before-verified flows do not require spendable gold rollback.
- [ ] Preserve bounded id tracking as needed for idempotent settlement.

### Store and economy guards

- [ ] Audit current gold sinks starting with:
	- [ ] [functions/src/ownership/store_state.ts](functions/src/ownership/store_state.ts)
	- [ ] [functions/src/ownership/apply_command.ts](functions/src/ownership/apply_command.ts)
- [ ] Confirm `purchaseStoreOffer` uses verified-only `progression.gold`.
- [ ] Confirm `refreshStore` uses verified-only `progression.gold`.
- [ ] Confirm no gold sink reads provisional reward display state.
- [ ] Document or patch any other backend command that consumes gold.

## Phase 5 - Validator settlement refactor

### Validator responsibilities

- [ ] Update [services/replay_validator/lib/src/validator_worker.dart](services/replay_validator/lib/src/validator_worker.dart) to settle reward lifecycle instead of creating initial reward grants.
- [ ] On success:
	- [ ] persist validated run
	- [ ] transition reward to `validated_settled`
- [ ] On revocable failure:
	- [ ] persist rejection state as appropriate
	- [ ] transition reward to `revocation_visible`
- [ ] On terminal `internal_error` retry exhaustion:
	- [ ] start grace-window handling
	- [ ] transition to `revocation_visible` after grace-window expiry unless incident mode is active
- [ ] If incident mode is active:
	- [ ] pause auto-revoke transition
	- [ ] keep reward frozen provisional until operator decision
- [ ] Keep terminal duplicate settlement idempotent.

### Revocation terminalization owner

- [ ] Choose and implement the component responsible for `revocation_visible -> revoked_final`.
- [ ] Preferred default: terminalize in backend reward lifecycle handling, not in client UI.
- [ ] Ensure terminalization is idempotent and independent of whether Game Over remains open.

### Reward grant writer cleanup

- [ ] Refactor or replace [services/replay_validator/lib/src/reward_grant_writer.dart](services/replay_validator/lib/src/reward_grant_writer.dart).
- [ ] Remove initial reward creation behavior from validator side.
- [ ] Rename if needed to better reflect settlement-only responsibility.

## Phase 6 - Client contract and state updates

### Run submission models

- [ ] Update shared submission status contract in [packages/run_protocol/lib/submission_status.dart](packages/run_protocol/lib/submission_status.dart) to carry reward payload fields.
- [ ] Extend [lib/ui/state/run_submission_status.dart](lib/ui/state/run_submission_status.dart) with reward payload fields.
- [ ] Parse new reward payload in [lib/ui/state/firebase_run_session_api.dart](lib/ui/state/firebase_run_session_api.dart).
- [ ] Keep tolerant parsing for migration window.

### App state behavior

- [ ] Ensure [lib/ui/state/app_state.dart](lib/ui/state/app_state.dart) does not award replay-run gold directly.
- [ ] Preserve canonical ownership refresh behavior so verified spendable gold converges globally.
- [ ] Keep reward display and spendability as separate client concepts.

## Phase 7 - Game Over UI implementation

### Reward row design

- [ ] Refactor [lib/ui/hud/gameover/game_over_overlay.dart](lib/ui/hud/gameover/game_over_overlay.dart) to use a simple reward row instead of verification-heavy copy.
- [ ] Use [lib/ui/components/gold_display.dart](lib/ui/components/gold_display.dart) for actual gold display.
- [ ] Render `Gold earned: <earned> + <actual gold>`.

### Collect interaction

- [ ] Add local-only collect interaction.
- [ ] Animate earned amount into actual gold display.
- [ ] Ensure collect does not mutate backend or canonical `progression.gold`.
- [ ] Ensure collect animation remains deterministic under polling updates.
- [ ] Ensure stale polling does not re-inflate collected visual reward.

### Cross-screen consistency

- [ ] Verify hub/town/profile continue showing verified-only gold.
- [ ] Ensure only reward-context UI shows provisional reward separately.

## Phase 8 - Cleanup and retention updates

- [ ] Update [functions/src/runs/cleanup.ts](functions/src/runs/cleanup.ts) for new lifecycle states.
- [ ] Preserve non-terminal states:
	- [ ] `provisional_created`
	- [ ] `provisional_visible`
	- [ ] `revocation_visible`
- [ ] Treat only terminal settled states as deletion-eligible:
	- [ ] `validated_settled`
	- [ ] `revoked_final`
- [ ] Keep legacy compatibility for `applied` during migration only.

## Phase 9 - Migration and rollout support

### Migration

- [ ] Add backfill logic or scripted migration for legacy `reward_grants` states.
- [ ] Map:
	- [ ] `pending_apply` -> `provisional_created`
	- [ ] `applied` + validated session -> `validated_settled`
	- [ ] `applied` + rejected/expired/cancelled session -> `revocation_visible`
- [ ] Do not perform historical balance correction unless a concrete migration issue is identified.

### Flags

- [ ] Add independent rollout controls for:
	- [ ] provisional reward creation
	- [ ] validator settlement writes
	- [ ] Game Over reward row / collect animation
	- [ ] legacy status fallback derivation
- [ ] Ensure rollback does not reintroduce spendable provisional gold semantics.

## Phase 10 - Tests

### Reward lifecycle tests

- [ ] Add/extend backend tests for finalize idempotency.
- [ ] Add/extend backend tests for validator success/failure settlement transitions.
- [ ] Add/extend backend tests for forbidden transitions and duplicate terminal events.
- [ ] Add/extend backend tests for `revocation_visible -> revoked_final` ownership and idempotency.

### Spendability tests

- [ ] Add backend tests proving provisional states do not mutate `progression.gold`.
- [ ] Add backend tests proving verified settlement applies spendable gold exactly once.
- [ ] Add backend tests proving purchase/refresh fail when only provisional gold would make them affordable.

### Reward projection tests

- [ ] Add backend tests for projection payload from:
	- [ ] no reward
	- [ ] provisional reward
	- [ ] final reward
	- [ ] revoked reward
	- [ ] fallback path during migration
	- [ ] malformed partial data
	- [ ] shared `run_protocol` serialization/parsing compatibility

### UI tests

- [ ] Add widget tests for Game Over reward row in all reward states.
- [ ] Add widget tests for collect animation behavior under polling transitions.
- [ ] Add tests ensuring hub/town/profile remain verified-only while Game Over shows provisional reward.

### Migration and cleanup tests

- [ ] Add tests for cleanup retention behavior with new lifecycle states.
- [ ] Add tests for legacy state backfill correctness.

### Internal error policy tests

- [ ] Add backend tests for grace-window behavior after terminal `internal_error`.
- [ ] Add backend tests for incident-mode pause of auto-revoke.
- [ ] Add backend tests proving no premature `revocation_visible` transition before grace-window expiry.

## Phase 11 - Validation and handoff

### Backend validation

- [ ] Run the relevant backend build.
- [ ] Run the relevant backend tests.
- [ ] Verify no callable contract drift between backend and client.

### Flutter/client validation

- [ ] Run targeted Flutter/widget tests for Game Over and state parsing.
- [ ] Run relevant app state tests.
- [ ] Manually verify end-to-end UX if practical:
	- [ ] finish run
	- [ ] see provisional reward
	- [ ] press collect
	- [ ] confirm town/profile/hub still show verified-only gold
	- [ ] confirm later verification success/revoke converges correctly

## Final acceptance checklist

- [ ] Provisional reward is created exactly once per run session.
- [ ] Provisional reward is visible in Game Over without exposing backend verification as a UX step.
- [ ] Provisional reward is never spendable.
- [ ] Canonical `progression.gold` remains verified-only.
- [ ] Verified settlement updates spendable gold exactly once.
- [ ] Revoked flows do not require negative spendable gold rollback.
- [ ] Reward projection is centralized and not duplicated across codepaths.
- [ ] Cleanup, migration, and rollout flags support safe deployment.
