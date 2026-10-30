# Achievement settlement and claims

Implemented on 2026-10-30. Dev backend/web are deployed; Android build 4 passed
inspection and awaits installation/device acceptance. See the
[release evidence](../verification/achievements-dev-2026-10-30.md).
Player-facing rules and tuning live in the [Hall of Honour GDD](../gdd/12_achievements.md).

## Ownership and reuse

`functions/src/ownership/achievement_catalog.ts` owns stable IDs, metric bindings,
total/best aggregation, thresholds, gold amounts and the qualifying minimum.
`achievements.ts` owns decoding, settlement evaluation and gold claims. These
operate on canonical ownership, not Core state or an independent inventory.

Core and the replay worker already produce distance, duration, natural end reason
and enemy defeat evidence in `ValidatedRun`; their protocol does not change.
The evaluator consumes that verified evidence in the existing terminal settlement
transaction alongside [player progression](player_progression.md) and
[Library discoveries](codex.md). `readRunEnemyDefeats` is shared with discoveries,
so achievement kills retain the same identity validation and kill attribution.
Achievement counters are separate because their eligibility and start date differ
from historical lifetime stats. No historical counter is copied or replayed.

## Persistence

The canonical ownership document's `progression.achievements` contains:

```json
{
  "schemaVersion": 1,
  "entries": [
    {
      "id": "firstSteps",
      "value": 1,
      "tiers": [
        {"threshold": 1, "goldAmount": 25, "achievedAtMs": 1793404740000, "claimedAtMs": null},
        {"threshold": 10, "goldAmount": 75, "achievedAtMs": null, "claimedAtMs": null},
        {"threshold": 50, "goldAmount": 150, "achievedAtMs": null, "claimedAtMs": null}
      ]
    }
  ]
}
```

The example abbreviates the entries: schema 1 persists all five catalog entries
in catalog order, with three tiers each. Missing achievement data initializes all
five at zero; malformed present data fails closed instead of discarding claim
receipts. Counts and additions must be nonnegative JSON-safe integers; dates
must also fit Dart's epoch-millisecond range. Thresholds increase, achieved tiers
must match sufficient progress and cannot skip earlier tiers, and a claim date
cannot precede or exist without achievement confirmation.

`achievedAtMs` is the backend settlement confirmation time (UTC epoch milliseconds),
captured outside transaction retries and written atomically. It is not the client
clock, upload time or menu-open time. Multiple tiers crossed by one run receive
the same confirmation time; later settlement and claims preserve it. `goldAmount`
is snapshotted on achievement. Claims use that stored amount. Tier receipts have
no TTL; account deletion removes them with canonical ownership. No collection,
index, rules exception, cleanup job or extra per-run ledger is introduced.

Schema 1 deliberately fixes its catalog IDs, order and thresholds. Additions or
threshold changes require an explicit versioned migration preserving every earned
amount/date/claim receipt. Do not mutate the registry and reset incompatible
history. Add a presentation entry in Dart for a new ID; thresholds/rewards still
come from the server. New metrics belong in the evaluator's typed metric mapping;
new gameplay facts require coordinated changes to the replay evidence producer
and reader. New reward types should extend authoritative grant policy rather than
allow arbitrary client payloads or duplicate wallet logic.

## Settlement

`settleAcceptedRunSession` calls the evaluator after verified player progression
and discovery evaluation. Existing session, ticket, identity, mode, board, score,
deletion and reward-grant checks remain authoritative. Qualification requires
distance >= 10 OR duration >= 10, and one of `fellBehindCamera`, `fellIntoGap`,
`playerDied`, `bossEncounterFailed`. `gaveUp` is excluded. All five metrics use
that gate. Ordinary verified Practice, Competitive and Weekly share this path;
Developer Practice has no server session and cannot enter it.

The evaluator increments totals or takes the best value and records newly reached
tiers. It never credits achievement gold. An achievement change participates in
the same single canonical revision increment as other settlement effects.
Terminal session state prevents repeated or concurrent deliveries from counting
again. Malformed evidence or overflow aborts all settlement writes, including
ordinary run gold. Legacy accepted results missing the necessary evidence retain
their old reward behavior and receive no achievement credit. Previously terminal
runs remain terminal and are not backfilled.

## Claim command

`loadoutOwnershipExecuteCommand` accepts the existing revisioned command envelope with
`type: "claimAchievements"` and exactly `payload: {"achievementId": "slayer"}`,
or `{"achievementId": null}` for all achievements. The client cannot provide a
gold amount, completion time or claim time. Unknown IDs are invalid commands.
One ID claims every earned/unclaimed tier of that achievement; null claims all.

The existing authenticated UID match, deletion barrier, quota, expected revision,
command ID and payload hash apply. The command atomically updates spendable gold,
per-tier claim dates, revision and idempotency result. A duplicate command returns
its existing result; a fresh stale command is rejected. A new valid command after
all rewards have been claimed is an accepted no-op (normal command revision
advance), so retrying after command receipt expiry still cannot pay twice.
Claim timestamps are server-owned and never earlier than completion timestamps.
These rewards are direct ownership claims, not Messages gifts or run reward grants.

## Client and presentation

`AchievementProgress` decodes detached, immutable history in `ProgressionState`.
It computes next-unreached tier and claimable amounts for presentation only. A
missing field from an older backend renders unavailable, never invented progress.
`ClaimAchievementsCommand` and `FirebaseLoadoutOwnershipApi` use the existing
ownership transport. Widgets access only `AppState`.

The achievements controller flushes pending ownership edits before refresh/claim,
serializes claim taps, and applies canonical responses without optimistic gold.
A stale revision is retried once with the returned canonical revision and a new
command ID. Older responses cannot regress the current canonical revision.
Account generations, UID checks, disposal and accepted deletion fence late writes.
Refreshes coalesce; selection projection is reconciled through the existing outbox.

`/meta/town/hall-of-honour` uses existing menu layout, buttons, gold display and
theme tokens. `AchievementPresentation` holds labels, icons, units and UTC date
formatting. Rows have account-scoped expansion state. `ProgressMeter` and
`formatCount` were extracted from Library; its existing `UiProgressAnimator`,
unlock timing and `LibraryProgressTracker` remain in the Library owner.
The shared `AttentionMarker` indicates available gold on the Town callout.
The building anchor is normalized `(0.395, 0.708)` on `assets/Théodonis.jpg`;
the artwork is unchanged. Long shared map labels wrap in narrow viewports.

## Compatibility and verification

The backend reader/claim implementation must be deployed before the new client
expects claims. No new replay fields or Core compatibility version are required
by this feature itself. Release preparation must still account for any other
changes in the selected candidate. The dev rollout used the coordinated
release workflow with unchanged Core and replay-wire sources and the existing
worker image; backend settlement changes still require coordinated cutover.

The TypeScript producer test compares real evaluator/claim output with
`functions/test/fixtures/achievement_progress.json`; Dart decoding and UI tests
consume the same fixture. Backend tests cover qualification, no backfill, atomic
settlement, stable dates, malformed state, overflow, concurrent claims, idempotency,
stale revisions, forged payloads, UID mismatch and deletion. Flutter tests cover
canonical-only gold, retries, late refresh/account/deletion responses, Developer
Practice, final-tier claims, expansion and compact/enlarged-text map navigation.
