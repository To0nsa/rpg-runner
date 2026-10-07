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
licenses remain unchanged. No production boss-placement changes were made.

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

The canonical release preparation still performs the complete client, Core,
shared-package, Functions and validator gates on a frozen commit. Its production
evidence will be recorded below after cutover. Device gameplay, authenticated
Play Games smoke and production replay acceptance must be distinguished from
local tests and infrastructure readiness.

## Production release

Preparation and cutover pending. The preflight Inspect succeeded against the
existing deployment; no production mutation has occurred at this checkpoint.
