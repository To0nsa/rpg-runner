# Hall of Honour implementation

Status: completed locally on 2026-10-30; not deployed.

The owner authorized implementation with safe defaults, no historical credit,
the southern courtyard building in their map reference, and a qualifying
minimum of **10 metres OR 10 seconds**. They requested reuse of stats/Library
foundations and an extensible design. This closes the implementation checklist;
future balance/design work remains possible without treating the old proposal
as committed scope.

Current behavior: [GDD](../../../gdd/12_achievements.md).
Architecture: [TDD](../../../tdd/achievements.md).
Local evidence: [verification](../../../verification/achievements-2026-10-30.md).
The [earlier 24-achievement proposal](../gdd/12_achievements.md) remains an idea backlog.

## Completed acceptance

- [x] First Steps, Marathoner, Road Warrior, Still Standing and Slayer.
- [x] Gold defaults of 25 / 75 / 150 per achievement, with conservative
  starting thresholds recorded in the GDD.
- [x] Natural, verified Practice/Competitive/Weekly runs qualify at 10 m OR
  10 s; quits, rejected/pending and Developer Practice runs do not count.
- [x] Separate counters start empty; no historical stats are credited.
- [x] Reuse verified player-progression settlement and Library defeat evidence.
- [x] Server confirmation timestamps, immutable completion dates and explicit
  day-month-name-year UTC display.
- [x] Hall of Honour map label and building marker at the owner's chosen site.
- [x] Collapsed rows show only the next unreached target; expansion shows the
  complete tier history, rewards, dates and claim states.
- [x] One claim per achievement or Claim all; only earned/unclaimed actions
  appear, including the final tier until its reward is claimed.
- [x] Revisioned, authenticated, idempotent atomic wallet updates with durable
  per-tier receipts; no separate inbox delivery or optimistic wallet grant.
- [x] Account/deletion/disposal fencing and safe stale-revision retry.
- [x] Shared Library progress meter, number formatting, menu controls, map
  labels, gold display and attention marker; Library animation stays intact.
- [x] Catalog/evaluator/persistence/presentation boundaries and explicit
  migration guidance for new achievements, thresholds, metrics and rewards.
- [x] Functions builds, emulator checks, Dart analysis, targeted Flutter
  regression checks and rendered compact/enlarged-text UI review.
- [x] Current GDD/TDD/indexes updated; completed plan archived.

## Remaining future work

Deployment and physical-device acceptance were not authorized/performed.
Thresholds and economy defaults need play data before claiming a measured pace.
Cosmetics, titles, mastery and build exploration remain future ideas. Weekly
prestige still needs the archived percentile proposal reconciled with the
Top-10-at-rollover proposals; this implementation adds no such award.

The unrelated reward-latency documentation, dev diagnostics evidence and root
AGENTS edits present during implementation were preserved outside task commits.
