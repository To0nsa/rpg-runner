import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/combat/damage_type.dart';
import 'package:walkscape_runner/core/combat/faction.dart';
import 'package:walkscape_runner/core/combat/status/status.dart';
import 'package:walkscape_runner/core/commands/command.dart';
import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/ecs/systems/projectile_world_collision_system.dart';
import 'package:walkscape_runner/core/ecs/world.dart';
import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/core/players/player_catalog.dart';
import 'package:walkscape_runner/core/projectiles/projectile_catalog.dart';
import 'package:walkscape_runner/core/projectiles/projectile_id.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';
import 'package:walkscape_runner/core/tuning/player/player_resource_tuning.dart';
import 'package:walkscape_runner/core/weapons/ranged_weapon_catalog.dart';
import 'package:walkscape_runner/core/weapons/ranged_weapon_id.dart';
import 'package:walkscape_runner/core/weapons/spawn_ranged_weapon_projectile.dart';
import 'package:walkscape_runner/core/ecs/stores/combat/ammo_store.dart';

import '../test_tunings.dart';

void main() {
  test(
    'ranged: sufficient stamina + ammo => projectile spawns + costs + cooldown set',
    () {
      const tickHz = 20;
      final core = GameCore.withTunings(
        seed: 1,
        tickHz: tickHz,
        playerCatalog: const PlayerCatalog(
          bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
          rangedWeaponId: RangedWeaponId.bow,
          ammo: AmmoDef(arrows: 2, throwingAxes: 0),
        ),
        cameraTuning: noAutoscrollCameraTuning,
        resourceTuning: const ResourceTuning(
          playerManaMax: 0,
          playerManaRegenPerSecond: 0,
          playerStaminaMax: 10,
          playerStaminaRegenPerSecond: 0,
        ),
      );

      final playerPosX = core.playerPosX;
      final playerPosY = core.playerPosY;

      core.applyCommands(
        const [
          RangedAimDirCommand(tick: 1, x: 1, y: 0),
          RangedPressedCommand(tick: 1),
        ],
      );
      core.stepOneTick();

      final snapshot = core.buildSnapshot();
      final projectiles = snapshot.entities
          .where((e) => e.kind == EntityKind.projectile)
          .toList();
      expect(projectiles.length, 1);

      final p = projectiles.single;
      final weapon = const RangedWeaponCatalog().get(RangedWeaponId.bow);
      expect(p.pos.x, closeTo(playerPosX + weapon.originOffset, 1e-9));
      expect(p.pos.y, closeTo(playerPosY, 1e-9));

      expect(snapshot.hud.stamina, closeTo(6.0, 1e-9));
      expect(snapshot.hud.rangedAmmo, 1);
      expect(snapshot.hud.rangedWeaponCooldownTicksLeft, 5); // 0.25s @ 20Hz
    },
  );

  test('ranged: insufficient ammo => no projectile + no costs + no cooldown', () {
    final core = GameCore.withTunings(
      seed: 1,
      tickHz: 20,
      playerCatalog: const PlayerCatalog(
        bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
        rangedWeaponId: RangedWeaponId.bow,
        ammo: AmmoDef(arrows: 0, throwingAxes: 0),
      ),
      cameraTuning: noAutoscrollCameraTuning,
      resourceTuning: const ResourceTuning(
        playerManaMax: 0,
        playerManaRegenPerSecond: 0,
        playerStaminaMax: 10,
        playerStaminaRegenPerSecond: 0,
      ),
    );

    core.applyCommands(
      const [
        RangedAimDirCommand(tick: 1, x: 1, y: 0),
        RangedPressedCommand(tick: 1),
      ],
    );
    core.stepOneTick();

    final snapshot = core.buildSnapshot();
    expect(
      snapshot.entities.where((e) => e.kind == EntityKind.projectile),
      isEmpty,
    );
    expect(snapshot.hud.stamina, closeTo(10.0, 1e-9));
    expect(snapshot.hud.rangedAmmo, 0);
    expect(snapshot.hud.rangedWeaponCooldownTicksLeft, 0);
    expect(snapshot.hud.canAffordRangedWeapon, isFalse);
  });

  test('ProjectileWorldCollisionSystem despawns ballistic projectiles', () {
    final world = EcsWorld();
    final system = ProjectileWorldCollisionSystem();

    final projectiles =
        ProjectileCatalogDerived.from(const ProjectileCatalog(), tickHz: 20);

    final owner = world.createEntity();
    final p = spawnRangedWeaponProjectileFromCaster(
      world,
      projectiles: projectiles,
      projectileId: ProjectileId.arrow,
      faction: Faction.player,
      owner: owner,
      casterX: 100,
      casterY: 50,
      originOffset: 0,
      dirX: 1,
      dirY: 0,
      fallbackDirX: 1,
      fallbackDirY: 0,
      damage: 1,
      damageType: DamageType.physical,
      statusProfileId: StatusProfileId.none,
      ballistic: true,
      gravityScale: 1.0,
    );

    expect(world.projectile.has(p), isTrue);
    expect(world.body.has(p), isTrue);
    expect(world.collision.has(p), isTrue);
    expect(world.projectile.usePhysics[world.projectile.indexOf(p)], isTrue);

    final ci = world.collision.indexOf(p);
    world.collision.grounded[ci] = true;

    system.step(world);

    expect(world.projectile.has(p), isFalse);
    expect(world.collision.has(p), isFalse);
  });
}

