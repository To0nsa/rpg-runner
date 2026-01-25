import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/commands/command.dart';
import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/game_core.dart';
import 'package:rpg_runner/core/players/player_character_registry.dart';
import 'package:rpg_runner/core/players/player_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_id.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';
import 'package:rpg_runner/core/util/tick_math.dart';

import '../test_tunings.dart';

void main() {
  int _scaledWindupTicks(String abilityId, int tickHz) {
    final ability = AbilityCatalog.tryGet(abilityId)!;
    if (tickHz == 60) return ability.windupTicks;
    final seconds = ability.windupTicks / 60.0;
    return ticksFromSecondsCeil(seconds, tickHz);
  }

  test('cast: insufficient mana => no projectile', () {
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      seed: 1,
      tickHz: 20,
      tuning: noAutoscrollTuning,
      playerCharacter: base.copyWith(
        catalog: const PlayerCatalog(
          bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
        ),
        tuning: base.tuning.copyWith(
          resource: const ResourceTuning(
            playerManaMax: 0,
            playerManaRegenPerSecond: 0,
          ),
        ),
      ),
    );

    core.applyCommands(const [ProjectilePressedCommand(tick: 1)]);
    core.stepOneTick();
    final windupTicks = _scaledWindupTicks('eloise.ice_bolt', core.tickHz);
    for (var i = 0; i < windupTicks; i += 1) {
      core.applyCommands(const <Command>[]);
      core.stepOneTick();
    }

    final snapshot = core.buildSnapshot();
    expect(
      snapshot.entities.where((e) => e.kind == EntityKind.projectile),
      isEmpty,
    );
    expect(snapshot.hud.mana, closeTo(0.0, 1e-9));
    expect(core.playerProjectileCooldownTicksLeft, 0);
  });

  test(
    'cast: sufficient mana => projectile spawns + mana spent + cooldown set',
    () {
      const catalog = PlayerCatalog(
        bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
      );
      final base = PlayerCharacterRegistry.eloise;
      final core = GameCore(
        seed: 1,
        tickHz: 20,
        tuning: noAutoscrollTuning,
        playerCharacter: base.copyWith(
          catalog: catalog,
          tuning: base.tuning.copyWith(
            resource: const ResourceTuning(
              playerManaMax: 20,
              playerManaRegenPerSecond: 0,
            ),
          ),
        ),
      );

      final playerPosX = core.playerPosX;
      final playerPosY = core.playerPosY;

      core.applyCommands(const [ProjectilePressedCommand(tick: 1)]);
      core.stepOneTick();
      final windupTicks = _scaledWindupTicks('eloise.ice_bolt', core.tickHz);
      for (var i = 0; i < windupTicks; i += 1) {
        core.applyCommands(const <Command>[]);
        core.stepOneTick();
      }

      final snapshot = core.buildSnapshot();
      final projectiles = snapshot.entities
          .where((e) => e.kind == EntityKind.projectile)
          .toList();
      expect(projectiles.length, 1);

      final p = projectiles.single;
      final expectedOffset = catalog.colliderMaxHalfExtent * 0.5;
      expect(p.pos.x, closeTo(playerPosX + expectedOffset, 1e-9));
      expect(p.pos.y, closeTo(playerPosY, 1e-9));

      expect(snapshot.hud.mana, closeTo(10.0, 1e-9));
      expect(
        core.playerProjectileCooldownTicksLeft,
        8 - windupTicks,
      ); // Cooldown already ticked during windup
    },
  );

  test('cast: equipped spell selects projectile + mana cost', () {
    const catalog = PlayerCatalog(
      bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
      projectileItemId: ProjectileItemId.fireBolt,
    );
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      seed: 1,
      tickHz: 20,
      tuning: noAutoscrollTuning,
      playerCharacter: base.copyWith(
        catalog: catalog,
        tuning: base.tuning.copyWith(
          resource: const ResourceTuning(
            playerManaMax: 20,
            playerManaRegenPerSecond: 0,
          ),
        ),
      ),
    );

    core.applyCommands(const [ProjectilePressedCommand(tick: 1)]);
    core.stepOneTick();
    final windupTicks = _scaledWindupTicks('eloise.fire_bolt', core.tickHz);
    for (var i = 0; i < windupTicks; i += 1) {
      core.applyCommands(const <Command>[]);
      core.stepOneTick();
    }

    final snapshot = core.buildSnapshot();
    final projectiles = snapshot.entities
        .where((e) => e.kind == EntityKind.projectile)
        .toList();
    expect(projectiles.length, 1);
    expect(projectiles.single.projectileId, ProjectileId.fireBolt);

    // fire_bolt costs 12 mana in AbilityCatalog.
    expect(snapshot.hud.mana, closeTo(8.0, 1e-9));
    expect(
      core.playerProjectileCooldownTicksLeft,
      5 - windupTicks,
    ); // Cooldown already ticked during windup
  });

  test('cast: cooldown blocks recast until it expires', () {
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      seed: 1,
      tickHz: 20,
      tuning: noAutoscrollTuning,
      playerCharacter: base.copyWith(
        catalog: const PlayerCatalog(
          bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
        ),
        tuning: base.tuning.copyWith(
          resource: const ResourceTuning(
            playerManaMax: 30,
            playerManaRegenPerSecond: 0,
          ),
        ),
      ),
    );

    core.applyCommands(const [ProjectilePressedCommand(tick: 1)]);
    core.stepOneTick();
    final windupTicks = _scaledWindupTicks('eloise.ice_bolt', core.tickHz);
    for (var i = 0; i < windupTicks; i += 1) {
      core.applyCommands(const <Command>[]);
      core.stepOneTick();
    }

    core.applyCommands(const [ProjectilePressedCommand(tick: 2)]);
    core.stepOneTick();
    for (var i = 0; i < windupTicks; i += 1) {
      core.applyCommands(const <Command>[]);
      core.stepOneTick();
    }

    var snapshot = core.buildSnapshot();
    expect(snapshot.hud.mana, closeTo(20.0, 1e-9));
    expect(
      snapshot.entities.where((e) => e.kind == EntityKind.projectile).length,
      1,
    );

    // Wait until cooldown should be 0, then cast again.
    while (core.playerProjectileCooldownTicksLeft > 0) {
      core.applyCommands(<Command>[]);
      core.stepOneTick();
    }

    core.applyCommands(const [ProjectilePressedCommand(tick: 9)]);
    core.stepOneTick();
    for (var i = 0; i < windupTicks; i += 1) {
      core.applyCommands(const <Command>[]);
      core.stepOneTick();
    }

    snapshot = core.buildSnapshot();
    expect(snapshot.hud.mana, closeTo(10.0, 1e-9));
    expect(
      snapshot.entities.where((e) => e.kind == EntityKind.projectile).length,
      2,
    );
  });
}
