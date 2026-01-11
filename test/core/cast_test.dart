import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/commands/command.dart';
import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/core/players/player_character_registry.dart';
import 'package:walkscape_runner/core/players/player_catalog.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';
import 'package:walkscape_runner/core/players/player_tuning.dart';

import '../test_tunings.dart';

void main() {
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

    core.applyCommands(const [CastPressedCommand(tick: 1)]);
    core.stepOneTick();

    final snapshot = core.buildSnapshot();
    expect(
      snapshot.entities.where((e) => e.kind == EntityKind.projectile),
      isEmpty,
    );
    expect(snapshot.hud.mana, closeTo(0.0, 1e-9));
    expect(core.playerCastCooldownTicksLeft, 0);
  });

  test(
    'cast: sufficient mana => projectile spawns + mana spent + cooldown set',
    () {
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
              playerManaMax: 20,
              playerManaRegenPerSecond: 0,
            ),
          ),
        ),
      );

      final playerPosX = core.playerPosX;
      final playerPosY = core.playerPosY;

      core.applyCommands(const [CastPressedCommand(tick: 1)]);
      core.stepOneTick();

      final snapshot = core.buildSnapshot();
      final projectiles = snapshot.entities
          .where((e) => e.kind == EntityKind.projectile)
          .toList();
      expect(projectiles.length, 1);

      final p = projectiles.single;
      expect(p.pos.x, closeTo(playerPosX + 4.0, 1e-9)); // maxHalfExtent * 0.5
      expect(p.pos.y, closeTo(playerPosY, 1e-9));

      expect(snapshot.hud.mana, closeTo(10.0, 1e-9));
      expect(core.playerCastCooldownTicksLeft, 5); // ceil(0.25s * 20Hz)
    },
  );

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

    core.applyCommands(const [CastPressedCommand(tick: 1)]);
    core.stepOneTick();

    core.applyCommands(const [CastPressedCommand(tick: 2)]);
    core.stepOneTick();

    var snapshot = core.buildSnapshot();
    expect(snapshot.hud.mana, closeTo(20.0, 1e-9));
    expect(
      snapshot.entities.where((e) => e.kind == EntityKind.projectile).length,
      1,
    );

    // Wait until cooldown should be 0, then cast again.
    for (var t = 3; t <= 6; t += 1) {
      core.applyCommands(<Command>[]);
      core.stepOneTick();
    }

    core.applyCommands(const [CastPressedCommand(tick: 7)]);
    core.stepOneTick();

    snapshot = core.buildSnapshot();
    expect(snapshot.hud.mana, closeTo(10.0, 1e-9));
    expect(
      snapshot.entities.where((e) => e.kind == EntityKind.projectile).length,
      2,
    );
  });
}
