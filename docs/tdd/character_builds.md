# Character builds

Each character owns exactly three saved `{name, loadout}` entries and one
zero-based `selectedBuildIndex`. `SelectionState` schema 2 stores these under
`buildsByCharacter`; there is no global build name or second loadout map.
`loadoutFor(character)` resolves its selected entry, so Hub, builder, Training
Field and run preparation consume the same build. Names default to Build 1,
Build 2 and Build 3; they are trimmed, non-empty and at most 28 Unicode grapheme
clusters. Flutter's input limit and the Functions `Intl.Segmenter` validator
count the same user-perceived characters.

## Character retirement

Only `eloise` and `bountyHunter` are registered runtime characters. The removed
development identity `eloiseWip` cannot be selected, equipped, purchased for,
or used for new gifts. Saved selections restore Éloïse and discard the retired
build branch without replacing either remaining character's builds. Core/client
and backend meta readers union its earned skills/projectiles into Éloïse while
keeping current equipment, shared inventory, currency and progression intact.
Backend normalization is repeatable and does not itself advance the revision;
the next normal canonical write deletes obsolete persisted character branches.
Retained inbox gifts preserve immutable identities and retry hashes while
crediting Éloïse; see [Admin compatibility](admin_tools.md#gifts-and-release-activation).

Replay/ticket character IDs remain exact strings: retired-character runs are not
reinterpreted as Éloïse or Willow. Roll out the matching client, Functions and
worker together under the coordinated compatibility workflow, draining any
outstanding retired-character tickets before worker cutover. This source change
does not deploy, reset accounts, cancel runs or activate the changed gift catalog.
[Local verification](../verification/eloise-wip-retirement-2026-11-11.md) records
the regression coverage and unrun release checks.

## Unlock authority

Build indices 0/1/2 require account levels 1/5/12. Client controls and AppState
use canonical `progression.playerProgress`, never optimistic reward-display XP.
Functions derives that level from settled total XP and rejects locked selections,
locked individual edits, and whole-selection changes to locked inactive builds.
Run issuance checks the chosen index again before authorizing its loadout and
binding the existing ticket snapshot. There is no replay/ticket wire change.

Developer Practice shows the same locks. Its isolated profile earns no XP and
therefore remains at level 1. Bootstrap normalizes a locked persisted selection
to Build 1 without discarding the other saved entries. Catalog gear and skills
remain available for testing in Build 1. Each slot is normalized independently.

## Saving and ordering

Equipment, ability, projectile and full-loadout commands include an explicit
`buildIndex`; queued coalescing keys include character, index and equipment or
ability slot. Delayed delivery cannot target a newly selected build. A build
switch or rename flushes earlier edits before saving the complete selection;
failed delivery prevents the transition. Renaming retains the original build
identity through that flush. Rejected selection writes surface an error rather
than opening the builder or closing the rename dialog as a success.

`meta.equippedByCharacter` is the projection of each character's selected build.
Functions recomputes it after full-loadout, gear and selection changes, including
when editing an inactive slot. Inventory/ability ownership, command revisions,
UID authentication, idempotency and account deletion remain with existing owners.
The ownership command envelope allows depth 9 for the extra build/loadout
nesting; all shared byte, node, key, string and array ceilings remain unchanged.

## Menus and schema boundary

The chooser keeps two cards in one landscape viewport and stacks them on narrow
portrait screens. Character art/name occupy the left column; three build rows
occupy the right. Available characters remain undimmed. Gold framing identifies the selected character;
only its active build has a checked selector and Active build label. There are
no role subtitles, build-list heading, repeated slot/last-used subtitles,
Select/Selected/locked-name footer controls, or next-run summary. Card heights
retain the previous footer allowance. Edit controls show only the pencil icon,
with full character/build tooltips and accessible action labels.
Locked rows state their required account level and cannot select or edit.

Character taps select the remembered build. Build-row taps select that character
and slot in place after saving; their separate Edit actions open the builder
without changing either character's remembered slot or the next-run selection.
Selection errors retain the canonical choice and expose a retryable message.

`LoadoutSetupArgs` pins the editor's character/index for its route lifetime.
Legacy route entries without arguments pin the current selection on entry.
Gear, ability, projectile and rename commands accept an optional explicit index;
omitting it retains the remembered-slot behavior. Locked indices are rejected
before optimistic mutations. Editing inactive gear does not change the
character's equipped-meta projection. The existing addressed wire commands and
selection schema are unchanged. Build activation stays on the chooser through
the existing flush-before-selection boundary.

The editor retains its original centered Gear/Skills/Training Field tabs and
rename presentation: the localized default name beside a pencil, or the custom
name as the rename control. Rename still addresses the edited build and has Save/Cancel, keyboard submission,
validation, a busy state and retryable errors. Gear/Skills failures offer a retry
that flushes the original addressed edit. Both app-bar and system Back return to the chooser;
Back from the chooser returns to the hub.

Gear and Skills keep their widget subtrees mounted while switching builder
tabs, retaining the selected slot, inspected item/ability and scroll positions.
The Skills list starts at the bottom after its initial layout and when changing
ability slots. Inspecting abilities and switching builder tabs preserve manual
scrolling.
Hidden editors disable tickers and focus and keep their viewport size when the
app bar overlays Training Field. This browsing state lasts only for the builder
route and edited character/build; it is not persisted in the saved build. Training
Field mounts only while selected, tests the addressed editor build without
activating it, and creates a fresh session on every return.

The builder does not shrink behind the modal keyboard. On short landscape
viewports the input and actions share a row so the editable name remains visible.

This is a pre-release schema replacement, without a migration layer. Local
schema-1 selections fall back to fresh defaults. Outbox envelope version 4
ignores obsolete commands without a build identity, retaining current queues
and account isolation. Backend profiles must be freshly created/reset when this
contract is rolled out; this local change does not reset remote data or deploy.
The producer-generated run-completion fixture carries schema 2 through the
existing Dart canonical-state decoder.
