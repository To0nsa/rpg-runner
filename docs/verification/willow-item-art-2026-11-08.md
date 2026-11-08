# Willow item-art verification — 2026-11-08

## Delivered assets

All 34 Willow-specific items have transparent 64×64 PNG illustrations in
[the canonical asset tree](../../assets/images/icons/gear-icons/willow/):
8 blades, 10 bomb kits, 8 field kits and 8 ranged weapons. The eight shared
accessories retain their existing artwork, completing illustrations for Willow's
42 compatible equipment items.

[Review sheet](assets/willow-item-art-2026-11-08.png): each item appears enlarged
on a dark background, at native 64 pixels on a light background, and at 32 pixels
on the same light background. Every final image was inspected in this sheet.
All files have transparent border pixels and nonempty silhouettes; all 34 file
hashes are distinct. No existing art was overwritten.

## Generation and provenance

Mode: built-in imagegen, one generation per distinct item, transparent background.
The built-in tool does not expose the underlying model identifier.
The [exact prompt set and hashes](willow-item-art-prompts-2026-11-08.json) records
every item identity, final asset path, complete prompt, source-image identifier,
source hash and final PNG hash.

Style references were the existing Waspfang icon, sword icon atlas and Roadguard
shield. Selected generated family masters provided additional consistency
references. Parent Lothringen `Brand/VisualIdentity.md` and
`Brand/VisuelTokens.md`, together with the existing equipment design references,
informed muted steel, aged brass, worn leather, restrained accent colors,
upper-left lighting and charcoal outlines. Reference images supplied style;
the generated images depict Willow's own equipment.

Built-in full-resolution outputs were saved under the local
`$CODEX_HOME/generated_images` tree. Final project assets were exported with
System.Drawing nearest-neighbor sampling to 64×64 RGBA PNGs, preserving generated
alpha. No palette quantization, painted touch-up or synthetic replacement artwork
was applied. The runtime assets and exact prompts are in the repository; local
full-resolution intermediates are not runtime dependencies.

## Integration

Shared `ui_icon_coords.dart` maps all equipment identities to canonical keys.
`GearIcon` loads blades, bomb kits and field kits; `ProjectileIconFrame` loads
ranged-item illustrations independently of projectile combat effects.
Both respect the consumer's `DefaultAssetBundle` and use
`FilterQuality.none` for nearest-neighbor display.
The root `pubspec.yaml` generated asset block includes the four family directories.
No copied Admin asset tree, gameplay changes or ownership changes were needed.

## Local checks

Source: the Windows working tree based on `d9049e98`, including preexisting
equipment, Codex/menu and muzzle work. Those changes were preserved. This record
covers the item-art integration, not a new gameplay or release certification.
Commands used the installed Dart executable at
`C:/Users/Toonsa/flutter/bin/cache/dart-sdk/bin/dart.exe`; `flutter` below was
invoked through that executable and the installed `flutter_tools.snapshot`.
Reviewed outside-sandbox execution was used because sandbox process startup
had stalled earlier in the session.

| Directory | Command/check | Result |
| --- | --- | --- |
| Repository root | `flutter test --no-pub test/ui/icons test/ui/state/app_state_inbox_test.dart test/ui/state/firebase_inbox_api_test.dart --reporter expanded` | 21 passed |
| `tools/admin` | `flutter test --no-pub test/admin_page_test.dart --reporter expanded` | 2 passed; fixture compose and every backend catalog entry resolve through repository assets |
| Repository root | `dart analyze packages/game_presentation test/ui/icons/willow_item_art_test.dart` | No issues after correcting one test-only brace lint |
| Repository root | `dart run tool/sync_assets.dart`, then `--check` | Generated manifest current; four directories added |
| Repository root | `node tools/admin/service/catalog.mjs --check-fixture` | Current existing generated catalog |
| Repository root | PNG inspection | 34 distinct 64×64 RGBA PNGs; all transparent margins; reviewed on dark/light backgrounds at 128/64/32 pixels |
| Repository root | `git diff --check` and changed-document relative targets | Passed |

The new tests load each PNG from the real game bundle, decode dimensions/alpha,
render all 34 shared widgets at 32/40/64 pixels, assert nearest-neighbor filtering,
and check that changing a ranged selection clears the prior artwork.
Admin checks use its real repository-backed asset loader with fixture accounts;
no live gift is sent. The brace-only correction does not alter test behavior.

## Remaining boundaries

Willow ability illustrations remain empty; abilities are outside this equipment
artwork request. Existing gameplay animations and shared accessory art are retained.
No native release build, device acceptance, live balance session or deployment
was performed. This is completed local asset authoring and integration.

The completed [work checklist](../archive/2026-11-08/building/willow_item_art.md)
and [equipment roster](../gdd/combat/gears/willow_equipment_roster.md) describe scope.
