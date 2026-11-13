# Training Field contract

Training uses the [shared runtime, input binding and surface](shared_gameplay_runtime.md).
Its auto-start, tab lifetime, opponent picker and reset policies remain local to
TrainingFieldSession/TrainingFieldTab; editor device calibration is not inherited.
The builder supplies its pinned character and build index to TrainingFieldTab.
Session creation and reset resolve that addressed loadout without selecting it;
direct tab entries without an address retain the current-selection fallback.

Training is a disposable local session outside registered run levels. It has no
ticket, recorder, reward handoff, replay submission, or persisted session state.
Normal run construction and protocol identities remain unchanged.

## Source and generation

`assets/authoring/level/training_field.json` is a separate schema-1 envelope:
revision, visual theme, player start in chunk 1, one enemy contact point with its
chunk index, and exactly two embedded chunk-v2 layout records (600 × 270).
Ordinary markers, encounters, arenas, traps, and water are rejected. Runtime
training settings are absent. The source compiler belongs to
`runner_content_pipeline`, consumes explicit strings, and performs no I/O.

The shared polygon compiler checks both joins, 1→2 and 2→1. Placement admission
uses the real player and regular-enemy catalog capsules, including Derf's support
width and the flying enemy's hover clearance. Invalid support blocks Build.
The root content generator validates the theme/material references and emits
`runner_core/lib/training/authored_training_{field,terrain}.dart` in its existing
atomic artifact transaction. Both outputs are excluded from captured source
inputs. Training is excluded from LevelId, normal level pools and leaderboards.

## Runtime

`GameCore.trainingField` admits the generated definition and current build.
Its pattern source selects by chunk-index modulo two; streaming keeps continuous
world coordinates. Camera tuning sets automatic speed to zero and retains normal
forward follow. An optional explicit support height in player initialization
honors the authored start beneath other platforms; ordinary runs retain their
topmost-support placement.

The Core training scheduler runs after terrain publication and before movement.
It queues the next occurrence of the marked chunk beyond the player's current
chunk, then spawns when that chunk enters the camera's forward extent. It removes
the previous opponent and enemy-owned hitboxes/projectiles before replacement.
None clears them on the next tick. Each selection is consumed once. Bosses and
summons are rejected by Core as well as omitted from the UI. Derf uses the shared
ground placement resolver with the marker's exact support height; ordinary
authored Derf perch spawning is unchanged. Automatic items, encounters, traps,
and ambient enemy spawning are bypassed only for this explicit factory.

The UI-owned `TrainingFieldSession` owns Core, controller, input, Flame host and
aim previews. `TrainingFieldTab` starts only after world preparation, cancels
input on modal/focus/background changes, and retires the entire session on
unmount or Reset. The parent mounts this tab only while selected. The picker uses
the same Library unlock rule as Codex and rechecks it on confirmation. Selecting
None, death Reset, and returning to the tab never restore an old opponent choice.
Combat death keeps the existing Core animation-only freeze, and Reset appears
only when Core publishes `gameOver` after the complete strip. Core captures the
player's grounded state before death cleanup releases terrain support, so Willow's
grounded death cannot switch to her shorter airborne strip during the freeze.

`TrainingFieldTab` supplies `UiHapticsService` to `RunnerGameplayBindings`, so
combat, charge-tier and ability-end cues use the same haptics mapping as normal runs.

`TrainingOpponentDialog` uses the shared `AppDialog` shell with scrollable content
and fixed title/actions. Its `EnemyPortrait` component is shared with the Library
and reads cached static frames from `UiAssetLifecycle`; the picker owns no separate
image cache or animation loop.

Character setup opts into `MenuScaffold.overlayAppBar` only for Training Field.
The game viewport and `GameOverlay` use the full page behind the transparent app
bar. Only the resources row (including its opponent button) consumes the body's
safe-area padding, which includes the app bar. Touch controls, the desktop control
bar, aim cancellation, damage borders, and terrain-recovery dimming use full-page
bounds. Rendering and desktop aim share the full viewport metrics.

## Editor ownership

The Training Field plugin owns its source envelope, dependency baselines,
validation, pending diff, transactional Save, and history reconciliation. It
reuses Chunk Creator's geometry workspace in bounded-layout mode, hiding normal
level/owner lifecycle and gameplay catalogs. The page provides player/enemy
contact-point inspectors and markers. No normal level or chunk file is written.

Save finalizes valid visible input. Incomplete geometric joins or placement can
be saved as drafts but block Build. Source/dependency drift rejects the write;
transaction failures preserve typed rollback/cleanup recovery. Undo after Save
restores content against the current disk baseline. Reload discards page drafts
after the shell's normal guard. Material deletion protection includes this
source, and the shared Build action generates its runtime artifacts.

The [gameplay specification](../gdd/training_field.md) describes player behavior.
Local validation evidence is recorded in the
[completed implementation checklist](../archive/2026-11-02/building/training_field.md);
this feature has not been deployed or verified on a physical device.
