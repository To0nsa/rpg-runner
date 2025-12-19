import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/combat/faction.dart';
import 'package:walkscape_runner/core/enemies/enemy_id.dart';
import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:walkscape_runner/core/ecs/stores/health_store.dart';
import 'package:walkscape_runner/core/ecs/stores/mana_store.dart';
import 'package:walkscape_runner/core/ecs/stores/stamina_store.dart';
import 'package:walkscape_runner/core/ecs/systems/damage_system.dart';
import 'package:walkscape_runner/core/ecs/systems/projectile_hit_system.dart';
import 'package:walkscape_runner/core/ecs/world.dart';
import 'package:walkscape_runner/core/projectiles/projectile_catalog.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';
import 'package:walkscape_runner/core/spells/spawn_spell_projectile.dart';
import 'package:walkscape_runner/core/spells/spell_catalog.dart';
import 'package:walkscape_runner/core/spells/spell_id.dart';

void main() {
  test('ProjectileHitSystem damages target and despawns projectile', () {
    final world = EcsWorld();

    final player = world.createPlayer(
      posX: 100,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0),
      mana: const ManaDef(mana: 100, manaMax: 100, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    final enemy = world.createEnemy(
      enemyId: EnemyId.demon,
      posX: 140,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.left,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    // Spawn a projectile overlapping the enemy.
    final projectile = spawnSpellProjectile(
      world,
      spells: const SpellCatalog(),
      projectiles: ProjectileCatalogDerived.from(const ProjectileCatalog(), tickHz: 60),
      spellId: SpellId.iceBolt,
      faction: Faction.player,
      owner: player,
      originX: 140,
      originY: 100,
      dirX: 1,
      dirY: 0,
    );
    expect(projectile, isNotNull);

    final damage = DamageSystem(invulnerabilityTicksOnHit: 0);
    final hits = ProjectileHitSystem();
    hits.step(world, damage.queue);
    damage.step(world);

    expect(world.health.hp[world.health.indexOf(enemy)], closeTo(75.0, 1e-9));
    expect(world.projectile.has(projectile!), isFalse);
  });
}
