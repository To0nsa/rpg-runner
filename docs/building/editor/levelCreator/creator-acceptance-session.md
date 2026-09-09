# Level Creator acceptance session

Status: Prepared; independent creator observations pending.

Use this session with a game creator who did not implement the editor. Familiarity
with chunks, Prefabs, groups, layers, and placement tools is expected. This is a
workflow assessment, not a beginner tutorial. Automated evidence is recorded in
[implementation verification](implementation-verification.md).

## Prepared workspace

The September 9 session workspace is `.tmp/level-creator-acceptance`, a detached
checkout of implementation revision `4c8c92e8`. Its authoring files and generated
outputs are independent of the main checkout. Open
`.tmp/Open Level Creator acceptance.lnk`, then choose Level Creator. The shortcut
starts the release editor with this
checkout as its working directory. Keep this checkout until observations and
any authored examples have been reviewed; do not reset it between tasks.

A facilitator provisions the SDK, dependencies, existing image assets, and
workspace. The participant performs the tasks inside the editor. Build changes
local generated content; this session does not publish a game release.

Record the actual editor revision, Windows version, display size/scaling,
participant's authoring experience, and session date. Record elapsed time from
opening Level Creator to the first running Level Play separately from loading
or preparation timings. Start with an ordinary desktop layout, then repeat the
most difficult interaction at 800×600 or increased text scaling.

## Participant tasks

Give the participant the objectives below without pointing out individual
controls in advance. Record hints, unclear labels, unexpected actions, and any
work they believe was lost. If they cannot proceed, preserve the current state
and record the blocker before helping.

| Task | Objective | Observation to record |
| --- | --- | --- |
| First playable level | Create an experiment with an independent background, add a flat starter, play it in Chunk Creator, return, and play the Level. | Time to first Level Play; understanding of the two Play scopes and unsaved changes. |
| Useful second chunk | Create another chunk, draw terrain, place an existing Prefab and a compatible enemy, activate it, and include it in the Level. | Discoverability of geometry, placement, activation, and return actions; whether both chunks appear in the sample/run. |
| Grouped flow | Put the chunks into two groups, configure ordered sections and repetition, then edit a source that appears more than once. | Understanding of group movement, difficulty fallback, section occurrences, and edits affecting every occurrence of a source. |
| Incomplete design | Save a distinct section that needs more content. Follow its diagnostic to add content and return without losing the section. Repeat with Copy section design. | Whether a saved incomplete design and a Play blocker are distinguishable; ability to recover without removing intended rules. |
| Empty a group | Move its last usable chunk to another group, then repair the resulting readiness issue. | Whether diagnostics identify the affected section/group and offer a useful next action. |
| Multi-level changes | Edit two levels and leave the domain. Try Cancel, Save all, and Discard all in separate attempts. Also leave one invalid field and discard only that edit. | Whether affected names match the participant's expectations and unrelated edits survive. |
| History and return | Save a section/value edit, Undo, Save, and Redo. Save a newly created level, then Undo. Leave/reopen the workspace and resume its saved starter. | Correct distinction between value history, persisted identities, handoff history, and saved-only reopening. |
| Shared appearance | Edit a shared background, identify the affected levels, then make an independent copy. | Whether the participant can predict which levels change. |
| Build an experiment | Exclude unfinished content, build finished content, restore the experiment, and resume its groups/rules. | Understanding of Saved, Ready to play, Included in build, and Built; actionable default/last-included-level errors. |
| Play lifecycle | Pause, lose application focus, resume, restart, resize, stop, and cancel preparation. | Focus behavior, input responsiveness, and whether editing context survives. |

## Facilitated recovery cases

The facilitator triggers these cases in the disposable checkout; the participant
uses the editor's recovery actions. They do not need to edit source files or use a
terminal. Keep the exact before/after source copies with the session record.

- Change a saved value externally while a compatible local edit is pending;
  repeat with both edits touching the same value. Observe reapplication and
  explicit conflict choices.
- Present a structurally invalid dependency while the origin has pending work.
  Exercise a failed repair-target load, a successful repair/return, conflicting
  return edits, refusal of nested repair, and closing with a retained origin.
- Interrupt starter creation before source commit, then after a successful Save.
  Reopen and resume; confirm no duplicate chunk and no lost saved level.
- Exercise the saved-files/refresh-failed state using the existing fault-injection
  regression harness, and review the resulting recovery action with the creator.
  Record this as a facilitated harness observation, not a naturally occurring
  disk failure or an independent end-to-end pass.

The automated fault coverage and limitations are documented in the verification
ledger. Do not claim a human observed a fault state merely because its regression
test passed.

## Session record and closure

No participant results have been recorded yet. For each task, retain:

| Field | Record |
| --- | --- |
| Outcome | Completed unaided / completed with hints / blocked |
| Duration | Elapsed time and pauses unrelated to the editor |
| Observation | Participant's words and the exact action/state |
| Evidence | Screenshot or retained authored example, when useful |
| Follow-up | Reproducible defect, wording/layout improvement, or no change |

Turn reproducible findings into focused fixes and rerun the affected checks.
Update the [Phase 6 checklist](ui-ux-redesign-checklist.md#phase-6--author-acceptance-and-closure)
with actual observations. Archive the Level plan only after the creator session
and its required fixes are complete.
