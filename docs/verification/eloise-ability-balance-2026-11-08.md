# Éloïse ability balance verification — 2026-11-08

## Source and scope

Local Windows working tree based on `d9049e98`, including preexisting Willow
items/art, ability icons, menu and projectile changes. Task edits were reviewed
against pre-task file backups to preserve overlapping work. This record covers
the accepted Éloïse review and local implementation, not a deployed release.

The design follows Lothringen's resource pressure and commitment/reward pillars.
The [current kit](../gdd/combat/abilities/eloise/eloise_abilities.md) contains all
21 abilities; the [completed checklist](../archive/2026-11-08/building/eloise_ability_balance.md)
records the scope. Existing mobility, Mana Infusion and Willow tuning are retained.

## Decisions and resulting behavior

Costs below are player units; times are seconds at base tuning before equipment.

| Ability | Before | Implemented | Purpose |
| --- | --- | --- | --- |
| Arcane Haste | +50%, 5s, 5s cooldown, 10 mana | +40%, 3s, 8s cooldown, 12 mana | A useful movement window with meaningful downtime |
| Focus | 5s, 7s cooldown, 12 mana | 4s, 8s cooldown, 12 mana | Preserve +25% power/+15% crit while reducing uptime |
| Arcane Ward | 5s, 7s cooldown, 12 mana | 3s, 9s cooldown, 14 mana | Require deliberate protection timing |
| Cleanse | 14 mana, 8s cooldown | 12 mana, 8s cooldown | Make reactive debuff removal competitive with prevention |
| Vital Surge | 35% max HP over 5s, 7s cooldown, 15 mana | 25% over 5s, 12s cooldown, 20 mana | Reduce sustained recovery pressure on encounter attrition |
| Second Wind | 35% max stamina over 5s, 7s cooldown, 15 mana | 25% over 5s, 10s cooldown, 18 mana | Preserve resource conversion with a stronger opportunity cost |
| Quick Shot | 10/2/12 execution ticks | 6/2/6 ticks | Deliver the fast aimed-shot role; damage/cost unchanged |
| Overcharge | Full charge at 10 ticks | Full charge at 24 ticks (0.4s); middle tier at 10 | Require commitment for its damage and two-target pierce |
| Cleave | Innate bleed on every release; full tier at 16 ticks | Innate bleed only at full charge, 20 ticks | Reward charging rather than immediate-release bleed |
| Aegis Riposte | Reward expired while guard remained held | Reward stays ready during its granting guard; one-second release window | Make the earned counterattack usable and visible |

Quick Shot's base execution is 14 ticks; the starter Strength Belt's 5% cooldown
penalty makes its repeat interval 15 ticks. Cleave deals 14.4/17.28/20.8 base damage
across its tiers; full charge adds the existing 3 damage/second bleed for 5s.
Equipment procs remain available on lower tiers. Full-charge innate bleed wins
existing first-source deduplication over Waspfang's chance-based bleed.

Utility tuning is local to Éloïse, leaving shared status profiles unchanged.
Ward still mitigates direct hits by 40% and temporarily suppresses DoT ticks;
Cleanse removes debuffs and can break stun. Focus and Sunlit Vow share an existing
non-stacking status; an equal-strength application extends it only when its new
duration exceeds the remaining duration. Mana Infusion remains 35% max mana over
5s, 7s cooldown and 15 stamina. Only one utility is equipped.

The displayed Bloodletter Slash name is now **Sword Slash**; its stable ownership
ID and asset path remain intact. Tooltips explain full-charge bleed, Overcharge
timing, shield exceptions and the absence of movement invulnerability. Starter
Spell List documentation now matches Haste/Focus and Acid/Holy Bolt ownership.

Riposte's HUD shows readiness during guard and a snapshot-driven countdown after
release. A later guard cannot renew the old reward, misses do not consume it,
and a landed melee hit consumes it once. Expiry, entity reuse and terminal-state
cleanup are covered. The [Core contract](../tdd/runner_core_simulation_contract.md#éloïse-balance-and-counterattack-window-20261181)
describes charge-tier proc inheritance, ordering and next-step snapshot timing.

## Local validation

`dart` denotes `C:/Users/Toonsa/flutter/bin/cache/dart-sdk/bin/dart.exe`.
Flutter tests used that Dart executable with the installed
`flutter_tools.snapshot`, `test --no-pub` and `--reporter expanded`.
All checks are local; remote worker dependencies and Admin delivery use mocks or
fixtures. No messages, live boards or tickets were changed.

| Directory | Command / scope | Result |
| --- | --- | --- |
| `packages/runner_core` | `dart test test/combat/eloise_balance_test.dart` | 18 passed: real charge commits, proc merging, guard release/reuse, resource restoration, Haste expiry, Quick Shot cadence and HUD snapshots |
| `services/replay_validator` | `dart test test/eloise_balance_replay_test.dart` | 36 passed: six utilities × two shots × 30/60/90 Hz, direct commands versus JSON-round-tripped replay frames |
| Root | `flutter test --no-pub test/core/self_ability_system_test.dart test/ui/text/ability_tag_resolver_test.dart test/ui/text/gear_text_test.dart test/core/parry_middleware_test.dart test/core/command_scheduling_test.dart test/core/determinism_test.dart test/core/fixed_point_pilot_test.dart` | 54 passed |
| Root | `flutter test --no-pub test/ui/hud/game/riposte_hud_test.dart test/ui/hud/game/hud_layout_test.dart test/ui/state/firebase_run_session_api_test.dart test/ui/icons test/ui/state/app_state_inbox_test.dart test/ui/state/firebase_inbox_api_test.dart` | 35 passed; includes narrow HUD layout and countdown independence from UI wall time |
| Root | `flutter test --no-pub test/ui/pages/select_character/loadout_setup_page_phase4_test.dart` | 10 passed |
| `tools/admin` | `flutter test --no-pub test/admin_page_test.dart` | 2 passed; catalog/art and wide/narrow fixture composition |
| `functions` | `corepack pnpm build` and `corepack pnpm build:test` | Passed |
| `functions` | `node --test lib_test/test/runs/compatibility.test.js` and `node --test lib_test/test/runs/practice_routes.test.js` | 3 + 2 passed |
| Root | `dart analyze packages/runner_core packages/game_presentation lib/ui/text lib/ui/hud/game/top_left_hud_overlay.dart lib/ui/hud/game/riposte_hud.dart test/ui/hud/game/riposte_hud_test.dart` | No issues |
| Root | `dart analyze packages/runner_core/test/combat/eloise_balance_test.dart` after snapshot coverage | No issues |
| `services/replay_validator` | `dart analyze lib/src/validator_worker.dart test/eloise_balance_replay_test.dart` | No issues |
| Root | `dart run tool/sync_assets.dart --check` | Current |
| Root | `dart run packages/runner_core/tool/update_navigation_revision.dart --check` | Current; navigation fingerprint unchanged |
| Root | `node tools/admin/service/catalog.mjs --check-fixture` | Current |
| Root | `git diff --check` and relative Markdown target checks for task docs | Passed |

Earlier combined invocations also passed 231 existing status/Willow regression
cases and 99 worker cases, but those commands exited unsuccessfully because the
new test fixture initially failed to load. Fixture path/constructor mistakes were
corrected; the new suites subsequently passed as listed above. Initial root
failures exposed stale tuning expectations and two existing equipment description
expectations; these were corrected and the 54-test command passed. The cadence
fixture was corrected to include the starter belt's actual cooldown penalty.
No unresolved failure is being treated as a pass.

Replay scenarios run 12 seconds with fixed seed 98 and track generation disabled.
They assert actual projectile/charge execution and compare checkpoint/final
snapshots; they prove deterministic reproduction, not encounter balance against
enemies. Targeted combat fixtures establish the changed effects and boundaries.

## Compatibility and remaining acceptance

Client, issuer and replay worker now prepare `2026.11.8.1`. No command or replay
wire schema changed. The offline owning generator
`node functions/tool/refresh_navigation_routes.mjs` regenerated ranked seeds
from unchanged windows; Practice seeds are preserved. It was executed only after
verifying that it writes local catalog data and performs no remote mutation.
Navigation fingerprint remains
`bd2274e0b71f13d538e131be959817d040eb11182da317b2db98903ed26a1e98`.

This is an implemented first balance pass. Full suites, representative device
playtesting, live encounter balance measurements and deployment were not run.
Playtesting should compare utility pick rates, damage taken per minute, recovery
between encounters, full-charge completion rates and successful Riposte followups.
Compatible client/issuer/worker rollout remains release work. Changes are left
uncommitted alongside the preserved existing work.
