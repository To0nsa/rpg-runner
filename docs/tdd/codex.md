# Codex and Town services

Implemented locally; production requires the coordinated Functions, validator
and client release. See [player rules](../gdd/codex.md).

## Authority and persistence

The account's canonical `ownership_profiles` progression contains:

```json
{
  "codex": {
    "schemaVersion": 1,
    "enemyKills": { "grojib": 10, "bringerOfDeath": 5 },
    "competitiveBestScores": { "forest": 10000, "field": 10000 }
  }
}
```

Keys are stable Core enum names, never ordinal positions. Counts are
non-negative JavaScript-safe integers. Missing Codex state on an old account
reads as empty; the first tracked settlement creates it. Progress is shared
across characters and retained across sessions, devices and board windows.
Existing account deletion removes it with canonical ownership.

The validator produces optional `ValidatedRun.codex` evidence:

```json
{
  "schemaVersion": 1,
  "levelId": "forest",
  "enemyKills": { "grojib": 3, "bringerOfDeath": 1 }
}
```

`CodexRunProgress` in `run_protocol` owns this immutable wire value. Version 1
allows at most 64 enemy identities, with ASCII identifiers of at most 64
characters. Direct constructors enforce bounds at runtime; decoders reject
malformed values with `FormatException`. Rejected results cannot carry Codex
evidence. Ranked evidence must match the validated board's level.

The replay worker maps the authoritative replayed `RunEndStats.enemyKillCounts`
to names and records the ticket's level. It does not trust client summaries
or write lifetime progression. Kill attribution, boss/summon classification and
combat rules stay in Core. Empty accepted runs carry an empty kill map, so
their competitive score still counts.

## Atomic settlement

`settleAcceptedRunSession` applies Codex evidence in the same Firestore
transaction as the reward grant, canonical revision and terminal `validated`
session state. `applyCodexProgress` requires accepted evidence and the same
level in both immutable ticket and session. Existing settlement checks bind
the identity, mode, board and score context.

- All accepted Practice, Competitive and Weekly runs add kills.
- Only Competitive takes the maximum of the prior level best and this run's
  validated score. Scores are never added and lower scores never replace bests.
- A terminal session returns `already_settled`; concurrent/retried deliveries
  cannot add kills again. No additional bounded run-ID ledger is used.
- Malformed evidence aborts the whole transaction, including gold and grant
  writes. Pending/rejected runs do not grant progress.
- The canonical revision advances once for the transaction, including a
  Codex-only change. Ownership commands preserve the progression subtree.
- Developer Practice has no remote session/submission and earns no progress.

Legacy accepted results without the optional evidence retain their original
reward behavior and add no Codex progress. Previously settled runs are not
backfilled. Deploy the backend reader before enabling the new worker writer,
using the existing coordinated release workflow. No replay digest, gameplay
compatibility or score calculation changes are introduced by Codex itself.

## Client and navigation

`ProgressionState.codex` decodes the canonical maps into detached, immutable
`CodexProgress` values. The existing final-reward receipt flow refreshes all
canonical progression before acknowledging completion, including zero-gold
rewards; Codex needs no independent mutation or refresh endpoint.

`CodexCatalog` holds presentation policy: ten kills for regular enemies,
five for Core-classified bosses and their nested summon sections, and 10,000
best Competitive points for each published Forest/Field entry. New authored/development levels do not appear
automatically. Enemy attack damage composition and resistance values come
from the current Core catalogs, including secondary damaging attacks sharing
the archetype's ability namespace. Lore/tactical prose remains UI content.

Routes:

- `/meta/town`: city map with city-service callouts, pan/zoom and reset.
- `/meta/town/store`: the existing store, preserving purchase/refresh behavior.
- `/meta/town/library`: Bestiary, Locations and opening Journal sections on a
  left-side icon rail.
- Entry routes are pushed within Library and recheck current account progress
  on rebuild, hiding combat/lore content again if the account is replaced.

Locked list rows expose names, idle portraits and requirements, with counts
inside a trailing progress bar. Status remains in accessibility semantics.
Entry details and lists scroll; the section rail uses the same `AppIconButton`
as the hub and retains each section’s scroll/filter state. Narrow viewports
use tooltip-labelled icons; wider views also show labels. Returning from Store
or Library returns to the map.

## Portraits and nested summons

`UiAssetLifecycle` owns at most one cropped static portrait for each enemy ID.
Loads are deduplicated and initiated by the portrait widget’s lifecycle, not
its `build` method. The loader samples the first catalog `previewAnimKey`
frame (including Derf’s caster idle), reuses the render-layer strip/composite
loader, trims transparent padding and releases the temporary sprite sheet.
Only the small rasterized portrait remains cached. No animation ticker runs.
Purge disposes portrait images and fences late loads by generation; failed
loads can retry and show an image placeholder without hiding navigation.

Bestiary excludes `isBossSummon` entries. `CodexCatalog.parentBoss` binds
Shoggoth Minion to Shoggoth and Void Tentacle to Voidcaller. Their complete
combat/lore sections appear only inside the unlocked parent page. Direct
construction with a summon ID resolves to the parent page and gate. Stored
summon kill totals remain compatible evidence but are not independent unlocks.
No backend migration or kill-credit change is needed.

## City map asset

`assets/Théodonis.jpg` is the supplied 4096 × 3072 city map, registered explicitly
in `pubspec.yaml`. It replaces the PDF regional extraction, which is no longer
bundled. `TownMap` uses the image’s 4:3 aspect ratio for both artwork and marker
geometry. Decode width is capped at 2048 pixels to bound display memory.

Service anchors use image coordinates: Store `(0.35, 0.49)` in the market
streets and Library `(0.47, 0.405)` at the northeastern courtyard complex.
Separate callout lines connect to those anchors and transform with the image.
These placements are navigation choices, not additional world-canon claims.
If loading fails, the service controls remain available over a city-name fallback.

## Verification

- Protocol tests: legacy omission, detached maps, invalid ranges/version,
  rejected evidence; compiled AOT constructor probe.
- Worker tests: replay-derived name/count evidence, including non-default
  30 Hz replays, plus existing rejection/settlement handoff coverage.
- Firestore emulator: concurrent duplicate settlement, mode and per-level
  separation, maxima, malformed-evidence rollback and pending/rejected gates.
- Flutter: canonical refresh, legacy state, exact unlock boundaries, locked
  detail visibility, account reset, tabs/filtering, map navigation, zoom and
  small viewport/large-text layout, plus existing store purchase regressions.

Local verification on 2026-10-16 passed: targeted Dart analysis, Functions
build and test compilation, 38 Firestore-emulator settlement/projection tests,
93 validator worker tests, 49 protocol tests, the compiled AOT probe, and 29
Flutter state/widget tests. Rendered Town and Library previews were reviewed
with the real fonts. Follow-up layout checks corrected duplicated top padding,
large-text store headers and minimum-zoom translation bounds. These are local
checks, not evidence of a production deployment or physical-device smoke test.

The Library cleanup adds checks for compact row geometry, left-side navigation,
removed summary/status text, boss-owned summon gates and all ten real idle
portrait loads (including cache reuse, disposal and late-load fencing). City
map navigation and zoom checks use the replacement JPEG. Targeted analysis
and all 15 focused Flutter tests passed. Rendered previews were reviewed at
normal and small viewport sizes, including enlarged text.
