import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_def.dart' show WeaponType;
import 'package:rpg_runner/core/combat/damage_type.dart';
import 'package:rpg_runner/core/combat/status/status.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/projectiles/projectile_render_catalog.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';

void main() {
  test('darkBolt gameplay metadata matches core tuning', () {
    final item = const ProjectileCatalog().get(ProjectileId.darkBolt);

    expect(item.weaponType, WeaponType.projectileSpell);
    expect(item.damageType, DamageType.dark);
    expect(item.speedUnitsPerSecond, 900.0);
    expect(item.lifetimeSeconds, 1.0);
    expect(item.colliderSizeX, 20.0);
    expect(item.colliderSizeY, 10.0);
    expect(item.ballistic, isFalse);
    expect(item.gravityScale, 1.0);
    expect(item.procs, hasLength(1));
    expect(item.procs.single.statusProfileId, StatusProfileId.weakenOnHit);
    expect(item.procs.single.chanceBp, 10000);
  });

  test('darkBolt render metadata maps to expected sheet rows and timing', () {
    final anim = const ProjectileRenderCatalog().get(ProjectileId.darkBolt);

    expect(anim.frameWidth, 40);
    expect(anim.frameHeight, 32);

    const expectedSource = 'entities/spells/dark/bolt/spriteSheet.png';
    expect(anim.sourcesByKey[AnimKey.spawn], expectedSource);
    expect(anim.sourcesByKey[AnimKey.idle], expectedSource);
    expect(anim.sourcesByKey[AnimKey.hit], expectedSource);

    expect(anim.rowByKey[AnimKey.spawn], 0);
    expect(anim.rowByKey[AnimKey.idle], 0);
    expect(anim.rowByKey[AnimKey.hit], 1);

    expect(anim.frameCountsByKey[AnimKey.spawn], 10);
    expect(anim.frameCountsByKey[AnimKey.idle], 10);
    expect(anim.frameCountsByKey[AnimKey.hit], 6);

    expect(anim.stepTimeSecondsByKey[AnimKey.spawn], closeTo(0.05, 1e-9));
    expect(anim.stepTimeSecondsByKey[AnimKey.idle], closeTo(0.06, 1e-9));
    expect(anim.stepTimeSecondsByKey[AnimKey.hit], closeTo(0.05, 1e-9));
  });
}
