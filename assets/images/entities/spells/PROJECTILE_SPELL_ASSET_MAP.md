# Projectile Spell Asset Map

This document maps player `WeaponType.projectileSpell` entries to their
projectile render assets and required animation metadata.

Source of truth in code:
- `lib/core/projectiles/projectile_catalog.dart`
- `lib/core/projectiles/projectile_render_catalog.dart`

Conventions:
- Asset paths in Core are relative to `assets/images/`.
- `AnimKey.spawn` and `AnimKey.hit` are one-shot animations.
- `AnimKey.idle` loops.
- `rowByKey` defaults to row `0` unless explicitly listed for a key.
- `frameStartByKey` defaults to `0` unless listed below.
- If a field is not available from source-of-truth files, use `TBD` as a
  placeholder instead of leaving it blank.

## Projectile Spell -> Asset Folder

| ProjectileId | Asset folder |
| --- | --- |
| `acidBolt` | `assets/images/entities/spells/acid/bolt/` |
| `darkBolt` | `assets/images/entities/spells/dark/bolt/` |
| `iceBolt` | `assets/images/entities/spells/ice/bolt/` |
| `fireBolt` | `assets/images/entities/spells/fire/bolt/` |
| `earthBolt` | `assets/images/entities/spells/earth/bolt/` |
| `thunderBolt` | `assets/images/entities/spells/thunder/bolt/` |

## Gameplay Metadata (Core)

| ProjectileId | DamageType | Speed (units/s) | Lifetime (s) | Collider (w x h) | Origin offset | Ballistic | Gravity scale | On-hit status proc |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `acidBolt` | `acid` | `500.0` | `1.3` | `18.0 x 8.0` | `30.0` | `false` | `1.0` | `StatusProfileId.acidOnHit` |
| `darkBolt` | `dark` | `550.0` | `1.3` | `18.0 x 8.0` | `30.0` | `false` | `1.0` | `StatusProfileId.weakenOnHit` |
| `iceBolt` | `ice` | `600.0` | `1.3` | `18.0 x 8.0` | `30.0` | `false` | `1.0` | `StatusProfileId.slowOnHit` |
| `fireBolt` | `fire` | `600.0` | `1.3` | `18.0 x 8.0` | `30.0` | `false` | `1.0` | `StatusProfileId.burnOnHit` |
| `thunderBolt` | `thunder` | `650.0` | `1.3` | `18.0 x 8.0` | `30.0` | `false` | `1.0` | `StatusProfileId.stunOnHit` |
| `earthBolt` | `earth` | `500.0` | `1.3` | `18.0 x 8.0` | `30.0` | `false` | `1.0` | `StatusProfileId.stunOnHit` |

## Animation Metadata

### `acidBolt`

Frame size: `32 x 32`

| AnimKey | Asset path (relative to `assets/images/`) | Frame count | Frame start | Step time (seconds) |
| --- | --- | --- | --- | --- |
| `spawn` | `entities/spells/acid/bolt/spriteSheet.png` | `10` | `0` | `0.06` |
| `idle` | `entities/spells/acid/bolt/spriteSheet.png` | `10` | `0` | `0.06` |
| `hit` | `entities/spells/acid/bolt/spriteSheet.png` | `6` | `10` | `0.06` |

### `iceBolt`

Frame size: `48 x 32`

| AnimKey | Asset path (relative to `assets/images/`) | Frame count | Frame start | Step time (seconds) |
| --- | --- | --- | --- | --- |
| `spawn` | `entities/spells/ice/bolt/start.png` | `3` | `0` | `0.06` |
| `idle` | `entities/spells/ice/bolt/repeatable.png` | `10` | `0` | `0.06` |
| `hit` | `entities/spells/ice/bolt/hit.png` | `8` | `0` | `0.06` |

### `fireBolt`

Frame size: `48 x 48`

| AnimKey | Asset path (relative to `assets/images/`) | Frame count | Frame start | Step time (seconds) |
| --- | --- | --- | --- | --- |
| `spawn` | `entities/spells/fire/bolt/spriteSheet.png` | `4` | `0` | `0.06` |
| `idle` | `entities/spells/fire/bolt/spriteSheet.png` | `4` | `0` | `0.06` |
| `hit` | `entities/spells/fire/bolt/spriteSheet.png` | `6` | `5` | `0.06` |

### `thunderBolt`

Frame size: `32 x 32`

| AnimKey | Asset path (relative to `assets/images/`) | Frame count | Frame start | Step time (seconds) |
| --- | --- | --- | --- | --- |
| `spawn` | `entities/spells/thunder/bolt/start.png` | `5` | `0` | `0.06` |
| `idle` | `entities/spells/thunder/bolt/repeatable.png` | `5` | `0` | `0.06` |
| `hit` | `entities/spells/thunder/bolt/hit.png` | `6` | `0` | `0.06` |

### `darkBolt`

Frame size: `40 x 32`

Spritesheet is 0-indexed (Row, Column)

| AnimKey | Asset path (relative to `assets/images/`) | Frame count | Frame start | Step time (seconds) |
| --- | --- | --- | --- | --- |
| `spawn` | `entities/spells/dark/bolt/spriteSheet.png` | `10` | `0 0` | `0.06` |
| `idle` | `entities/spells/dark/bolt/spriteSheet.png` | `10` | `0 0` | `0.06` |
| `hit` | `entities/spells/dark/bolt/spriteSheet.png` | `6` | `1 0` | `0.06` |

### `earthBolt`

Frame size: `48 x 32`

Spritesheet is 0-indexed (Row, Column)

| AnimKey | Asset path (relative to `assets/images/`) | Frame count | Frame start | Step time (seconds) |
| --- | --- | --- | --- | --- |
| `spawn` | `entities/spells/earth/bolt/spriteSheet.png` | `6` | `0 0` | `0.06` |
| `idle` | `entities/spells/earth/bolt/spriteSheet.png` | `6` | `0 0` | `0.06` |
| `hit` | `entities/spells/earth/bolt/spriteSheet.png` | `4` | `1 0` | `0.06` |

## Template (Use `TBD` Placeholders)

Use this when adding a new projectile spell before all metadata is finalized.

| ProjectileId | Asset folder | Frame size | DamageType | Speed (units/s) | Lifetime (s) |
| --- | --- | --- | --- | --- | --- |
| `TBD` | `assets/images/entities/spells/TBD/` | `TBD x TBD` | `TBD` | `TBD` | `TBD` |

| AnimKey | Asset path (relative to `assets/images/`) | Frame count | Frame start | Step time (seconds) |
| --- | --- | --- | --- | --- |
| `spawn` | `TBD` | `TBD` | `TBD` | `TBD` |
| `idle` | `TBD` | `TBD` | `TBD` | `TBD` |
| `hit` | `TBD` | `TBD` | `TBD` | `TBD` |
