# Accessory Catalog (Core)

This catalog defines **global inventory accessories** (data-only) ahead of the
inventory system. Accessories are **not equipped or applied** yet; they are
authoring-time definitions for future loadout/inventory work.

## v0 Scope
- **Single accessory slot**: `AccessorySlot.trinket`
- **Filtering**: `AccessoryTag` for UI grouping
- **Stats**: `AccessoryStats` for future bonuses (not wired yet)
- **Procs**: Optional procs for future payload integration

## Files
- `lib/core/accessories/accessory_id.dart`
- `lib/core/accessories/accessory_def.dart`
- `lib/core/accessories/accessory_catalog.dart`

## Current IDs (aligned to icon map)
- `speedBoots`
- `goldenRing`
- `teethNecklace`
