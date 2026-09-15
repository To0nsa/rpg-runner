# Content authoring readiness

## Decision boundary

Entity authoring and source-format selection are deferred to a separate future
work pipeline. The [Core hardening plan](../../building/runnerCoreHardening/plan.md)
will only establish stable runtime contracts; it will not prototype JSON, select
a source syntax, generate catalogs, or build editor creation workflows.

This audit's format and workflow discussion is retained as future research
input, not accepted architecture or scheduled work.

Do not expand direct Dart AST patching into a full entity creation system, and
do not make loose data files loaded at runtime the simulation authority.

The existing terrain workflow is the pattern:

```text
authoring record
    -> schema + semantic + cross-reference validation
    -> canonical ordering and deterministic generation
    -> typed, immutable runtime bundle + content signature
    -> Core / Flame / UI / validator data-only projections
```

This keeps Core pure Dart, makes editor errors actionable, produces reviewable
repository diffs, and gives the replay validator an exact content identity.

## Current readiness matrix

| Content | Current authority | What the editor can do now | Blocking work before “create” is honest |
| --- | --- | --- | --- |
| Levels | JSON level descriptors plus generated registry | Existing level/terrain tools | Preserve current generator contract |
| Terrain/chunks/prefabs/materials | Repository-authored JSON and generated Core artifacts | Broad authoring support | Not part of entity migration |
| Projectiles | Dart enum, Core simulation catalog, separate Flame/UI/backend facts | Edit collider/render anchor/scale for known entries | Schema, stable ID, render facet, reference validation, generated consumers |
| Enemies | Dart enum/catalog plus abilities, tuning, concrete-ID system branches | Edit collider/render fields for known entries | Behavior capabilities, spawn/navigation policy, stable statistics protocol, generated consumers |
| Players | Dart character definition/catalog/tuning plus UI/backend defaults | Edit collider/render/cast origin for known entries | Generic traversal policy, animation/loadout references, backend existence projection, lifecycle state |
| Abilities | Typed Dart definitions split by character/enemy | No complete authoring flow | Explicit validator, injectable catalog, declared special policies; initially reference-only |
| Weapons/accessories/spell books | Typed Dart catalogs plus store/ownership metadata | No complete authoring flow | Explicit validation and generated reference indices; pricing stays backend-owned |

## Why the current AST editor is transitional

The current Entities route knows fixed Dart source shapes and edits selected
numeric fields. That is useful for visual collider/anchor iteration, but full
creation would require it to:

- synthesize enums, imports, constants, maps, switches, and cross-layer files;
- infer which concrete-ID branches a new enemy needs;
- update enum-indexed protocol semantics;
- distinguish gameplay changes from visual changes for replay compatibility;
- roll all of those edits back as one transaction.

An AST patcher can make these writes syntactically, but it cannot turn the
implicit runtime contracts into a safe authoring model. Those contracts first
need explicit schemas, capabilities, validators, and generated projections.

The current editor hardening should still be finished. The untracked
`docs/audit/editor-entities-section-audit-2026-08-15.md` and
`docs/building/editor/entityAuthoring/entity_catalog_authoring_strategy.md` are
sound working-tree inputs, but are not owned by this audit commit. The working
tree appears to address the audit's earlier
transaction, drift, typed-outcome, parsing, and scalar-binding findings. The
source-format preservation test that failed at the audit snapshot passed on an
isolated 2026-08-16 rerun; the editor checklist still owns the broader validation
gate and committed closure evidence.

## Candidate source model

If a record-oriented format wins the prototype, one file per entity is the
leading layout because it supports focused diffs and reduces merge conflicts.
The following paths are illustrative rather than accepted:

```text
assets/authoring/entities/
  projectiles/<stable-id>.<format>
  enemies/<stable-id>.<format>
  characters/<stable-id>.<format>
```

Each file should have common identity and lifecycle fields plus typed facets.
The exact schema belongs in the implementation design, but the following
boundaries should be fixed before UI work begins.

### Common fields

- `schemaVersion`: authoring schema, not game compatibility.
- `id`: immutable lower-snake or namespaced stable value.
- `ordinal`: immutable append-only bridge only where an existing list/enum wire
  contract still requires it.
- `displayNameKey`: localization key, not authoritative UI prose.
- `lifecycle`: `draft`, `active`, or `retired`.
- `simulation`: typed collider/stats/policy references.
- `render`: asset, animation, scale, anchor, and layer references.
- `references`: ability, projectile, loadout, or behavior-policy IDs.

Do not place price, entitlement, or ranked publication permission in the Core
record. Those are backend/product authorities.

### Projectile facet

A projectile is the best first slice because its runtime behavior is already
mostly catalog-shaped. Its record should cover:

- stable identity and lifecycle;
- motion policy and speed/gravity/homing facts;
- collider shape and offsets;
- lifetime, damage/effect reference, pierce/impact policy;
- render asset/animation/scale/anchor;
- localization key and optional editor grouping.

The generated slice should remove hand-maintained switches for render scale and
display discovery. Abilities and equipment should reference the stable ID.

### Enemy facet

An enemy record must select closed capability/policy types, not arbitrary code:

- locomotion and terrain-contact policy;
- navigation graph profile;
- spawn-placement policy;
- combat controller and ability loadout;
- collider, base stats, faction/tags, score class;
- render/animation descriptor;
- optional bespoke policy key from a reviewed registry.

If a desired enemy needs a genuinely new mechanic, a developer adds and tests
the policy in Core first; the editor can then expose that admitted option.

### Character facet

A character record should cover:

- collider and render animation set;
- movement, resource, combat, and animation tuning;
- traversal/motion policy (removing the Eloise-specific derivation);
- ability namespace/loadout references;
- cast origin and visual anchors;
- default gear references as gameplay defaults only where Core needs them.

Backend starter ownership and store activation should consume an explicit
reviewed projection or remain separately authored. Creating a character in the
editor must not silently grant or sell it.

## Validation layers

Every record should pass four layers before generation:

1. **Schema:** types, required fields, allowed keys, finite numeric values.
2. **Semantic:** positive dimensions, valid collider geometry, consistent
   animation timing, legal stat/timing ranges.
3. **Reference:** every ability/projectile/policy/asset exists and is compatible
   with the referencing facet.
4. **Set-wide:** unique IDs and ordinals, lifecycle rules, no forbidden cycles,
   and complete projections for active content.

Diagnostics should contain a stable code, record ID, source field path, and
clear message. The editor, command-line generator, pre-submit validation, and
CI must call the same validator library.

Debug assertions in runtime classes are not a substitute for this admission
gate.

## Generated outputs and ownership

Prefer one generator invocation that computes the canonical source set and
writes all required data-only projections atomically.

| Output | Contains | Must not contain |
| --- | --- | --- |
| Core gameplay bundle | Typed definitions, stable IDs/ordinals, content hash | Flutter/Flame objects, store pricing |
| Flame render registry | Asset and animation descriptors keyed by stable ID | Damage, movement, entitlements |
| UI discovery metadata | Stable ID, localization key, preview asset/grouping | Authoritative simulation stats copied by hand |
| Backend existence projection | Known IDs/revision where backend validation needs them | Automatic publication, price, ownership grants |
| Validator bundle | The same Core gameplay bundle/revision as the client | Independently recreated tuning |

Generated files must be visibly marked and never edited by the editor after
generation. Writes should use the editor's transaction mechanism: validate all
source and outputs, stage the complete artifact set, verify baseline drift, then
replace atomically or roll back.

## Stable IDs, enums, and compatibility

There are two viable identity stages:

1. **Migration bridge:** generate existing Dart enums in immutable append-only
   ordinal order. This minimizes immediate code and protocol churn.
2. **Target:** use stable value IDs for content identity and keyed protocol
   records. Reserve closed enums for behavior categories that truly require an
   exhaustive code switch.

Do not expose arbitrary enemy creation while kill counts still derive their
meaning solely from `EnemyId.index`. Migrate that result contract or formally
freeze and validate immutable ordinals first.

Every successful generation should compute:

- a schema version;
- a canonical gameplay content hash;
- optionally a visual-content hash;
- a human-readable revision/build label.

A gameplay hash change requires a compatible run-contract publication step.
The editor should report this requirement; it should not deploy client,
validator, or backend code automatically.

## Editor UX contract

The Entities route can become one catalog workspace with filters for
projectiles, enemies, and characters. Creation should be staged:

1. choose a content type and supported template/capability set;
2. assign an immutable ID;
3. edit typed sections with units shown (`seconds`, `world units`, basis points);
4. see live schema/semantic/reference diagnostics;
5. preview render/collider data;
6. review source and generated diffs;
7. export the full artifact transaction;
8. run the smallest generated-content and Core parity tests.

Unknown source fields, missing references, unrecognized policies, baseline
drift, or generator differences must block export with no partial writes.

## Deferred future-pipeline outline

No item in this section belongs to the active Core hardening program. A future
pipeline must re-audit and explicitly authorize the work before using this
outline.

1. Finish and rebaseline current editor write-safety hardening.
2. Repair Core entity identity, influence, time, replay, and validation
   contracts while current Dart catalogs remain authoritative.
3. Generalize enemy behavior, player traversal, result identity, and the
   runtime content boundary without changing authoring format.
4. Prototype source formats using representative projectiles and record an ADR;
   retaining Dart is a valid outcome.
5. Migrate projectiles end to end only if the accepted decision calls for it.
6. Decide enemy and character formats independently, then migrate them in
   separate vertical slices if justified.
7. Treat abilities and gear as validated references first; add their own
   authoring only after special-case runtime policies are explicit.

This preserves the possible projectile -> enemy -> character delivery direction
while ensuring the format choice follows Core lifecycle, behavior-policy,
protocol, replay-version, and prototype evidence.
