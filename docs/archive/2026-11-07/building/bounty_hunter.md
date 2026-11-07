# Willow implementation — completed locally

User-authorized scope: the playable bounty hunter Willow with 25 abilities, three
pre-run weapon choices, cooldown-only unlimited bombs, and character selection
before the builder. Local implementation and validation; no deployment.

## Acceptance and milestones

- [x] Core character, independent tuning/poses, weapon and projectile catalogs,
  six populated loadout slots, character-specific equipment eligibility.
- [x] Four melee actions (Quick Cut, Twin Cut, Threefold Cut, Lunge Slash),
  four bombs (Blast, Shrapnel, Fire, Concussion), five shots (Snap, Quick,
  Piercing, Scatter, Charged), Dash/Roll/Slide, Jump/Double Jump, and seven
  fieldcraft actions (Hunter's Focus, Mark Quarry, Forced March, Field Dressing,
  Antidote, Second Wind, Prepare Charges).
- [x] Persistent falling/landed bombs, deterministic fuse and blast, terrain
  occlusion, once-per-target damage, no friendly fire, no resource cost;
  scatter damage budget and attacker-specific mark lifecycle.
- [x] Weapon-specific animation sets, ground/air/run shots, action and reaction
  timing, live and ghost rendering, previews, projectile and bomb effects.
- [x] Selection -> builder routing, independent remembered loadouts, usable
  Gear/Skills/Training Field, Supplies/Fieldcraft presentation for the hunter.
- [x] Ownership, store/gifts, run tickets and validator accept the same new
  identities without weakening validation; local compatibility recorded.
- [x] Focused behavior tests, deterministic/replay checks, consumer checks,
  broader required suites and local visual verification; final diff review.
- [x] Implemented GDD/TDD and verification evidence updated; archive this plan.

## Decisions

Pistol, crossbow and shotgun are equipped before a run. Shot abilities determine
the pattern; the equipped ranged weapon determines its payload and visuals.
Supplies reuse the regenerating mana resource. Bombs consume no Supplies and
have unlimited uses limited by cooldown. Basic fuse/cooldown start at 1s/4s.
Movement abilities do not grant automatic invulnerability. All gameplay clocks,
damage and collision remain in Core. Existing command encoding is retained.

## Completion and limits

Asset import is committed in `b6e0cf26`. Core, app, backend, worker and Admin
implementation and local validation are complete. The user named the character
Willow and requested empty illustrations for content lacking dedicated art.
The game is not live; new old-profile migration and older-client selection
fallback code were removed. Fresh defaults include Willow directly.

See the [implemented roster](../../../gdd/combat/abilities/willow.md),
[technical contract](../../../tdd/willow.md) and
[verification evidence](../../../verification/willow-2026-11-07.md).
Deployment/device acceptance and extended balance playtesting were not part of
this local task. Existing unrelated edits to `.gitignore`, `AGENTS.md` and
`README.md` are preserved.
