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
- cleanup and tests cover the new lifecycle

## Phase 0 - Prep and alignment

- [x] Re-read [docs/building/goldGrantVerification/plan.md](docs/building/goldGrantVerification/plan.md) and confirm state names/contract fields before editing code.
- [x] Cross-check hybrid write assumptions in [docs/building/ownershipHybridWrite/plan.md](docs/building/ownershipHybridWrite/plan.md).
- [x] Confirm no other active work depends on retired `reward_grants` state names.
- [x] Decide whether `services/replay_validator/lib/src/reward_settlement_writer.dart` is renamed or repurposed as a settlement writer.

## Phase 1 - Backend schema and lifecycle constants

### Reward lifecycle constants

- [x] Update lifecycle/state constants in [functions/src/ownership/reward_grants.ts](functions/src/ownership/reward_grants.ts):
	- [x] add `provisional_created`
	- [x] add `provisional_visible`
	- [x] add `validated_settled`
	- [x] add `revocation_visible`
	- [x] keep `revoked_final`
- [x] Remove retired pre-lifecycle state assumptions in backend reads.
	- [x] Keep runtime logic lifecycle-only.

### Reward grant schema support

- [x] Update reward grant read/write helpers in [functions/src/ownership/reward_grants.ts](functions/src/ownership/reward_grants.ts) to support:
	- [x] `runSessionId`
	- [x] `uid`
	- [x] `mode`
	- [x] `boardId` / `boardKey` as applicable
	- [x] `goldAmount`
	- [x] `lifecycleState`
	- [x] timestamps (`createdAtMs`, `updatedAtMs`, `validatedAtMs`, `revokedAtMs` as needed)
	- [x] diagnostics (`settlementReason`, `lastTransitionBy` as needed)

## Phase 2 - Finalize path creates provisional reward

### Finalize upload flow

- [x] Update [functions/src/runs/submission_store.ts](functions/src/runs/submission_store.ts) finalize path to create or upsert a provisional reward grant after replay finalize preconditions pass.
- [x] Make creation idempotent by `runSessionId` document key.
- [x] Ensure duplicate finalize calls do not create duplicate reward state or duplicate visible earned gold.
- [x] Ensure reward grant `uid` matches the run session owner.

### Validation of finalize behavior

- [x] Verify finalize response still returns submission status successfully when reward grant already exists.
- [x] Verify finalize does not mutate canonical `progression.gold`.

## Phase 3 - Reward projection module

### Create projection responsibility

- [x] Add a single reward projection module in `functions/src/runs/` or another clearly owned backend location.
- [ ] Projection input sources:
	- [x] `run_session`
	- [x] `reward_grant`
	- [x] `validated_run`
- [ ] Projection output fields:
	- [x] `status`
	- [x] `provisionalGold`
	- [x] `effectiveGoldDelta`
	- [x] `spendableGoldDelta`
	- [x] `grantId`
	- [x] `updatedAtMs`
	- [x] `message`

### Wire projection into status endpoints

- [x] Update [functions/src/runs/submission_store.ts](functions/src/runs/submission_store.ts) status loading to use the projection module.
- [x] Ensure `runSessionFinalizeUpload` uses the same projection path as `runSessionLoadStatus`.
- [x] Keep projection lifecycle-driven from `reward_grants` and canonical run state only.
- [x] Remove non-lifecycle fallback derivation from active projection behavior.

## Phase 4 - Verified-only canonical gold enforcement

### Ownership reward reconciliation

- [x] Refactor [functions/src/ownership/reward_grants.ts](functions/src/ownership/reward_grants.ts) so provisional states do not mutate `progression.gold`.
- [x] Apply spendable gold only on `validated_settled`.
- [x] Ensure revoked-before-verified flows do not require spendable gold rollback.
- [x] Preserve bounded id tracking as needed for idempotent settlement.

### Store and economy guards

- [x] Audit current gold sinks starting with:
	- [x] [functions/src/ownership/store_state.ts](functions/src/ownership/store_state.ts)
	- [x] [functions/src/ownership/apply_command.ts](functions/src/ownership/apply_command.ts)
- [x] Confirm `purchaseStoreOffer` uses verified-only `progression.gold`.
- [x] Confirm `refreshStore` uses verified-only `progression.gold`.
- [x] Confirm no gold sink reads provisional reward display state.
- [x] Document or patch any other backend command that consumes gold.

## Phase 5 - Validator settlement refactor

### Validator responsibilities

- [x] Update [services/replay_validator/lib/src/validator_worker.dart](services/replay_validator/lib/src/validator_worker.dart) to settle reward lifecycle instead of creating initial reward grants.
- [x] On success:
	- [x] persist validated run
	- [x] transition reward to `validated_settled`
- [x] On revocable failure:
	- [x] persist rejection state as appropriate
	- [x] transition reward to `revocation_visible`
- [x] On terminal `internal_error` retry exhaustion:
	- [x] start grace-window handling
	- [x] transition to `revocation_visible` after grace-window expiry unless incident mode is active
- [x] If incident mode is active:
	- [x] pause auto-revoke transition
	- [x] keep reward frozen provisional until operator decision
- [x] Keep terminal duplicate settlement idempotent.

### Revocation terminalization owner

- [x] Choose and implement the component responsible for `revocation_visible -> revoked_final`.
- [x] Preferred default: terminalize in backend reward lifecycle handling, not in client UI.
- [x] Ensure terminalization is idempotent and independent of whether Game Over remains open.

### Reward grant writer cleanup

- [x] Refactor or replace [services/replay_validator/lib/src/reward_settlement_writer.dart](services/replay_validator/lib/src/reward_settlement_writer.dart).
- [x] Remove initial reward creation behavior from validator side.
- [x] Rename if needed to better reflect settlement-only responsibility.

## Phase 6 - Client contract and state updates

### Run submission models

- [x] Update shared submission status contract in [packages/run_protocol/lib/submission_status.dart](packages/run_protocol/lib/submission_status.dart) to carry reward payload fields.
- [x] Extend [lib/ui/state/run_submission_status.dart](lib/ui/state/run_submission_status.dart) with reward payload fields.
- [x] Parse new reward payload in [lib/ui/state/firebase_run_session_api.dart](lib/ui/state/firebase_run_session_api.dart).
- [x] Keep tolerant parsing for optional reward payload fields.

### App state behavior

- [x] Ensure [lib/ui/state/app_state.dart](lib/ui/state/app_state.dart) does not award replay-run gold directly.
- [x] Preserve canonical ownership refresh behavior so verified spendable gold converges globally.
- [x] Keep reward display and spendability as separate client concepts.

## Phase 7 - Game Over UI implementation

### Reward row design

- [x] Refactor [lib/ui/hud/gameover/game_over_overlay.dart](lib/ui/hud/gameover/game_over_overlay.dart) to use a simple reward row instead of verification-heavy copy.
- [x] Use [lib/ui/components/gold_display.dart](lib/ui/components/gold_display.dart) for actual gold display.
- [x] Render `Gold earned: <earned> + <actual gold>`.

### Collect interaction

- [x] Add local-only collect interaction.
- [x] Animate earned amount into actual gold display.
- [x] Ensure collect does not mutate backend or canonical `progression.gold`.
- [x] Ensure collect animation remains deterministic under polling updates.
- [x] Ensure stale polling does not re-inflate collected visual reward.

### Cross-screen consistency

- [x] Verify hub/town/profile continue showing verified-only gold.
- [x] Ensure only reward-context UI shows provisional reward separately.

## Phase 8 - Cleanup and retention updates

- [x] Update [functions/src/runs/cleanup.ts](functions/src/runs/cleanup.ts) for new lifecycle states.
- [x] Preserve non-terminal states:
	- [x] `provisional_created`
	- [x] `provisional_visible`
	- [x] `revocation_visible`
- [x] Treat only terminal settled states as deletion-eligible:
	- [x] `validated_settled`
	- [x] `revoked_final`
- [x] Keep cleanup lifecycle-only with no retired state compatibility.

## Phase 9 - Rollout support

### Flags

- [x] Add independent rollout controls for:
	- [x] provisional reward creation
	- [x] validator settlement writes
	- [x] Game Over reward row / collect animation
- [x] Ensure rollback does not reintroduce spendable provisional gold semantics.

## Phase 10 - Tests

### Reward lifecycle tests

- [x] Add/extend backend tests for finalize idempotency.
- [x] Add/extend backend tests for validator success/failure settlement transitions.
- [x] Add/extend backend tests for forbidden transitions and duplicate terminal events.
- [x] Add/extend backend tests for `revocation_visible -> revoked_final` ownership and idempotency.

### Spendability tests

- [x] Add backend tests proving provisional states do not mutate `progression.gold`.
- [x] Add backend tests proving verified settlement applies spendable gold exactly once.
- [x] Add backend tests proving purchase/refresh fail when only provisional gold would make them affordable.

### Reward grant lifecycle tests (additional)

- [x] Add backend tests for `revocation_visible -> revoked_final` ownership and idempotency.

### Reward projection tests

- [x] Add backend tests for projection payload from:
	- [x] no reward
	- [x] provisional reward
	- [x] final reward
	- [x] revoked reward
	- [x] malformed partial data
	- [x] shared `run_protocol` serialization/parsing compatibility

### UI tests

- [x] Add widget tests for Game Over reward row in all reward states.
- [x] Add widget tests for collect animation behavior under polling transitions.
- [x] Add tests ensuring hub/town/profile remain verified-only while Game Over shows provisional reward.

### Cleanup tests

- [x] Add tests for cleanup retention behavior with new lifecycle states.

### Internal error policy tests

- [x] Add backend tests for grace-window behavior after terminal `internal_error`.
- [x] Add backend tests for incident-mode pause of auto-revoke.
- [x] Add backend tests proving no premature `revocation_visible` transition before grace-window expiry.

## Phase 11 - Validation and handoff

### Backend validation

- [x] Run the relevant backend build.
- [x] Run the relevant backend tests.
- [x] Verify no callable contract drift between backend and client.

### Flutter/client validation

- [x] Run targeted Flutter/widget tests for Game Over and state parsing.
- [x] Run relevant app state tests.
- [ ] Manually verify end-to-end UX if practical:
	- [ ] finish run
	- [ ] see provisional reward
	- [ ] press collect
	- [ ] confirm town/profile/hub still show verified-only gold
	- [ ] confirm later verification success/revoke converges correctly

## Final acceptance checklist

- [x] Provisional reward is created exactly once per run session.
- [x] Provisional reward is visible in Game Over without exposing backend verification as a UX step.
- [x] Provisional reward is never spendable.
- [x] Canonical `progression.gold` remains verified-only.
- [x] Verified settlement updates spendable gold exactly once.
- [x] Revoked flows do not require negative spendable gold rollback.
- [x] Reward projection is centralized and not duplicated across codepaths.
- [x] Cleanup and rollout flags support safe deployment.
