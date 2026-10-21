import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';

import '../support/test_level.dart';

void main() {
  for (final airborne in [false, true]) {
    test(
      'dash range and two half bursts through terrain, airborne=$airborne',
      () {
        final dash = _core('eloise.dash', airborne: airborne);
        final start = dash.playerPosX;
        for (var i = 0; i < 12; i++) {
          _step(dash, press: i == 0);
        }
        // Terrain integration quantizes position to 1/1024 units per tick.
        expect(dash.playerPosX - start, closeTo(110, 12 / 1024));
        final doubleDash = _core('eloise.double_dash', airborne: airborne);
        final doubleStart = doubleDash.playerPosX;
        for (var i = 0; i < 8; i++) {
          _step(doubleDash, press: i == 0);
        }
        final firstEnd = doubleDash.playerPosX;
        expect(firstEnd - doubleStart, closeTo(68.75, 8 / 1024));
        expect(doubleDash.buildSnapshot().hud.mobilityRecastTicksLeft, 30);
        for (var i = 0; i < 8; i++) {
          _step(doubleDash, press: i == 0);
        }
        expect(doubleDash.playerPosX - firstEnd, closeTo(68.75, 8 / 1024));
        expect(doubleDash.playerPosX - doubleStart, closeTo(137.5, 16 / 1024));
        expect(doubleDash.buildSnapshot().hud.mobilityRecastTicksLeft, 0);
      },
    );
  }

  test('gear speed applies on the first and all subsequent dash ticks', () {
    final core = _core('eloise.double_dash', accessory: AccessoryId.speedBoots);
    _step(core, press: true);
    final speed = core.playerVelX;
    expect(speed, greaterThan(515.625));
    for (var i = 1; i < 8; i++) {
      _step(core);
      expect(core.playerVelX, closeTo(speed, 1e-9));
    }
  });

  test('HUD exposes exactly the usable window and clears it at run end', () {
    final core = _core('eloise.double_dash');
    for (var i = 0; i < 7; i++) {
      _step(core, press: i == 0);
      expect(core.buildSnapshot().hud.mobilityRecastTicksLeft, 0);
    }
    _step(core);
    expect(core.buildSnapshot().hud.mobilityRecastTicksLeft, 30);
    while (core.tick < 37) {
      _step(core);
    }
    expect(core.buildSnapshot().hud.mobilityRecastTicksLeft, 1);
    _step(core);
    expect(core.buildSnapshot().hud.mobilityRecastTicksLeft, 0);
    final ended = _core('eloise.double_dash');
    for (var i = 0; i < 8; i++) {
      _step(ended, press: i == 0);
    }
    ended.giveUp();
    expect(ended.buildSnapshot().hud.mobilityRecastTicksLeft, 0);
  });
}

GameCore _core(
  String ability, {
  bool airborne = false,
  AccessoryId accessory = AccessoryId.strengthBelt,
}) {
  final core = GameCore(
    seed: 1,
    playerCharacter: PlayerCharacterRegistry.eloise,
    equippedLoadoutOverride: EquippedLoadoutDef(
      abilityMobilityId: ability,
      accessoryId: accessory,
    ),
    levelDefinition: testFieldLevel(
      tuning: const CoreTuning(
        camera: CameraTuning(speedLagMulX: 0, followThresholdRatio: 1),
        track: TrackTuning(enabled: false),
      ),
    ),
  );
  if (airborne) {
    core.setPlayerPosXYUnsafeForTest(core.playerPosX, core.playerPosY - 100);
  }
  return core;
}

void _step(GameCore core, {bool press = false}) {
  final tick = core.tick + 1;
  core.applyCommands([
    MoveAxisCommand(tick: tick, axis: 0),
    if (press) DashPressedCommand(tick: tick),
  ]);
  core.stepOneTick();
}
