# Ancient God separation and visual audit

Date: October 7, 2026. Target gameplay compatibility: `2026.10.9`, retaining
`rules-v2`, `score-v4` and `ghost-v1`. The owner requested the audit, commits and
production deployment, and authorized cancellation of active runs if needed.

## Implemented ownership

Commit `0ab07746` separates Goddess, Shoggoth and Voidcaller attack decisions,
ability definitions, actor/projectile animation metadata and combat poses.
Minion and tentacle content is independently defined. Shared services handle
engagement, action commits, terrain-validated placement, utility timing and
summon cleanup. Global catalogs provide lookup; no shared utility selects a
concrete boss's attack. Boss state is per entity and lifecycle registered.
Bringer remains independent of the chunk that places it.

Nine pre/post-refactor traces matched exactly: three bosses at 30/60/90 Hz,
28 simulated seconds each, with per-tick health, arena phase, actor identity,
position and animation frames. This evidence applies to the ownership refactor,
before the intentional visual corrections below.

## Video and collision review

Reviewed the full [Ancient God animation video](https://www.youtube.com/watch?v=0rPsM1DjEuc)
using one-second frame samples and source-sheet frame inspection. Goddess is
shown at approximately 0–20 seconds, Shoggoth at 21–49 and Voidcaller at 50–75.
The displayed claw/orb/blob, sweep/spin/orb/minion and beam/tentacle/claw kits
match the selected mechanics. Damage, cadence, summon caps and lifetime are
gameplay defaults, not claims about rules demonstrated by the video.

The review found and corrected two issues:

- Voidcaller's diagonal middle and damage capsule sloped opposite to its
  endcaps. They now descend from the offset upper-right portal into the ground
  mark. World-anchored impact art and damage use the same fixed orientation.
- Shoggoth's spin omitted the visible rear crescents and underfit a front arc.
  Frames 4–7 now follow the visible sweep, retaining once-per-target damage.

These corrections intentionally change combat geometry within `2026.10.9`.
All actors/effects retain the same 1.5x art scale as Bringer. Source PNGs and
licenses remain unchanged. The owner subsequently requested three Forest chunks
before deployment. Dedicated easy sections now place Goddess, Shoggoth and
Voidcaller immediately after Bringer, before the existing enchanted forest.
Their terrain/scenery reuse the authored Bringer room. Generation adds exactly
three chunks (80 → 83). Before route repairs, comparison confirmed all 80 prior
generated terrain records were identical. The new seeded routes exposed two
existing obstructions: normal camp 002's anvil/crate spacing and hard grove
008's narrow irregular gap platform. The anvil moves 16 units left; a 96-unit
platform replaces the 32-unit foothold and rises 28 units. Enemy limits and
test tolerances are unchanged; exact incoming sequences remain regressions.

## Local evidence

- Core analysis and the affected render audit: no issues.
- Boss suite after separation: 122 passing tests, including 21 new isolation
  and stale-utility cases. Two instances of a boss keep separate cooldowns;
  running one boss system cannot commit another boss's action.
- Visual correction regressions: 27 passing damage checks at 30/60/90 Hz,
  including both spin facings and the visible/empty sides of the diagonal beam.
- Full new-boss arena scenarios after the initial geometry correction: 18 pass,
  including both characters' real-combat victories and summon cleanup.
- Render and entrance checks: nine pass; the corrected composed-beam/pose
  preview was rendered and visually reviewed again.
- Editor source round-trip and stale-source rejection: pass with separate files.
- Projectile/beam generators and asset manifest: current.
- Both characters clear the four authored Forest arenas continuously using
  normal resources and committed combat: four introductions, victories,
  blessings, summon cleanup and exit into the ordinary section.
- Production selector verifies consecutive unique boss rooms at seeds 7/42/2026;
  full Forest horizons are 114/105/116 chunks, with Field/New Level at 32.
  All 36 seeded pursuit cases pass. The combined 124-case arena/navigation/
  signature checks pass after updating the midpoint-gap control's continuation
  to normal grove 009, since the repaired hard grove 008 now supports its midpoint.
  The final control was rerun separately; no movement capability was widened.
- Release checks found stale blank-image fixture bounds and the previous 60%
  HUD expectation. Catalog-derived source bounds and the current 20% expectation
  correct them; all ten affected rendering/playtest/HUD cases pass.

The canonical release preparation passed on frozen commit `8b0062d4`:

| Gate | Passing tests |
| --- | ---: |
| Client unit/widget suite | 1,128 |
| Core | 1,127 |
| Functions, Firestore emulator | 212 |
| Replay worker | 203 |
| Shared protocol | 44 |
| Content pipeline | 98 |
| Terrain materials | 25 |

Analysis, compiled AOT protocol rejection, generated-content freshness and the
production web build passed. The fresh production dependency audit found no
known vulnerabilities. Functions checks/build reused the matching successful
component evidence from earlier in this same audit; other components ran on
the final frozen checkout. Device gameplay and authenticated production replay
acceptance remain separate from these local tests and infrastructure checks.

## Production release

Deployed October 7, 2026, via `tools/release/release.ps1` in coordinated scope.
The live tuple is `2026.10.9` / `rules-v2` / `score-v4` / `ghost-v1`; replay and
command formats remain 1.

- Frozen source: `8b0062d403acd180c9a7d2a04cab0425cfbd2498`.
- Source digest: `2c81850739548ad42d4064509482316704525a0bed99ea832965659745d772ee`.
- Cloud Build: `35eecbf7-c0ce-4acf-9a95-d1abf38573d8`, successful.
- Worker image: `europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:5840d990c3b400043cc55fde0a8623659cc2924fbff6480e9079f49fa8c4228b`.
- Worker revision: `replay-validator-00050-5dm`, healthy, serving 100% of traffic.
- Resumed issuer: `runsessioncreate-00047-vnm`, healthy, serving 100% of traffic;
  direct serving-revision inspection confirms the temporary pause gate is absent.
- Live [Hosting](https://rpg-runner-d7add.web.app) `main.dart.js` SHA-256:
  `9f422b2192d44d17055f46964c1eb671f97065292e3e722bfa3a49eb6421c18d`.
  Downloaded production bytes exactly match the frozen build.

The final container passed the strict 36,000-tick benchmark under one CPU and
512 MiB: Forest 1.554 seconds, Field 1.813 seconds, New Level 1.939 seconds, with
deterministic outcomes. This existing benchmark workload is not a full Forest
campaign or a device boss-combat performance claim; Forest's benchmark final
distance is 331.75 units. The authored boss sequence and complete route coverage
are established by the separate tests above.

| Stage | October 7 UTC |
| --- | --- |
| Preparation complete | 20:34:58 |
| Issuance paused | 20:40:22 |
| Authorized cancellations committed | 20:40:39 |
| Backend verified | 20:45:01 |
| Worker deployed | 20:46:59 |
| Hosting deployed | 20:47:24 |
| Issuance restored | 20:52:10 |
| Final inventory | 20:52:58 |
| Serving issuer verified | 20:54:45 |

The owner explicitly authorized cancellation when necessary. A fresh read-only
review identified two issued `2026.10.8` tickets and one abandoned upload whose
lease expired at 13:14:50 UTC. The upload had no Storage object, finalized replay,
provisional summary, validation result or reward grant. After verifying paused
issuance, a Firestore transaction rechecked identities, states, update times,
absent validation/reward evidence and the missing replay object, then marked
only those three sessions cancelled. Records and expired upload metadata remain;
profiles, validated runs, rewards and Storage objects were not altered.
The reviewed candidate-set SHA-256 is
`68dc7cc2e3f913cb4536274dbccff8e0ca0f5789df29808d0f17210617b184d8`.

The final inventory has zero active sessions, 196 accepted validated runs and
196 settled grants, with no stale or quarantined settlement. Both queues are
`RUNNING`; all six expected current/next boards exist. The canonical workflow
verified matching live artifacts, IAM/queue configuration and saved the verified
production baseline. The new version has no controlled post-cutover accepted
replay in this evidence window.

Evidence remains under the frozen checkout's
`.tmp/releases/rpg-runner-d7add/2c81850739548ad42d4064509482316704525a0bed99ea832965659745d772ee/`,
including release state, component logs/cache references, Cloud Build result,
live inventory, service/queue/scheduler snapshots and operator receipts.

### Remaining verification

The browser was checked before and after deployment. Both builds show
`App bootstrap (services) failed: Unsupported operation: _Namespace` and the
unsupported-services screen. This pre-existing browser initialization failure
blocks a signed-in gameplay smoke in the available browser. Linked Play Games
gameplay, new-version replay acceptance, once-only settlement, leaderboard/ghost
publication and live retired-version request rejection remain unverified end to
end. No native package was installed during this release. The release checklist
stays open for these checks; local tests and live infrastructure evidence do not
stand in for them.
