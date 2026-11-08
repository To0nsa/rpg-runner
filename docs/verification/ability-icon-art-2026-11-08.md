# Ability icon artwork — 2026-11-08

## Delivered assets

All 46 current playable abilities have distinct transparent 64×64 PNG icons:

- [Éloïse assets](../../assets/images/icons/skills-icons/eloise/): 21 icons, including a dedicated Double Dash.
- [Willow assets](../../assets/images/icons/skills-icons/willow/): 25 icons, keyed by the existing `bounty_hunter.*` ability IDs.

Review sheets show each icon enlarged on dark, at native 64 pixels on light,
and at 32 pixels on light. Both complete sheets were visually inspected:

- [Éloïse review sheet](assets/ability-icons-eloise-2026-11-08.png)
- [Willow review sheet](assets/ability-icons-willow-2026-11-08.png)

Charcoal outlines, upper-left lighting, muted steel/slate, ivory, aged brass and
leather follow existing item artwork and the parent Lothringen brand references.
Restrained rust and fire accents distinguish specific effects. Action silhouettes
communicate gameplay: one/two/three cuts, guidance/piercing/five-shot spread,
separate bomb effects, recovery/preparation symbols and single/double impulses.
Only Éloïse's Cleave includes innate bleed; her Roll includes contact stun.
Willow's Roll does not. Projectile symbols remain independent of weapon payload.
Small figures are action emblems, not replacements for portraits or gameplay sprites.

## Generation and provenance

Generated with the built-in imagegen tool, one transparent image per ability.
The tool does not expose its underlying model identifier. The
[exact prompts and SHA-256 hashes](ability-icon-art-prompts-2026-11-08.json)
record all 46 ability IDs, subjects, prompts, reference images, generated source
identifiers, final paths and hashes. Existing item art supplied style references;
selected generated icons supplied family consistency references. Mechanics came
from current Core definitions and matching GDDs. Parent `Brand/VisualIdentity.md`
and `Brand/VisuelTokens.md` informed palette and material treatment.

Full-resolution originals remain under the local `$CODEX_HOME/generated_images`
tree. Final assets are in the workspace and do not depend on that directory.
Exports use System.Drawing nearest-neighbor sampling to 64×64 RGBA and preserve
generated alpha. No palette quantization or binary-alpha conversion was applied.
Three border pixels across Forced March and Prepare Charges retain alpha 1/255;
all other border pixels are fully transparent. The border check explicitly permits
this imperceptible generated-alpha residue, while rejecting visible clipping.

## Integration and documentation

`packages/game_presentation/lib/ability_skill_icon.dart` maps every current
Éloïse and Willow ability to its own file. The shared widget uses nearest-neighbor
filtering and the consumer's asset bundle, so game menus, inbox gifts and Admin
consume the same files. Null/unknown IDs and failed loads retain empty fixed-size
boxes. Old root-level Éloïse files remain available; current mappings use the new
character subdirectories. The generated `pubspec.yaml` includes both directories.

Current Willow GDD/TDD and Admin documentation now describe the artwork.
Éloïse's overview includes the previously omitted Double Dash and the implemented
12-tick Dash duration. No ability definitions, tuning or gameplay animations were
changed by this artwork task.

## Local verification

Source: Windows working tree based on `d9049e98`, including preexisting equipment,
Codex/menu and muzzle work, preserved throughout. Commands used the installed
`C:/Users/Toonsa/flutter/bin/cache/dart-sdk/bin/dart.exe`; Flutter was invoked
through that executable with `C:/Users/Toonsa/flutter/bin/cache/flutter_tools.snapshot`.
Reviewed outside-sandbox execution was used because sandbox process startup stalled.

| Directory | Command/check | Result |
| --- | --- | --- |
| Root | `flutter test --no-pub test/ui/icons test/ui/state/app_state_inbox_test.dart test/ui/state/firebase_inbox_api_test.dart --reporter expanded` | 23 passed; initial strict-zero border assertion failed on alpha 1/255 residue |
| Root | `flutter test --no-pub test/ui/icons/ability_skill_icon_test.dart --reporter expanded` | All 3 passed after documenting native-alpha tolerance; other 21 consumer tests unchanged |
| Root | `dart analyze packages/game_presentation test/ui/icons/ability_skill_icon_test.dart` | No issues after test-only brace correction |
| Root | `dart run tool/sync_assets.dart`, then `--check` | Current; two ability directories added |
| Root | `node tools/admin/service/catalog.mjs --check-fixture` | Existing catalog current |
| `tools/admin` | `flutter test --no-pub test/admin_page_test.dart --reporter expanded` | 2 passed: fixture compose flow and every backend catalog entry |
| Root | PNG review, provenance hashes and documentation links | 46 distinct matching hashes; both review sheets inspected; relative targets and `git diff --check` passed |

New tests derive coverage from the two Core catalogs, load and decode every actual
bundled PNG, check 64×64 dimensions, nonempty silhouettes and transparent margins,
render all icons at 32/40/64 pixels, and verify selection changes clear unknown or
null artwork. Admin uses its repository asset loader with fixture accounts;
no live message is sent. There was no device acceptance, native release build,
gameplay balance test or deployment.

[Completed work checklist](../archive/2026-11-08/building/ability_icon_art.md).
