# Mobility recasts

Core owns ability execution and follow-up eligibility. `MobilityRecastDef`
authors one additional burst using the same speed, duration and cost as the
first. It is restricted to instant, tap-driven mobility-slot abilities, with no
recovery and a shared cooldown longer than the burst plus follow-up window.
The ordinary Dash has no recast; Double Dash opts into a 30-authoring-tick window.
See [mobility design](../gdd/combat/abilities/eloise/mobility.md) for balance values.

## State and tick boundaries

`MovementStore` retains the armed ability identity, opening tick and exclusive
expiry tick. This state participates in sparse-set swap removal and entity
destruction. At first accepted commitment, activation spends the ordinary cost,
starts the mobility cooldown, and arms `[executeTick + activeTicks, expiry)`.
Expiry is the earlier of opening plus the scaled window and cooldown completion.
The latter prevents cooldown-reduction bonuses from carrying a follow-up into
another cooldown cycle. All authoring times scale from 60 Hz using the existing
ability timing conversion; distance comparisons are calibrated at production 60 Hz.

For a first press at tick 1 and an eight-tick burst, movement occurs on ticks
1â€“8, and a second press may commit on ticks 9â€“38 inclusive. Early presses are
rejected without buffering. The existing simulation order is unchanged:
activation runs before player movement, then mobility execution, gravity and
terrain integration. Activation therefore permits the final remaining movement
timer count of one only for a matching recast whose opening tick has arrived.
It cannot interrupt an in-progress burst or authorize another ability.

The second accepted commitment resolves direction and resources again, consumes
the follow-up, and leaves the shared cooldown unchanged. Failure to afford it
preserves the remaining window. A third activation follows ordinary cooldown
gating. Gear movement bonuses apply on execution tick as well as subsequent
movement ticks; status speed modifiers continue to resolve each tick.

Activation clears stale identity/expiry and checks stun and swimming. Status stun
application and water immersion also clear the follow-up immediately, so a
same-tick interruption cannot leave the HUD advertising it. Run end clears it;
entity destruction removes all movement state. Landing does not reset it.
Terrain collision, gravity suppression and combat preemption use the existing
mobility pipeline. There is no teleport, extra invulnerability or compensation
for blocked travel. Ordinary motion between/after bursts is outside their range.

## HUD and ownership

`PlayerHudSnapshot.mobilityRecastTicksLeft` reports usable remaining input ticks
starting at `snapshot.tick + 1`. It is zero during the first burst and after
expiry, interruption or run end. It does not imply resource affordability.
Cooldown arrays keep their actual values. The tap control uses the Core signal
to temporarily enable a follow-up during cooldown, shows `+1`, and exposes an
accessible follow-up label. Resource blocking and its feedback still apply.
No widget timer or renderer state decides whether a recast exists.

The ability is registered in the Core catalog and backend store pool; the usual
ownership and loadout authorization paths control purchase and equip. Starter
profiles retain ordinary Dash. The picker and tooltips use the catalog and
ownership state; Double Dash reuses the existing dash art.

## Replay and release

Both taps use the existing `DashPressedCommand` and replay pressed bit. Neither
command encoding nor ticket/loadout schema changes. Outcomes do change, including
ordinary Dash duration and first-tick gear scaling, so client, issuer and worker
source support moves together to gameplay compatibility `2026.10.21`. Older
compatibility is rejected by this worker rather than replayed under new rules.
The offline ranked navigation route plan is refreshed for the new tuple.

This is prepared source, not production verification. The existing coordinated
[release workflow](deployment_workflow.md) must drain old runs and switch the
matching client, issuer, worker, boards and navigation artifacts before normal
issuance resumes. Score and command encoding versions are unchanged.

## Validation

- Core recast tests exercise overlap, opening/expiry at 60 and 120 Hz, costs,
  cooldown persistence, direction changes, interruption and entity recycling.
- Full Core terrain tests measure active travel on ground and in air, account
  for coordinate quantization, and verify HUD boundaries and gear speed scaling.
- Widget tests cover follow-up visibility, activation during cooldown and
  resource failures. Picker and backend tests retain ownership gating.
- Worker replay tests compare decoded existing-format tap streams with direct
  Core execution, including early, expired and third-tap attempts.

Local validation on October 21, 2026 compiled the worker successfully, but its
strict 36,000-tick throughput fixture ended on Field at tick 226 before timing
completed. An isolated copy with the dash changes removed reproduced the same
failure. That fixture sends no dash inputs. This baseline failure is unresolved
and does not establish throughput or release readiness for this change.
