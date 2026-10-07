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

The canonical release preparation still performs the complete client, Core,
shared-package, Functions and validator gates on a frozen commit. Its production
evidence will be recorded below after cutover. Device gameplay, authenticated
Play Games smoke and production replay acceptance must be distinguished from
local tests and infrastructure readiness.

## Production release

Preparation and cutover pending. The preflight Inspect succeeded against the
existing deployment; no production mutation has occurred at this checkpoint.
