# Campaign: Val Outpost

Status: campaign systems implemented locally November 11, 2026. See the
[current contract](../../tdd/campaign_runtime.md), [game behavior](../../gdd/campaign.md)
and [acceptance checklist](implementation.md). The user owns production layouts;
all four remain excluded drafts. Deployment and account resets are not authorized.

## Outcome

Introduce campaign chapters containing finite, hand-authored missions. The first
chapter takes place at Val Outpost and introduces the game through play without
being named or presented as a tutorial. Players can move freely in both
directions, with the camera following them.

The campaign reuses the existing deterministic Core, terrain/chunk content,
combat, renderer, editor foundations, and verified reward pipeline. Its finite
world and completion rules become explicit contracts in those owners.

The user places these events after chapter 3, **Le feu de joie**, of the
roleplaying scenario **Les Soleils d'or**. Cultists have been seen at several
locations, and Val Outpost calls the player for help dealing with them. This
session-provided premise governs the chapter; unprovided scenario events are
not inferred from the chapter title.

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
- The opening chapter contains four missions, teaching through play.
- These missions have no forced runner scrolling. Movement and camera following
  work in both directions throughout their traversable routes.
- Chunk distribution is authored explicitly, without random chunk selection.
  The editor must support assembling complete missions from reusable chunks.
- Mission one, **Reporting for Duty**, crosses the Forêt des Moyen-Ducs to arrive
  at Val Outpost. It introduces movement and jumping, with no encounters. Its
  source direction is Forest `rocky_grove` easy/normal, ending in `trainingcamp`.
- Mission one's completion unlocks Double Jump and grants the earned XP and gold.
  Its arrival route must therefore be completable with the initial basic jump.
- Willow is locked until the first campaign chapter is completed; completing
  all four missions unlocks her as a playable character.
- A new player's intended first pass through the four missions targets the start
  of account level 3: 224 cumulative XP under the current progression curve.
- The user will author the actual level layouts by hand. Exact chunk selection
  and geometry are not required now; tooling and small technical fixtures come first.
- The editor includes a chunk converter that duplicates layouts from runner to
  campaign and from campaign to runner, preserving the source and validating the
  new copy for its destination mode. Supported encounter content is copied too;
  the user edits the duplicate afterward, including removing encounters for
  Reporting for Duty. The converter has no encounter-removal option or preset.

## Implementation defaults and limits

Editable missions two through four are Signs in the Grove, The Supply Trail and
Holding the Outpost, using the cultist premise. Their layouts remain to be authored.
A fresh account begins with Éloïse; Willow becomes
available after chapter completion and for subsequent replays. Keep personal best
scores and once-only unlock rewards. Retain mission state for the entire attempt;
restart begins a fresh attempt. Replaying completed missions is supported.

Interpret Double Jump's initial reward as Éloïse's existing `eloise.double_jump`;
granting Willow's separate version is not yet specified. First-clear XP defaults to 40/48/60/76; accepted attempts keep collected
gold. The 224-XP budget
assumes a fresh account at level 1 with zero XP and the intended first-clear reward
collection; retries and other activities are not an account XP cap.

The first delivery does not include branching campaign paths, a general dialogue
engine, mid-mission save/resume, checkpoints, co-op, campaign leaderboards, or
cross-session world persistence. These are scope defaults, not user prohibitions.
Moment-to-moment combat can retain deterministic randomness; mandatory encounters
and teaching resources must not depend on spawn luck.

## Baseline inspected

The initial planning task started on clean source `1b8a77e2`; the user-directed
story/progression/converter revision starts from clean planning commit `c45d796f`.
No unrelated worktree or staged edits were present. Recheck both on resume; this
is an inspection baseline, not a frozen release candidate or a claim about
deployed behavior.

Current [Level Creator](../../tdd/editor_level_workspace.md) orders sections but
still selects chunks within them. Its non-looping setting continues the final
section. [Training Field](../../tdd/training_field.md) sets automatic camera speed
to zero but retains forward following and is a disposable, unrewarded local mode.
At planning time the normal streamer discarded old chunks and terminal reasons
covered failure/abandonment. Campaign now has separate finite lifetime and success
contracts; this section records the inspected baseline.

The [existing regional map](../../../lib/ui/pages/library/location_map.dart)
supplies artwork and anchors, but its Library unlock logic is not campaign
progression. The [hub](../../../lib/ui/pages/hub/play_hub_page.dart) currently
wraps fixed-size cards. [Reward settlement](../../tdd/reward_settlement_operations.md)
already provides verified grants, canonical revisions, and retry recovery.
Current [player progression](../../gdd/player_progression.md) starts at level 1
and requires 100 then 124 XP for levels 2 and 3. Current
[Willow ownership](../../tdd/willow.md) has no campaign character gate; this plan
adds that ownership/admission work rather than treating a disabled UI card as a lock.

## Next action

When implementation is requested, start M0 in the [implementation checklist](implementation.md):
settle the source/wire contracts and finite-world lifetime policy, then build the
small return-trip test fixture before integrating the user's authored missions.
