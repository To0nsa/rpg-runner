# Campaign validation plan

Status: planned checks, not test evidence. Progress is recorded only in the
[implementation checklist](implementation.md). This documentation task requires
diff/link validation; do not run application suites merely to publish the plan.

## Behavior matrix

| Area | Required evidence | Milestone |
| --- | --- | --- |
| Fixed route | Exact order across seeds; stable repeated occurrences; no continuation past final chunk; invalid references fail clearly | M1/M2 |
| Camera/bounds | Left/right following, edge clamping, narrow-route framing, dash/teleport/knockback boundaries; no behind-camera death | M1 |
| Terrain lifetime | Return after crossing actual unload/activation boundaries where used; collision ready before tick; no unsupported active actors | M1 |
| Persistent state | Dead enemies, collected items, damaged living enemies, cooldown/status/AI state, rescues, and traps survive return travel correctly | M1 |
| Objectives | Required versus optional targets, repeated source instances, exit before readiness, success once, death/success ordering, failure/abandonment | M1 |
| Replay | Same input/ticket/content gives same terminal tick, objective results, stats, score, and reward inputs; tampering/mismatch rejected | M1/M3 |
| Editor | Create/reorder/variant/repair/play/save/reopen/build; dependency drift, unsaved capture isolation, Undo after Save, failed-save recovery | M2 |
| Generated content | Exact dependency closure and freshness; shared edits invalidate all affected missions; independent source ownership retained | M2 |
| Admission | First mission open, locked missions rejected, prerequisites/content/build rechecked, no accidental ranked board requirement | M3 |
| Settlement | Duplicate delivery and two distinct first-clear attempts, response loss, reconnect, account deletion/switch, old records | M3 |
| UI | Three-card single row, crop/anchor, map/list/details/back flow, lock/clear/pending states, first versus repeat rewards, best score | M3/M4 |
| Content | Complete chapter with both starter builds; no locked-skill dependency; required encounters/resources guaranteed | M4 |
| Regression | Practice/Competitive/Weekly, Training Field, runner camera/assembly, Library rules, achievements, existing rewards/ghosts | M1-M4 as affected |
| Performance | Startup, terrain preparation, left/right travel, camera motion, graph fallback, frame/tick time and memory on representative hardware | M1/M4 |

## Traversal proof

Follow the [level traversal workflow](../../../.agent/workflows/test-level-traversal.md)
with generated freshness checked first. Declare mission/content fingerprint,
occurrence sequence, combat seeds, player builds, enemy catalog profiles, tick
rates, coordinate boundaries, activation policy, and finite tick/route horizons.

A campaign route test traverses the actual joins forward and backward with one
continuous actor state, then satisfies the authored exit. Exercise enough distance
to leave and re-enter the real active terrain window if one exists; crossing one
seam inside a permanently loaded window does not prove reload behavior. For a
fully resident first slice, report that policy and its measured route-size budget
instead of claiming unloaded-region coverage.

Adapt forward-only harness assumptions explicitly. Do not reuse monotonically
increasing waypoint/stall logic for a legitimate return trip. Finite missions end
at their authored exit; they do not need the endless harness's synthetic next
chunk. Add clear/blocked controls for forward and reverse boundaries and for the
exit objective. Crossing the actual declared boundary or entering the actual
exit region is required; proximity tolerances cannot substitute for completion.

Use actual catalog movement limits, start support, physics, water/trap behavior,
and composed terrain. Retain exact failing occurrence sequences and combat seeds.
Diagnose geometry, graph planning, and movement execution separately. Do not
teleport actors, skip chunks, widen tolerances to hide failures, or increase
character/enemy capabilities merely to make reused terrain pass.

Player traversal is required for both starter characters. Ground enemies need
continuous pursuit/reversal checks across the joins they are allowed to use;
flying enemies and confined bosses need their own behavior-appropriate checks.
Pursuit tests alone do not prove spawn, combat, resource pacing, camera, objective,
or complete-mission behavior.

## Replay and authority boundaries

Use actual encoded producer payloads through consumer admission and production
simulation. A pure serializer round trip is insufficient. Include a supported
non-default tick rate, content/scoring version changes, malformed/missing/null
fields, unknown mission IDs, unavailable content, changed loadouts, and unsupported
legacy mode combinations. Run the required protocol AOT probe when constructor
admission changes, as specified by its owner instructions.

Check that local editor/Developer Practice results cannot update canonical
progress. The validator must reject forged completion/score/reward inputs and
resolve trusted content itself. Compare client/local-run and worker terminal
evidence for the full return-trip fixture, then representative authored missions.
Performance fixtures must use the admitted content and actual world lifetime
policy, including prepared-navigation misses where relevant.

Exercise successful settlement twice for one run and concurrently for two
different runs clearing the same mission. Only one first-clear entitlement can
be consumed. Replayed completions can update a compatible personal best without
re-granting that entitlement. Content revisions preserve progression but do not
mix incompatible score records. Receipts/canonical revisions, prerequisites,
retry recovery, account deletion, and other reward projections remain consistent.

## Focused commands and existing starting points

Use the [validation routing index](../../../.agent/README.md#validation) for working
directories and the current owning instructions for mandatory checks. The examples
below are command templates for implementation, not commands run for this plan.
Replace test targets with the actual new/affected files; no campaign tests exist
merely because they are described here.

| Scope and working directory | Appropriate command |
| --- | --- |
| Repository root, generated content | `dart run tool/generate_chunk_runtime_data.dart --dry-run` |
| Owning pure-Dart package | `dart analyze`; `dart test <target>` |
| Repository root, app | `dart analyze <changed-path>`; `flutter test <target>` |
| `tools/editor` | `dart analyze <changed-path>`; `flutter test <target>` |
| Repository root, Functions | `corepack pnpm --dir functions build`; relevant emulator tests through the existing Functions harness |
| `services/replay_validator` | `dart analyze`; `dart test <target>` |

Useful existing fixtures include Core `test/training/training_field_test.dart`,
`test/playtest/level_playtest_scenario_test.dart`,
`test/track/track_streamer_active_chunks_test.dart`, and
`test/collision/terrain/terrain_chunk_connections_test.dart`; root
`test/ui/pages/hub/play_hub_page_test.dart` and
`test/ui/run/runner_run_session_test.dart`; editor
`test/level_playtest_editor_integration_test.dart`; validator
`test/run_session_repository_test.dart` and `test/settlement_dispatcher_test.dart`.
Extend these only where they own an affected invariant; add campaign-specific
behavior coverage instead of changing unrelated test expectations.

## Evidence and release

At each milestone record source/commit or captured input fingerprint, commands,
working directories, results, test scope, and remaining gaps. Keep raw/transient
logs out of committed plans. Reference focused evidence under `docs/verification/`
when it becomes substantial. Distinguish local, mocked, emulator, live backend,
and physical-device checks. Reuse unchanged valid evidence; rebuild/retest only
when inputs, environment, toolchain, or uncovered concerns justify it.

For UI acceptance include the smallest supported viewport, landscape dimensions
used by the app, safe-area insets, enlarged text, English/French, and touch/desktop
input. Inspect actual rendering and navigation; widget assertions alone do not
prove map crop, legibility, or camera feel. Record measured performance and device
identity rather than declaring a route fast from desktop test timing.

Release preparation follows the existing [deployment contract](../../tdd/deployment_workflow.md)
and [release workflow](../../../.agent/workflows/deploy-release.md). Shared
simulation/protocol changes keep coordinated compatibility requirements. Freeze
matching app, worker, generated source, and trusted mission/reward catalogue;
declare finite route coverage in navigation artifacts. Deployment and signed-in
device acceptance remain unrun until an authorized release actually performs them.
