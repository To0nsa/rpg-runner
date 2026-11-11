# Item authoring

The editor's Items route creates, duplicates and edits player equipment in the
existing weapon, accessory, spell-book and projectile categories. Weapons include
primary and offhand equipment. Skill definitions, new mechanics, new equipment
families, internal enemy/NPC projectiles and artwork creation remain code-owned.

## Source and authority

`assets/authoring/items/item_defs.json` is the single authored source for item
definitions, English/French names and canonical art assignments. Schema 1 stores
category, stable ID, explicit enum ordinal, names, icon and category-specific data.
Projectiles also select an existing render/muzzle profile of the same family.
Reserved internal projectile IDs retain their original enum positions in the
source manifest; their definitions remain Core-owned Dart.

`runner_content_pipeline/item_source.dart` strictly decodes source strings without
repository I/O. Its closed field schema covers existing Core constructors, stat
bonuses, proc hooks/profiles, per-effect tuning, projectile physics and equipment
family/slot fields. Missing optional fields inherit Core constructor/profile
defaults; explicit zero/false remain overrides. Validation rejects unknown fields,
nonfinite/out-of-range numbers, duplicate/reserved IDs, invalid art references,
unsupported family/slot combinations and tuning for effects absent from a profile.
Canonical art membership is supplied by callers from `game_presentation`.

Core retains gameplay semantics, status presets, runtime caps and character
equipment policy. The compiler and editor call `CharacterEquipmentPolicy`'s
family APIs, also used by runtime identity checks. They do not maintain a second
character eligibility table. Gear ownership is account-wide; equipment eligibility
is character-specific. Projectile ownership is character-specific. Neither the
editor nor its eligibility preview grants ownership or equips a character.

`tool/item_generation.dart` emits typed Core enums and definition maps, plus
`game_presentation/items.generated.dart`. Core catalogs resolve those maps;
there is no second handwritten copy of player item definitions. Canonical art IDs
and their atlas/image mappings remain in `game_presentation`, independent of which
items use them. New projectile identities reuse Core render profiles, render
scales, character variants and muzzle mappings while retaining their own physics.
Existing localized descriptive prose remains in shared presentation ARBs; new
items fall back to their translated name, with gameplay details derived from Core.

## Identity and saved-loadout compatibility

Enum indexes are persisted in gameplay/replay data. Generation preserves every
existing ID, serialized name and ordinal, and appends new identities after all
existing ordinals, including internal projectile entries. Source ordering is
canonical by category and ordinal. The backend exporter retains its established
slot/category ordering because retained gift activation hashes depend on it.

The editor has no delete or rename command. IDs, categories and ordinals are
read-only after creation. Duplicate allocates an unused ID and a new ordinal.
Reserved language/enum members and retired `ironBracers`/`eloiseWip` identities
cannot be reused. Existing retirement/retained-gift readers remain unchanged.

Ordinary authoring rejects changes to a saved item's equipment family, slot or
two-handed occupancy, even when the item has not yet shipped. These can invalidate
saved loadouts or ability compatibility. Duplicate into a new identity to change
them; names, icons, stats and effects can still be edited. Generation checks the
same identity/eligibility constraints against compiled Core, so external source
edits cannot bypass them. Undo cannot erase/recycle a persisted new identity.

This is a rejection policy, not an account migration. A future change to Core's
eligibility policy or an existing identity's family requires separately designed
saved-loadout compatibility and release work. Never infer authorization to drop
ownership, rewrite builds, retire identities or migrate accounts from a source edit.

## Save, history and Build

`ItemDomainPlugin` owns source loading, unique identity allocation, semantic edits,
validation, history reconciliation and export. The page buffers visible fields and
participates in shared Save/Undo/navigation guards. Invalid input remains visible;
Save validates it before dispatch/export. Category-specific controls select existing
enum/effect values, with an explicit inherited/default option. The library, form
and eligibility/art preview use the shared responsive panel layout.

Save compares the exact loaded bytes with current source before staging and again
before replacement, then uses `WorkspaceWriteTransaction`. Conflicts retain the
draft. Failed replacement rolls back; partial recovery and committed cleanup
outcomes use the session's existing recovery path. Undo after Save keeps the latest
disk baseline rather than resurrecting stale bytes.

Save writes source only. The shell's Build includes items in
`generate_chunk_runtime_data.dart`'s captured-input transaction. It publishes all
item enums, definitions, presentation mappings and the Functions catalogue together
with other generated content. Input-set/byte drift, cancellation and safe
multi-file replacement retain the existing [Build contract](editor_content_build.md).
The shell watches item source and canonical art inputs and distinguishes local
draft changes, saved source and generated freshness.

The focused offline command is `dart run tool/generate_item_data.dart` (also
`corepack pnpm catalog:generate`); `--check`
renders and compares without writes. Both paths reuse `generate_backend_catalog.dart`.
For the atomic build, the exporter accepts validated authored descriptors before
new enums exist in that process, deriving eligibility from the same Core policy.
Its normal standalone check derives the compiled Core catalogue. Tests require
both paths to agree exactly after compilation.

New items need no handwritten backend IDs, slot lists or eligibility entries.
Backend prices, purchase rules, reward quantities, authentication, revisions,
ownership grants and settlement remain backend authority. Functions runtime reads
only checked-in generated TypeScript; it never runs Dart or reads repository sources.

Restart/rebuild the editor and Admin after Build to load new compiled identities.
Campaign and Admin use `GameCatalogItem` and the same `CatalogGiftPicker`. Refresh
the Admin service catalogue/fixture when deliberately changing membership; restart
its local service as needed. Existing running Dart processes cannot hot-load new
enum members merely by refreshing a list.

## Verification and release

`test/tool/item_migration_test.dart` locks the original effective definitions,
ordinals, starter state and rendered backend bytes to a pre-migration digest.
Generation integration tests add one item per category in an isolated repository,
check deterministic output and read-only drift failure, compile Core/presentation,
and exercise both shared-picker input paths. Editor tests cover creation,
duplication, edit/reload, invalid inputs, immutable/retired IDs, eligibility changes,
source conflicts, rollback and persisted-identity history. Existing backend tests
retain gift retry/activation hashes and once-only campaign settlement checks.

Use `corepack pnpm catalog:check` and the normal content Build freshness gate before
release. Gameplay item changes follow the coordinated
[release workflow](../../.agent/workflows/deploy-release.md), including compatibility
version/evidence decisions and matching client, issuer and validator artifacts.
Generation is local preparation and does not authorize deployment or account changes.
The [active checklist](../building/campaign/implementation.md#item-authoring-follow-up)
records local results and limitations.
