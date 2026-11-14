@TestOn('vm')
library;

// The Flutter workspace analyzer hides VM-only mirrors. The Core VM suite still
// compiles and executes this complete-field contract test; app code imports none.
// ignore: uri_does_not_exist
import 'dart:mirrors';

import 'package:runner_core/campaign/campaign_registry.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_identity.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:test/test.dart';

void main() {
  for (final player in PlayerCharacterRegistry.playable) {
    test(
      '${player.id.name}: compiled Campaign and captured Play match for 360 ticks',
      () {
        final mission = campaignMissions['reporting_for_duty']!;
        final product = GameCore.campaign(
          missionId: mission.id,
          contentDigest: campaignContentDigest,
          playerCharacter: player,
          seed: 42,
          tickHz: 60,
          runId: 77,
        );
        final editor = GameCore.campaignPlaytest(
          mission: mission,
          playerCharacter: player,
          seed: 42,
          tickHz: 60,
          runId: 77,
        );
        addTearDown(product.stopTerrainPreparation);
        addTearDown(editor.stopTerrainPreparation);
        expect(
          product.buildSnapshot().levelIdentity,
          isA<RegisteredLevelIdentity>(),
        );
        expect(
          editor.buildSnapshot().levelIdentity,
          isA<AuthoredLevelIdentity>(),
        );
        for (var tick = 0; tick <= 360; tick++) {
          if (tick > 0) {
            final commands = <Command>[
              MoveAxisCommand(tick: tick, axis: tick <= 180 ? 1 : -1),
              if (tick % 60 == 0) JumpPressedCommand(tick: tick),
              if (tick % 45 == 0) StrikePressedCommand(tick: tick),
              if (tick % 90 == 0) ProjectilePressedCommand(tick: tick),
            ];
            for (final core in [product, editor]) {
              core.applyCommands(commands);
              core.stepOneTick();
            }
          }
          expect(
            _value(editor.drainEvents()),
            _value(product.drainEvents()),
            reason: 'event payloads at tick $tick',
          );
          if (tick == 0 || tick == 1 || tick % 60 == 0) {
            final a = _value(product.buildSnapshot()) as Map<String, Object?>;
            final b = _value(editor.buildSnapshot()) as Map<String, Object?>;
            // Registered product region vs authored mission provenance is the only
            // intentional difference. Keep collision, objectives and combat data.
            a.remove('levelIdentity');
            b.remove('levelIdentity');
            expect(b, a, reason: 'complete snapshot at tick $tick');
          }
        }
        expect(product.tick, 360);
        expect(editor.tick, 360);
      },
    );
  }
}

// VM-only contract test: inspect every public data field, including future
// snapshot/event additions, rather than hiding drift behind a partial projection.
Object? _value(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is Enum) return value.toString();
  if (value is Iterable) return value.map(_value).toList();
  if (value is Map) {
    return value.map((key, value) => MapEntry(_value(key), _value(value)));
  }
  // ignore: undefined_function
  final instance = reflect(value);
  final result = <String, Object?>{'type': value.runtimeType.toString()};
  for (
    // ignore: undefined_class
    ClassMirror? type = instance.type;
    type != null;
    type = type.superclass
  ) {
    // ignore: non_type_as_type_argument
    for (final field in type.declarations.values.whereType<VariableMirror>()) {
      if (!field.isStatic && !field.isPrivate) {
        // ignore: undefined_identifier
        result[MirrorSystem.getName(field.simpleName)] = _value(
          instance.getField(field.simpleName).reflectee,
        );
      }
    }
  }
  return result;
}
