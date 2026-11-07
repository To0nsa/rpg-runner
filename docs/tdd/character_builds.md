# Character builds

Each character owns exactly three saved `{name, loadout}` entries and one
zero-based `selectedBuildIndex`. `SelectionState` schema 2 stores these under
`buildsByCharacter`; there is no global build name or second loadout map.
`loadoutFor(character)` resolves its selected entry, so Hub, builder, Training
Field and run preparation consume the same build. Names default to Build 1,
Build 2 and Build 3; they are trimmed, non-empty and at most 28 Unicode grapheme
clusters. Flutter's input limit and the Functions `Intl.Segmenter` validator
count the same user-perceived characters.

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

The chooser keeps two cards in one viewport. Art/name occupy the left column;
three build buttons occupy the right. Unlocked buttons show the saved name;
locked buttons show a centered lock icon and required level together inside the
button instead of the name. Card taps select in place, unlocked build buttons
save and open the builder, and locked buttons consume taps. The selected
character retains the level-selector scrim behavior. Builder actions show the
current build name and edit icon. Rename has Save/Cancel, keyboard submission,
validation, a busy state and retryable errors.

Gear and Skills keep their widget subtrees mounted while switching builder
tabs, retaining the selected slot, inspected item/ability and scroll positions.
Hidden editors disable tickers and focus and keep their viewport size when the
app bar overlays Training Field. This browsing state lasts only for the builder
route and selected character; it is not persisted in the saved build. Training
Field mounts only while selected and creates a fresh session on every return.

The builder does not shrink behind the modal keyboard. On short landscape
viewports the input and actions share a row so the editable name remains visible.

This is a pre-release schema replacement, without a migration layer. Local
schema-1 selections fall back to fresh defaults. Outbox envelope version 4
ignores obsolete commands without a build identity, retaining current queues
and account isolation. Backend profiles must be freshly created/reset when this
contract is rolled out; this local change does not reset remote data or deploy.
The producer-generated run-completion fixture carries schema 2 through the
existing Dart canonical-state decoder.
