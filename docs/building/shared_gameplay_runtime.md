# Shared gameplay runtime and editor play plan

Status: implementation, task-diff review, targeted native/unit tests and Windows
release editor compilation completed November 12, 2026. M1–M5 are implemented.
M6 remains open for optimized web/browser verification and hands-on ruler,
monitor and real-device acceptance. Resource/tooling limitations are recorded
below; this is not a full-acceptance claim.
This is the single implementation checklist for this cleanup. The existing
[Campaign preview evidence](campaign/implementation.md#mobile-hud-in-mission-play-november-12)
records the earlier implementation, not completion of this plan.

The outcome is one maintained gameplay foundation for the product game, in-game
Training Field, Chunk Play, Runner Level Play and Campaign Play. Each mode keeps
its content, lifecycle and presentation needs. Shared mechanics have one owner;
mode decisions stay in focused session modules. Cleanup includes existing tangled
code in the affected paths, not just placing new wrappers around it.

All three editor Play modes gain the same pre-launch HUD, movement-control and
device settings. The user specifically requires previews at the device screen's
actual physical size, with monitor calibration and no automatic zoom when the
editor window changes size. This supersedes the current fit-to-window preview.

## Scope and boundaries

| Consumer | Behavior to retain |
| --- | --- |
| Product game | Campaign and runner modes, online recording/settlement, Developer Practice, optional runner ghosts, selected character/build, route navigation and platform control preferences |
| In-game Training Field | Current build, world-ready auto-start, opponent picker and unlock checks, training HUD, death-animation completion, Reset and disposal on leaving the tab |
| Chunk Creator Play | Accepted local edits, focused selected/filtered chunk scenario, captured assets, editor shortcuts, frozen Restart and return to the same workspace |
| Runner Level Play | Selected authored level and seed, ordered assembly and normal enemy-opening behavior, captured dependencies and workspace restoration |
| Campaign Play | Exact finite authored mission, objectives and backtracking, captured dependencies and workspace restoration |

The editor's Training Field layout authoring remains a source editor. This plan
includes the **in-game Training Field runtime**; it does not add a new Play feature
to its layout editor. No tutorial system, character/loadout picker, gameplay tuning,
new persistence schema for content, backend/protocol redesign or deployment is
included. Both characters and representative loadouts remain validation cases.

The working tree already contains extensive uncommitted Campaign, UI, content
and preview changes. The audit used HEAD
`1bf2a2d52ea6e3d6f78905e74cf5b6c0496bb57e` plus that working tree. Preserve those
changes, including staged work, and record the actual source state at each gate.

## Existing implementation and proposed ownership

The simulation, renderer, semantic dispatcher, input router, HUD and viewport math
are already shared. The duplication is primarily construction, event bindings,
resource ownership and view composition. Keep the existing implementations of
those systems and extract their wiring.

| Responsibility | Proposed owner and migration |
| --- | --- |
| Gameplay truth | Existing `GameCore`, `CampaignSession`, Core training systems and explicit factories; preserve `ui -> game -> core` |
| Common runtime graph | A small `RunnerGameplayRuntime` under `lib/game/`, used by all session types; owns controller/router/aim models and renderer construction without importing UI, editor, AppState or account services |
| Input and feedback bindings | One module under `lib/ui/input/`; owns semantic dispatch wiring, device-controller lifetime, UI signals and subscriptions; consumes runtime aim models without disposing them |
| Shared game surface | One UI component for viewport calculation, desktop hit surface and existing `GameOverlay`; consumes session state and presentation inputs without creating sessions or submitting results |
| Product session | Refine `RunnerRunSession` and focused helpers under `lib/ui/run/`; retain readiness, recorder, ghost and attempt identity policies; reuse existing `RunStartPreparation` and AppState submission services |
| Training session | Refine `TrainingFieldSession`; retain training start/reset/opponent policy. `TrainingFieldTab` and its picker remain focused on UI and unlock-aware selection |
| Editor runtime session | Extract generation/lifecycle coordination from `RunnerPlaytestHost` into a focused `lib/playtest/` session; retain the public controller and host APIs |
| Editor preparation and launch | Extend existing `AuthoredPlaytestSession` and shared editor widgets; pages keep source selection and local-field acceptance |
| Device preview | Existing display value/catalog/frame, extended with physical screen metadata; editor-owned calibration/profile storage and a fixed physical-size wrapper |

These module names describe intended responsibilities; use an existing owner when
it already fits. Do not introduce a new package, service locator, generic plugin
framework, duplicate session hierarchy, or a universal session driven by mode
booleans. Shared UI may consume explicit overlay content/callbacks; it must not
switch on editor page types or perform source I/O.

`RunnerGameWidget` should become a composition facade. Move remaining non-view
workflows, including attempt-bound result finalization and restart coordination,
to their run-owned helpers where they still obscure ownership. Preserve existing
AppState/backend authority rather than creating a second submission coordinator.
Apply the same responsibility review to `RunnerPlaytestHost` and
`TrainingFieldTab`. File splitting alone is not completion.

## Contracts to settle before extraction

### Runtime lifetime and asynchronous work

Each attempt has an immutable identity and one runtime graph. Session wrappers
decide when the attempt can start, pause, resume or be replaced. Common code owns
the mechanics of cancellation and resource retirement, not those policy decisions.

Retirement must fence callbacks and cancel queued/held input before stopping the
controller and pending preparation. Detach subscriptions before disposing their
publishers. Unmount the old view before disposing signals it still reads. Preserve
Flame's ownership of mounted game removal, render-listenable disposal and image
cleanup; the runtime must not independently invoke those hooks a second time.
Specify a cleanup path for construction failure and a game that never mounts.
Document idempotency and the handoff between session, binding and Flutter/Flame.

Product recorder finalization/closing can outlive a view. Capture descriptor,
recorder, summary and session identity before an await; late completions may finish
the correct durable operation but cannot update or submit under a replacement
attempt. Preserve pre-start ticket reuse only after the previous recorder closes,
and preserve exactly-once journal/submission behavior.

World/terrain readiness remains distinct from user pause. Preserve
`prepareNextTick` admission, buffered command cancellation, renderer update order,
the first recorded tick and ghost preparation. No new frame driver or tick loop.

### Mode policies and presentation

Product runs still wait for world and required recorder readiness. Editor Play
still requires explicit Start; background/focus loss pauses until explicit Resume.
Training still auto-starts after preparation, retains its current touch/desktop
resume policy and pauses for its opponent picker. Product mobile background resume
retains its existing policy. Do not homogenize these differences during extraction.

Training keeps the transparent app bar, full-page game/controls and the resource
row's distinct safe area. Death Reset remains unavailable until Core publishes
game-over after the death animation. None, Reset and leaving/re-entering the tab
must not resurrect an old opponent. Recheck unlocks when a picker result returns;
discard it after session replacement or unmount.

Input binding must distinguish full cancellation from charged-ability cancellation.
A timed-out charge must not clear unrelated movement. Keep touch pointer epochs
and charge-cancel signals distinct. Handle multi-touch plus keyboard/mouse sources,
duplicate lifecycle notifications, action-mode changes and late release events.
HUD buttons must not also issue attacks through the desktop world surface.

Keep actual device `MediaQuery`, locale, text scaling, reduced-motion behavior,
orientation and system UI in the product/Training Field host. The editor's simulated
logical display remains scoped to its preview. Editor settings never mutate the
player's `ControlSettings`, authored source or gameplay/replay descriptor.

### Editor launch and source capture

Move `CampaignPlaytestDialog` into a shared launch dialog with a title/description
provided by the caller. Reuse `PlaytestDisplaySettings`, display presets and the
presentation value; remove Campaign-specific aliases and callers after migration.
One shared session owns the modal-in-flight guard and last accepted settings.
Settings remain page-session-local, matching current Campaign behavior; no new
global play preference persistence is needed. Calibration has separate editor
machine-level persistence.

All three modes default to HUD on, arrows and the existing default phone preset.
Retain floating/fixed joysticks and custom dimensions/DPR. HUD off hides the mobile
overlay while preserving keyboard input and accessible host start/pause/stop
actions. Preserve public embedding constructor defaults; change editor defaults
at the editor composition boundary.

Pages retain their existing valid-field acceptance before launch. Cancel discards
the settings draft, performs no capture, Save or runtime creation, and cannot
commit new presentation choices. It does not undo field edits already accepted
through the page's normal semantic commands. Test this explicitly instead of
claiming that Cancel can never change document identity.

Fence the dialog through controller, workspace, document and selected-target
changes as well as disposal. Repeated Play/F5 opens one modal. Retry recaptures
current accepted source with the accepted presentation; Restart reuses the frozen
scenario/assets/presentation. Return to Edit preserves source/history, selection,
scroll positions and viewport context.

Keep scenario semantics explicit. Chunk pool selection, whole-Level assembly and
Campaign mission compilation must not share a permissive fallback. Restore starter
equipment consistently through the Core/catalog default path; do not copy gear IDs
into editor pages. Preserve explicit scenario overrides and product player builds.

### Actual physical display size

The preview represents the active rectangular screen, not the phone body or bezel.
Browser device presets supply logical width/height and DPR; they do not establish
centimetres. Add sourced physical screen dimensions/diagonal and precision to the
curated presets. Verify physical metadata against manufacturer specifications
before enabling a preset's actual-size mode. Document nominal rectangular size for
rounded screens. Preserve the logical aspect ratio with a uniform scale; do not
silently stretch mismatched physical and logical metadata.

Keep the existing logical display contract usable without calibration metadata.
Physical-size requirements apply at the editor launch boundary, not to every
public embedding caller. The shared frame consumes resolved immutable geometry;
monitor APIs and profile storage stay in the editor, outside gameplay and product
services.

Calibration uses a known measured length on the current monitor, such as a ruler
reference, with an adjustable reference line. Store calibrated monitor pixels per
millimetre and the display/profile signature independently from mission settings.
Identify monitors and resolution modes through a narrow editor platform adapter;
use explicit profile selection if reliable identification is unavailable. Never
silently reuse a different monitor's calibration. Remote desktop, changed display
resolution or an unrecognized monitor must request calibration/profile selection.

The preview scale is derived from physical size, not available window space:

`preview scale = monitor pixels per mm * device screen width mm / (monitor DPR * device logical width)`.

The selected **device DPR** affects the simulated game's inner viewport; the
**monitor DPR** converts the outer physical size to editor logical units. Do not
apply either twice. Normal OS scaling changes can recompute the outer scale from
the same valid monitor calibration. Monitor changes must resolve a matching profile
before claiming physical accuracy.

Resolve the monitor from the preview's bounds. A physical-accuracy claim requires
the preview to occupy one calibrated monitor; a window spanning different-density
monitors cannot use one scale everywhere. If the preview crosses monitors or its
profile becomes invalid, clear held input and pause pending repositioning or profile
resolution. Preserve the attempt rather than recreating it. Display signatures
include resolution and orientation; corrupt/stale profiles remain unresolved.

Custom devices require logical dimensions/DPR and a measured physical dimension
or diagonal; unknown physical size must be explicitly unresolved. Keep validation
and physical-size math in one place, with an explicit aspect/rounding policy.
First use guides calibration before launching actual-size Play. Cancellation
returns to setup/editing without starting a runtime.

Replace automatic `FittedBox` fitting. Center a fitting preview; when it exceeds
the editor area, retain its calibrated size and provide surrounding scrollbars or
a dedicated pan control. Panning must not steal joystick/aim gestures. Resizing
changes margins/visible area, not scale or runtime identity. Reconfiguration that
moves input geometry cancels active pointers without committing an ability.
The frame must still map pointer positions, cancel hitboxes and HUD obstacles
through the same transforms.

No automatic fit, magnification or fit-to-window fallback is included. The UI must
distinguish a calibrated preview from an unresolved calibration. This remains a
layout/input preview; notches, system bars, hardware GPU density and device
performance emulation remain outside this workstream.

## Audit findings incorporated into this plan

This audit inspected code and existing tests; it did not rerun runtime tests or
reproduce every suspected behavior. The dispositions below are implementation
requirements, not claims that the current code is fixed.

| Finding | Evidence and gap | Required response |
| --- | --- | --- |
| A1 Resource ownership | [Flame game](../../lib/game/runner_flame_game.dart) owns removal/image/listenable cleanup, while [product](../../lib/ui/run/runner_run_session.dart), [training](../../lib/ui/run/training_field_session.dart) and [editor](../../lib/playtest/runner_playtest_host.dart) each retire controller/preview resources. A generic dispose method could double-dispose or dispose before unmount. | M1 ownership inventory; M3 explicit mounted, never-mounted, failed-construction and late-completion retirement tests. |
| A2 Input behavior drift | [Product host](../../lib/ui/runner_game_widget.dart) handles charge timeout/damage interruption, terrain failure and per-tick mouse aim refresh. The editor's tick handler checks game-over and its event handler only forwards impact; [Training](../../lib/ui/pages/selectCharacter/training_field_tab.dart) has a third partial implementation. | M2 shared bindings with observable regression tests; preserve movement during charge-only cancellation and feedback deduplication. |
| A3 Async result identity | Product `_journalReplayForSubmission` retains a recorder but reads host session fields after awaits; restart replaces those fields. This is a potential stale-attempt association and UI-update hazard, not a reproduced account mutation. | M3 immutable operation context and delayed-finalize/journal/restart tests; old work cannot borrow the new run ID or overwrite its status. |
| A4 Training is more than controls | [Training contract](../tdd/training_field.md) and [parent tab](../../lib/ui/pages/selectCharacter/loadout_setup_page.dart) include auto-start, full-page layout beneath the app bar, unlock-aware modal selection, death timing and tab-owned lifetime. | M2–M4 migrate the complete Training runtime/view while retaining these policies. |
| A5 Existing Training tests were easy to miss | Host coverage is in [loadout_setup_page_phase4_test.dart](../../test/ui/pages/select_character/loadout_setup_page_phase4_test.dart), including real death animation, app-bar geometry, opponent filtering and tab/reset behavior; it is not limited to the opponent-dialog test. | Reuse these tests in every affected milestone; add missing binding/lifecycle regressions instead of replacing them with a smaller synthetic harness. |
| A6 Product variants and embedding | [Public route](../../lib/ui/runner_game_route.dart) includes online readiness, developer mode, ghosts, terrain waits, locale and platform controls. Extracting only Campaign's product path would miss these consumers. | M3–M4 cover normal runner, Campaign, Developer Practice and ghost-enabled runner; retain public API and test injection seams. |
| A7 Source admission and equipment | [Preparation](../../tools/editor/lib/src/playtest/authored_playtest_preparation.dart) filters runner patterns but passes a broader terrain collection, and Chunk/Level explicitly use an empty default loadout. Previous checks recorded pool failures and a stale capture-count assertion. | M1 reproduce/repair related admission failures without bypassing validation; M5 canonical starter loadout, explicit overrides and distinct scenario tests. |
| A8 Launch races and Cancel semantics | [Shared session](../../tools/editor/lib/src/app/pages/shared/authored_playtest_session.dart) fences capture/compilation; Campaign alone owns the setup guard/settings. Page-level field acceptance can precede Cancel. | M5 extend fencing through setup, target/controller/workspace replacement and repeated F5; preserve undoable field acceptance and distinguish it from settings/capture effects. |
| A9 Lifecycle policies differ | Product mobile resume, editor explicit Resume, Training auto-start/modal resume and recorder readiness are intentionally different. | M1 policy table; M3 common mechanics with separate policies, not a universal state machine or implicit auto-resume. |
| A10 Physical size was absent | [Current frame](../../lib/playtest/runner_playtest_display_frame.dart) fits available space and [presets](../../lib/playtest/runner_playtest_device_presets.dart) contain logical dimensions/DPR only. Neither establishes real screen size. | M1 validate physical metadata/calibration feasibility; M5 fixed calibrated scale, monitor profiles, overflow/pan behavior and physical measurement gate. |
| A11 Viewport and inherited environment | Training uses contain and different resource-row insets; Campaign preview uses cover and a scoped `MediaQuery`. [HUD obstacles](../../lib/ui/hud/game/offscreen_indicator_overlay.dart) and aim cancellation use transformed coordinates. | M4 preserve each inner viewport policy and actual-device environment; M5 apply physical scaling only outside the editor view. Test clipping, panning, DPI and hit targets. |
| A12 False parity claims | Different scenarios intentionally have different spawning, identity, camera and objectives. Direct equality across all modes would either fail legitimately or hide differences by broad normalization. | Use the two parity levels below; enumerate any non-gameplay identity differences before assertions. |
| A13 Partial modularization | Large host widgets mix construction, event handling, rendering and async workflows. Moving a few methods while keeping parallel implementations would leave the original maintenance problem. | Each milestone removes the replaced path. M6 audits remaining constructors, subscriptions, metrics and mode branches; do not introduce unexplained wrapper layers. |
| A14 Performance and imports | New wrappers can duplicate per-tick subscriptions/rebuilds or bring recorder/native/editor dependencies into shared runtime code. | M2–M4 retain a single input/update path, inspect listener counts, preserve native/web imports and cache lifetime; profile only when new evidence indicates a regression. |

## Implementation milestones

Execute in dependency order. Each milestone includes tests, targeted analysis,
documentation and a review of the actual diff before starting the next. Keep
independently validated changes coherent; preserve unrelated staged work.

### M1 Baseline and contracts

- [x] Record current consumer/resource/policy inventories and focused test baseline.
- [x] Reproduce the previously reported Level terrain-pool mismatch, Chunk fixture
      count and focused-metadata overflow. Repair blockers for these Play paths in
      isolated changes; keep unrelated failures explicit. No removed assertions,
      geometry changes or invented fallback pools to make tests pass.
- [x] Add characterization for input/async hazards and both parity levels. Input
      cases accompanied M2, delayed finalization M3 and equivalent Campaign
      construction M6; this sequencing adjustment is recorded in the evidence.
- [x] Verify sourced physical metadata, calibration persistence, aspect rounding
      and manual-profile fallback; implement/test monitor identity and DPR math.
      Real monitor/ruler verification remains the separate M6 manual gate.

Gate: ownership and intentional differences are explicit; affected launch paths
can be tested; every remaining failure has a classification and owner. Existing
Campaign's 42 focused passes are historical evidence, not this refactor's baseline.

### M2 Shared input and feedback bindings

- [x] Extract action-mode resolution, aim/impact signals, device binding and event
      subscriptions into one implementation used by product, Training and editor.
- [x] Centralize full/charge-only cancellation, terrain-failure cancellation and
      stationary-pointer aim refresh without altering router buffering/order.
- [x] Keep haptics optional and event deduplication explicit; retire old handlers
      and signal ownership in the same migration.
- [x] Verify both characters, tap/maintain/release/aimed actions, mixed input,
      cancellation without accidental commit and replacement/disposal listeners.

Gate: common input behavior matches for equivalent contexts, including the new
regression cases. Each host retains its focus/start/resume policy.

### M3 Shared runtime and focused sessions

- [x] Extract the common runtime graph and migrate product, Training and all
      editor scenarios. Preserve explicit Core factories and catalog authority.
- [x] Make construction failure, readiness, stop and retirement ownership explicit;
      remove parallel resource setup/disposal. Keep Flame mount ownership intact.
- [x] Refine product restart/finalization helpers and Training/editor coordinators
      so widget code no longer owns unrelated async/runtime workflows.
- [x] Fence operations by attempt identity, preserving recorder/ticket rules,
      ghost lifecycle, Training reset and frozen editor Restart.

Gate: startup/retry, rapid replacement, pre-start exit, mid-load disposal and late
recorder/asset/ghost completions are safe. Product result effects remain exactly
once, while Training/editor/Developer Practice never gain recorder or account writes.

### M4 Shared view composition

- [x] Extract one metrics/game/input/HUD surface using the existing `GameViewport`
      and `GameOverlay`; migrate product, Training and editor consumers.
- [x] Keep loading/pause/results, Training opponent controls and editor actions as
      explicit host presentation. Simplify remaining mode branches by ownership;
      do not fork the HUD or create a second UI state model for Core values.
- [x] Preserve theme/localization, accessibility, app-bar/safe-area geometry,
      viewport alignment, touch/desktop scheme changes and public embedding APIs.

Gate: visual/input tests cover real sprites, controls, HUD indicators, aim targets,
Training's full-page view, loading/error states and actual-device environment.

### M5 Shared editor launch and physical device preview

- [x] Migrate all three editor pages to one setup dialog and session-owned settings,
      modal guards, source checks and Retry/Restart rules. Remove Campaign-only paths.
- [x] Use canonical starter equipment for editor defaults and retain explicit
      overrides; preserve all three content-selection/assembly semantics.
- [x] Add verified device physical metadata, custom physical dimensions and a
      cancellable monitor-calibration flow with separate editor profile storage.
- [x] Replace auto-fit with fixed physical sizing, stable resize behavior and
      overflow scroll/pan controls that do not interfere with gameplay gestures.
- [x] Verify preset/custom validation, calibration/profile cancellation, mocked
      monitor changes, stale/nested setup, repeated F5 and page-local settings.

Gate: each editor mode launches the real shared runtime/view with identical setup
capabilities. Screen size is independent of window size and is not called calibrated
without a valid profile. Frame/input tests pass before the physical measurement gate.

### M6 Cleanup and integrated acceptance

- [x] Audit every touched play-mode path for duplicate construction, event/input
      logic, viewport calculations, stale helpers/imports, dead flags and unnecessary
      forwarding layers. Remove superseded implementations rather than leaving TODOs.
- [x] Run the affected native/unit integration targets, including repeated lifecycle
      transitions, calibrated geometry, editor admission and scenario parity.
- [x] Complete final Windows editor compilation and focused analysis checks.
- [ ] Complete optimized web compilation and browser execution checks; current
      attempts are blocked by memory headroom and the local Flutter test server.
- [ ] Run native editor/product/Training smoke checks, physical ruler measurement
      and monitor switching/straddling. These require actual device interaction.
- [x] Update implemented TDDs, editor README and public embedding/playtest API docs.
      Keep this plan active until manual acceptance; do not archive unfinished gates.

Gate: shared behavior has one implementation; mode-specific behavior has a named
owner and tests; no blocking failures remain in the affected paths. Unavailable
native/physical checks remain open and prevent a full-acceptance claim.

## Verification matrix

Two distinct parity checks are required:

1. **Input and presentation parity:** equivalent action scripts under the same
   loadout/control configuration produce equivalent applied command frames across
   product, Training and editor bindings. Include cancellation, damage/timeout,
   pointer-stationary movement and focus changes. Do not claim equal gameplay
   state across different scenario types.
2. **Equivalent scenario parity:** run matching compiled content through product
   and captured-editor construction using the same character, loadout, seed and
   tick-stamped commands. Compare gameplay-relevant state/events at declared ticks
   and an explicit finite horizon. Document intentional run-ID/level-identity
   differences; never normalize away collision, objectives, inventory or combat.
   Do not weaken production digest checks or substitute an untrusted mission.

| Area | Existing coverage to retain and required additions |
| --- | --- |
| Input | Root `test/game/input/runner_semantic_action_dispatcher_test.dart`, `test/ui/input/desktop/`, `test/ui/controls/movement_control_test.dart`, `test/ui/controls/directional_action_button_test.dart`; add shared-binding timeout/damage/terrain/mixed-input and listener retirement cases |
| Product | Root `test/ui/run/runner_run_session_test.dart`, `test/ui/runner_game_widget_startup_test.dart`, `test/ui/runner_game_widget_desktop_test.dart`, `test/ui/runner_game_widget_ghost_test.dart`; add delayed finalize/journal across restart/exit and duplicate-event checks |
| Training | Root `test/ui/pages/select_character/loadout_setup_page_phase4_test.dart`, `test/ui/pages/select_character/training_opponent_dialog_test.dart`; from `packages/runner_core`, retain `test/training/training_field_test.dart` and `test/training/training_death_animation_test.dart`; add stale picker/reset, loading failure, controls, timeout and background-resume coverage where missing |
| Editor lifecycle | From `tools/editor`, `test/authored_playtest_session_test.dart`, `test/editor_home_playtest_shortcut_test.dart`, all three page integration targets; cover accepted edits, source/controller/target replacement during modal/capture, Retry and frozen Restart |
| Editor scenarios | From `tools/editor`, `test/chunk_playtest_preparation_test.dart`, `test/chunk_playtest_editor_integration_test.dart`, `test/level_playtest_editor_integration_test.dart`, relevant `test/campaign_authoring_test.dart` cases; verify scenario identity, seed, source pools, equipment and captured assets |
| View and devices | Root `test/playtest/runner_chunk_playtest_host_test.dart`, `test/playtest/runner_playtest_display_frame_test.dart`, `test/ui/game_viewport_test.dart`, `test/ui/hud/game/hud_layout_test.dart`; editor `test/playtest_launch_dialog_test.dart` and `test/display_calibration_test.dart` cover calibrated-size/profile/overflow math and transformed input cases |
| Isolation and compatibility | Retain Developer Practice no-recording assertions and product submission tests when workflows move. Verify root/native and web compilation surfaces; the editor still consumes the tooling barrel without production service bootstrap |

Use `flutter test --no-pub <affected targets>` and targeted `dart analyze` from the
root or `tools/editor` as appropriate. Run package Core checks from their package
directory if factories/default contracts change. If authored-runtime admission
changes, verify generated freshness with `dart run tool/generate_chunk_runtime_data.dart
--dry-run` and relevant generator tests. Geometry/navigation changes require the
[traversal workflow](../../.agent/workflows/test-level-traversal.md); this cleanup
does not authorize changing geometry to obtain a pass. Do not run simultaneous
commands that write the same build outputs.

New tests should exercise behavior through public seams and real Core where
relevant. Use fakes for delayed recorder/network failures, not as evidence of real
rendering or capture. Preserve existing test factories and avoid test-only runtime
branches. Validate representative narrow/wide phones and a tablet; all presets
still get metadata/form/unit checks without multiplying every expensive case.

Manual acceptance includes Windows Play/F5 for all three editor modes, every
movement style, HUD off, keyboard input, pause/resume/stop/restart and calibration.
Measure a known reference and at least one real device screen or ruler: target
error at most 1 mm per 100 mm of measured preview length, including calibration
and preset precision. Record monitor/resolution, OS scaling, profile and device
metadata. Check window resize and overflow without a size jump. Use two calibrated
monitors if available, including moving and straddling; otherwise leave that check
open. Device metadata too imprecise
for the tolerance must be corrected or explicitly excluded from calibrated presets.

Also smoke-test actual mobile gameplay and Training Field, plus desktop/browser
controls, because a calibrated editor preview cannot prove native lifecycle,
cutout, haptic or performance behavior. Record local/mocked/native evidence
separately, including source state, command, result and remaining checks.

## Completion and implementation handoff

Implementation is complete when all milestone gates pass and the affected paths
contain no parallel implementation of shared mechanics. Each mode retains the
behavior in the scope table, all three editor modes use the same launch/preview
pipeline, and actual-size claims have physical evidence. TDDs describe the delivered
ownership and public APIs; this checklist records only execution and acceptance.

The user authorized implementation of all milestones, with this plan adapted as
evidence is collected. Release, backend mutations and unrelated repository cleanup
remain outside the task.

### Execution evidence

The original working-tree files are retained under ignored
`build/shared_runtime_baseline/` for task-diff review. Existing uncommitted content
and UI changes remain in place. Test output goes under ignored `build/`; evidence
below distinguishes completed checks from pending acceptance.

- M1 editor baseline: `flutter test --no-pub test/authored_playtest_session_test.dart
  test/chunk_playtest_preparation_test.dart test/chunk_playtest_editor_integration_test.dart
  test/level_playtest_editor_integration_test.dart test/campaign_playtest_dialog_test.dart
  --reporter expanded` from `tools/editor`: 36 passed, six failed. The first
  sandboxed invocation never reached compilation because
  Flutter's external SDK cache was unavailable and was canceled. The retry uses
  SDK access. No results from the canceled invocation count as a test baseline.
- M1 repairs: Level terrain now uses the same admitted runner pool as its patterns;
  all captured source still receives structural validation. The selected-owner test
  derives expected keys from the repository fixture, and the theme-group dropdown
  handles long labels at sidebar width. Re-running the three affected editor test
  files above with `--concurrency=1` passed all 25 tests, including the unchanged
  five-second preparation threshold. No geometry, pool validation or timing limits
  were weakened. Root generator `dart run tool/generate_chunk_runtime_data.dart
  --dry-run` passed (166 chunks, three levels/themes/materials).
- Root baseline: `flutter test --no-pub test/ui/run/runner_run_session_test.dart
  test/ui/runner_game_widget_startup_test.dart test/ui/runner_game_widget_desktop_test.dart
  test/ui/runner_game_widget_ghost_test.dart
  test/ui/pages/select_character/loadout_setup_page_phase4_test.dart
  test/playtest/runner_chunk_playtest_host_test.dart --reporter expanded`: 55 passed.
- M2: the same root host targets except the unchanged session test, plus
  `test/ui/input/runner_gameplay_bindings_test.dart` and
  `test/ui/input/desktop/runner_desktop_input_adapter_test.dart`: 69 passed.
  New real-Core tests prove touch/desktop timeout preserves movement, rejects a
  late release, clears queued input on full cancellation and detaches feedback
  after retirement. One initial assertion expected a zero movement field; the
  canonical neutral frame omits that field, so the assertion now requires null.
  Targeted analysis of the five changed runtime/UI files passed.
- Plan adjustment: input characterization accompanies the M2 extraction; delayed
  recorder characterization accompanies M3's focused operation owner. Native
  monitor verification stays with M5, where the adapter and calibration UI can be
  exercised together. These remain explicit unchecked gates above. Milestone
  changes stay uncommitted while dependent pre-existing edits are interleaved;
  committing entire files would absorb unrelated work.
- Display feasibility: Flutter exposes display identity, pixel size and DPR, not
  measured centimetres. A Windows editor adapter will supply monitor bounds and
  profile identity; calibration supplies pixels/mm. Profile resolution and native
  geometry verification remain M1/M5 requirements. Manufacturer sources distinguish
  the nominal screen rectangle from the rounded visible region.

- M3: root `flutter test --no-pub test/ui/run/run_replay_finalization_test.dart
  test/ui/run/runner_run_session_test.dart test/ui/runner_game_widget_startup_test.dart
  test/ui/runner_game_widget_desktop_test.dart test/ui/runner_game_widget_ghost_test.dart
  test/ui/pages/select_character/loadout_setup_page_phase4_test.dart
  test/playtest/runner_chunk_playtest_host_test.dart --reporter expanded`: 57 passed.
  Delayed finalization retains immutable identity after disposal and recorder close
  waits for the pending journal. Runtime construction and editor lifecycle now
  have one owner per attempt.
- M4 first regression run: 48 passed, two failed. One obsolete banner expectation
  was addressed by placing the tooling label outside the device; a real control-
  switch disposal regression was fixed by reparenting the keyed GameViewport.
  Follow-up confirmed control switching; two device tests still assumed window
  fitting and are being updated to fixed-size/overflow expectations.
- M5 uses a narrow Windows method channel for monitor device-interface identity,
  physical monitor bounds, orientation and Flutter client origin. Calibration is
  stored separately under LOCALAPPDATA/LothringenEditor; remote/unidentified
  displays require session confirmation. Native build and physical measurements
  are still pending. Source capture is now preceded by the same modal in all
  three editor pages, fenced by accepted source, controller, workspace and target.


### November 12 verification checkpoint after memory exhaustion

Historical checkpoint: implementation files remained in the working tree. Heavy
checks were serialized after the crash, with Flutter tests at `--concurrency=1`.
The user later removed the unnecessary Java discovery and authorized parallel
work. Independent light checks can overlap; memory headroom still limits builds.
Preserve the user's existing work and applications.

Completed local evidence after the earlier milestones:

- Root input/display targets: 77 passed (`build/shared_runtime_input_display.log`),
  including semantic action modes, desktop/touch controls, fixed preview sizing,
  transformed input and shared cancellation.
- Product/Training/replay/viewport/HUD targets: 49 passed, with the new runtime
  ownership test initially failing compilation because its fixture omitted the
  required character. The corrected ownership target passed both tests separately
  (`shared_runtime_final_hosts.log`, `shared_runtime_ownership.log`).
- Root editor host recheck: all 14 passed (`shared_runtime_host_recheck.log`),
  including unresolved-presentation start/resume blocking, movement modes, shield,
  frozen restart and rapid disposal.
- Editor session/calibration/Chunk/Level workflow targets: 18 passed
  (`shared_runtime_m5_workflows.log`). The later Campaign/Home recheck passed
  those targets; the combined run had 31 passes and one calibration-profile
  dropdown failure (`shared_runtime_editor_recheck.log`). That real defect was
  fixed by separating session confirmations from persisted profiles.
- The next calibration target passed all six tests, including profile reuse,
  persistence and DPI invalidation. The session test then missed an off-screen
  Calibrate button at 800x600; it now scrolls the button into view. That fix and
  the nested-modal retirement assertion still require a rerun. The final launch
  target was loading when checks were interrupted
  (`shared_runtime_editor_calibration_final.log`).
- Core scenario/Training targets: 32 passed (`shared_runtime_core.log`). A new
  VM-only compiled-Campaign/editor construction parity target is written but
  **unrun**: `test/playtest/campaign_construction_parity_test.dart`, both
  characters, seed 42, 360 ticks, exact event data and full snapshot data with
  only registered/authored level provenance excluded. This is not route coverage.
- The Windows release editor built successfully before the final calibration
  fixes (`shared_runtime_editor_windows.log`). It needs an incremental rebuild
  after final validation; the existing executable is not the final source state.
- Final targeted root analysis reports no issues
  (`shared_runtime_root_analysis_final.log`). Editor analysis has no completion
  result. The web-build log has no result; do not count either as passing.

At the user's crash report, no agent-started Dart test/analyzer/build process
remained. The active Dart language server belonged to the reopened VS Code.
Windows reported about 0.4 GB free physical RAM of 15.4 GB. Two standalone
analyzers, editor tests and a web-build request had overlapped earlier and likely
added memory pressure; no Windows resource-exhaustion event was found to attribute
an exact culprit. These observations do not establish a gameplay memory leak.

Remaining M6 work: finish the targeted calibration/session/launch rerun, execute
the new parity test, complete editor analysis and instruction/link/diff checks,
review explicit damage/terrain and Training lifecycle coverage, and finish web
and updated Windows builds sequentially when memory permits. Complete the final
ownership/duplication review against `build/shared_runtime_baseline/` and reconcile
all checklist gates before marking code acceptance complete.

Native visual automation was unavailable because the Computer Use native pipe
could not connect. No native interaction was performed. Ruler verification,
monitor-switch/straddling checks and real mobile/Training smoke tests remain open.
The user was told calibration means measuring the reference line with a real ruler
and entering its length in millimetres; no measurement result has been supplied.


### Resumed verification after extension cleanup

The user confirmed cleanup and authorized parallel work. Independent checks
resumed with measured memory headroom; existing VS Code and the user's running
editor remained open. Validation remains local, using the uncommitted source.
`build/shared_runtime_final_sources.json` records SHA-256 hashes for 66 task files;
`build/shared_runtime_baseline/` preserves the starting edits for task-only review.
An encoding/link scan of those task files passed. An unrelated, unchanged archived
Willow verification file has legacy encoding and was left untouched.

New completed evidence:

- From `packages/runner_core`: `dart test
  test/playtest/campaign_construction_parity_test.dart --reporter expanded`:
  **2 passed**. Both playable characters, seed 42, run ID 77, 360 continuous ticks,
  complete event payloads every tick and snapshot fields at 0, 1 and every 60 ticks.
  Only registered/authored `levelIdentity` provenance is excluded; this is command
  parity for the same compiled mission, not navigation/traversal acceptance.
  Log: `build/shared_runtime_campaign_parity.log`.
- From `tools/editor`: `flutter test --no-pub --concurrency=1
  test/display_calibration_test.dart test/authored_playtest_session_test.dart
  test/playtest_launch_dialog_test.dart --reporter expanded`: 23 passed, one
  nested calibration regression. The first test correction moves the tap onto
  the real async store-loading clock; this then exposed the real route leak.
  Removing a covered setup route could defer its widget disposal, leaving the
  calibration child open. The session now explicitly retires both owned routes.
  Re-running session + launch targets passed **18 tests**; the six calibration
  tests remain passing and their implementation did not change beyond a lint fix.
  Logs: `shared_runtime_editor_calibration_resumed.log`,
  `shared_runtime_editor_session_resumed.log`, `shared_runtime_editor_session_fixed.log`.
- From the root: `flutter test --no-pub --concurrency=1
  test/ui/input/runner_gameplay_bindings_test.dart
  test/game_controller_terrain_readiness_test.dart
  test/playtest/runner_playtest_display_frame_test.dart --reporter expanded`:
  **21 passed**. Real Training combat damages an active charge without clearing
  movement or allowing late commit. A controlled terrain worker fails at a real
  streamed transition; retry preserves the attempt/tick and clears queued input.
  Device transforms preserve accessibility while replacing geometry/insets.
  Log: `build/shared_runtime_final_cancellation.log`.
- From the root: `flutter test --no-pub --concurrency=1
  test/ui/runner_game_widget_startup_test.dart
  test/ui/runner_game_widget_desktop_test.dart
  test/ui/pages/select_character/loadout_setup_page_phase4_test.dart
  --reporter expanded`: **33 passed**. Includes late opponent-picker completion
  after Training unmount on Android/Windows, both characters, reset/death timing,
  background resume, load failures, desktop scheme switches and restart. Final
  review tightened restart error/finally fencing and null-safe Training resume.
  Log: `build/shared_runtime_lifecycle_final.log`.
- `node tools/agents/check.mjs` passed (37 instruction files). Task-specific
  encoding/local Markdown target checks passed; no product tests were run for
  documentation-only edits.

The first resumed web release build was deliberately stopped with about 360 MB
free physical memory. Process inspection showed concurrent JavaScript compilation
and Flutter's optional WebAssembly compatibility dry run. This is not a failed
application test or evidence of a gameplay leak. A second attempt used `--no-wasm-dry-run --dart2js-optimization=O1`,
supported by the installed Flutter tool and its official
[Wasm documentation](https://docs.flutter.dev/platform-integration/web/wasm), to
avoid the second compiler and reduce optimization. Its JavaScript optimizer also
reached about 390 MB free RAM and was stopped, along with a newly pending targeted
test. Neither interrupted build counts as passing. No user-owned process was
stopped. The root web front end produced its 52,945,072-byte `app.dill` before
optimization, but this alone is not a complete deployable build. Browser smoke
tests are recorded separately below; optimized web release and WebAssembly
compatibility remain unverified.

### Audit disposition

| Findings | Delivered owner / evidence |
| --- | --- |
| A1 disposal ownership | `RunnerGameplayRuntime`, idempotent Flame cleanup and stop-before-unmount retirement; construction/never-mounted/late-asset tests |
| A2 input inconsistency | `RunnerGameplayBindings`; shared semantic actions, separate movement epoch, timeout/damage/terrain regressions |
| A3 asynchronous results/restarts | Attempt-bound `RunReplayFinalization`, immutable captures, close ordering, restart fences; delayed journal and duplicate-event tests |
| A4–A5 Training policies/coverage | `TrainingFieldSession` and tab retain auto-start, picker/unlocks, safe areas, death/reset, lifecycle; real-asset Android/Windows cases |
| A6 product variants | Explicit product factories retain Campaign, runner, Practice and ghost policies; startup/desktop/ghost/session suites and public API review |
| A7 source/equipment | Admitted runner terrain pool and canonical starter loadout; Chunk/Level/Campaign preparation and shield assertions |
| A8 launch races | Session-owned setup and nested calibration routes; source/controller/target fences, single F5, frozen Restart and recapturing Retry |
| A9 distinct lifecycle policies | Each mode owns start/resume/readiness; shared cancellation and retirement mechanics only |
| A10 physical size | Sourced metadata, machine profiles, fixed-scale frame and native adapter implemented; ruler/multimonitor acceptance remains open |
| A11 geometry/environment | One shared surface, outer calibrated transform, preserved product safe areas and scoped preview accessibility; frame/aim/HUD tests |
| A12 parity | Separate shared-input coverage and exact equivalent-Campaign construction; no normalization of gameplay data |
| A13 modularization | Replaced constructors, subscriptions, viewport and journaling paths removed; task diff reviewed against baseline |
| A14 performance/import boundaries | One dispatcher/frame driver/render cache per attempt; bindings avoid per-tick notifier broadcasts; no editor I/O or account service enters runtime. Build evidence below remains distinct from device performance. |

No commits were made: task changes remain interleaved with the user's existing
uncommitted files. No backend, release or account mutations were performed.


Final review follow-ups:

- Setup restoration now compares both logical dimensions and physical diagonal
  before matching a preset. A custom screen with preset-sized logical pixels
  stays Custom and editable. From `tools/editor`, `flutter test --no-pub
  --concurrency=1 test/playtest_launch_dialog_test.dart --reporter expanded`
  passed **15 tests**, including this regression
  (`build/shared_runtime_launch_final.log`).
- Product/editor targeted analyses initially reported only two missing-braces
  style findings; both were corrected. Final focused rechecks report **No issues
  found** (`shared_runtime_root_analysis_clean.log`,
  `shared_runtime_editor_analysis_clean.log`). The broader root/editor analysis
  logs retain their original results rather than erasing the style findings.
- `flutter build windows --release --no-pub` from `tools/editor` passed in 357.9 s
  (`shared_runtime_editor_windows_final.log`). The later custom-screen restoration
  fix requires the final incremental rebuild below. The README now has one shared
  Play setup description; its obsolete Campaign fit-to-window wording was removed.

- Browser attempt: root `flutter test --no-pub --platform chrome --concurrency=1
  test/game/runner_gameplay_runtime_test.dart
  test/ui/input/runner_gameplay_bindings_test.dart
  test/playtest/runner_playtest_display_frame_test.dart --reporter expanded`
  compiled a test runner and launched isolated headless Chrome, but no test
  executed. Flutter reports that concurrency is ignored for web tests. The local
  server returned HTTP 404 for `/canvaskit/chromium/canvaskit.js` and `.wasm` even
  though both files exist in the installed SDK cache. Read-only headless-browser
  logs and a direct local request confirmed the 404s. Inspection points to the
  Windows path handling in Flutter's `flutter_web_platform.dart`; no SDK patch
  or renderer substitution was applied. The stalled test process tree was stopped.
  Log: `build/shared_runtime_chrome_smoke.log`. Browser runtime checks remain open.
- During the browser attempt, VS Code's existing Dart language server used about
  3.8 GB resident RAM. It and the user's live editor were left running. Java cleanup
  alone does not guarantee enough headroom for multiple Dart/Flutter compilers.
  Future optimized-web verification needs sufficient RAM; a browser test rerun
  additionally needs the local Flutter renderer-serving issue resolved.


### Final native checkpoint — November 12

- Final source: `flutter build windows --release --no-pub` from `tools/editor`
  **passed in 352.2 s**, including custom physical-screen restoration.
  Log: `build/shared_runtime_editor_windows_verified.log`.
  Executable: `tools/editor/build/windows/x64/runner/Release/runner_editor.exe`.
- `dart analyze lib/src/app/pages/shared/playtest_display_settings.dart
  test/playtest_launch_dialog_test.dart` from `tools/editor`: **No issues found**
  (`build/shared_runtime_custom_screen_analysis.log`).
- The equivalent-Campaign test explicitly declares VM-only execution because its
  complete-field projection uses reflection. Its final VM rerun passed both
  characters (`build/shared_runtime_campaign_parity_verified.log`); no application
  or Core production code imports reflection.
- The final task source/hash manifest and native executable/AOT hashes are in
  ignored `build/shared_runtime_final_sources.json` and
  `build/shared_runtime_final_artifacts.json`. Source encoding, local Markdown
  targets and task diff whitespace were checked after the final documentation edits.

Remaining work is precisely the unchecked M6 gates: optimized web/browser
verification in a suitable environment, plus native visual/ruler/multimonitor and
real-phone acceptance. No test failures are being counted as passes. Keep this
plan in `building/` until those gates have evidence.
