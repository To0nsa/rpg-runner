# Campaign: Val Outpost

Status: proposed implementation, documented November 11, 2026. No campaign
runtime, editor, progression, or UI changes have been implemented by this plan.
The current request authorizes preparing this planning folder. Deployment and
account/data changes remain separate from implementation.

## Outcome

Introduce campaign chapters containing finite, hand-authored missions. The first
chapter takes place at Val Outpost and introduces the game through play without
being named or presented as a tutorial. Players can move freely in both
directions, with the camera following them.

The campaign reuses the existing deterministic Core, terrain/chunk content,
combat, renderer, editor foundations, and verified reward pipeline. Its finite
world and completion rules become explicit contracts in those owners.

## Documents and tracking

| Document | Purpose |
| --- | --- |
| [Implementation](implementation.md) | The only progress checklist; dependencies, milestones, acceptance gates, and resume checkpoint |
| [Architecture](architecture.md) | Mission identity, finite world, backtracking state, objectives, replay, and account authority |
| [Authoring](authoring.md) | Source ownership, reusable chunk instances, mission workspace, compiler, and publication |
| [Experience](experience.md) | Main menu, campaign map, mission selection, introductory chapter, and proposed tuning |
| [Validation](validation.md) | Behavior matrix, traversal evidence, regression coverage, and release acceptance |

Supporting documents describe the intended design; they are not additional task
ledgers. Update implemented TDDs/GDDs alongside each delivered milestone. Keep
remaining work here until completion, then archive the folder with repaired links.

## Confirmed requirements

- Campaign has its own main-menu card, beside Level Selection and Character
  Selection. All three stay on the same row and fit the available screen width.
- The card shows the regional map zoomed around Val Outpost.
- Opening Campaign shows the regional map with a clickable Val Outpost location.
- Selecting Val Outpost opens its mission selection, with the first mission
  accessible immediately. Missions have their own titles, rewards, and scores.
- The opening chapter contains three or four missions, teaching through play.
- These missions have no forced runner scrolling. Movement and camera following
  work in both directions throughout their traversable routes.
- Chunk distribution is authored explicitly, without random chunk selection.
  The editor must support assembling complete missions from reusable chunks.

## Proposed baseline and limits

Plan around four short missions; final count and names remain content decisions.
Use the selected character/build, objectives achievable with both starter builds,
linear completion-based unlocking, personal best scores, and once-only first-clear
rewards. Retain mission state for the entire attempt; restart begins a fresh
attempt. Replaying completed missions is supported.

The first delivery does not include branching campaign paths, a general dialogue
engine, mid-mission save/resume, checkpoints, co-op, campaign leaderboards, or
cross-session world persistence. These are scope defaults, not user prohibitions.
Moment-to-moment combat can retain deterministic randomness; mandatory encounters
and teaching resources must not depend on spawn luck.

## Baseline inspected

The documentation task started on clean source `1b8a77e2`. No unrelated worktree
or staged edits were present. Recheck both on resume; this is an inspection
baseline, not a frozen release candidate or a claim about deployed behavior.

Current [Level Creator](../../tdd/editor_level_workspace.md) orders sections but
still selects chunks within them. Its non-looping setting continues the final
section. [Training Field](../../tdd/training_field.md) sets automatic camera speed
to zero but retains forward following and is a disposable, unrewarded local mode.
The normal streamer discards old chunks; Core's terminal reasons currently cover
failure/abandonment rather than successful mission completion.

The [existing regional map](../../../lib/ui/pages/library/location_map.dart)
supplies artwork and anchors, but its Library unlock logic is not campaign
progression. The [hub](../../../lib/ui/pages/hub/play_hub_page.dart) currently
wraps fixed-size cards. [Reward settlement](../../tdd/reward_settlement_operations.md)
already provides verified grants, canonical revisions, and retry recovery.

## Next action

When implementation is requested, start M0 in the [implementation checklist](implementation.md):
settle the source/wire contracts and finite-world lifetime policy, then build the
small return-trip mission before authoring the complete chapter.
