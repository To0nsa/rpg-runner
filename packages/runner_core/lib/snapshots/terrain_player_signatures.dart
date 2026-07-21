import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'terrain_player_debug_snapshot.dart';

/// Quantized command record used only by reviewed terrain-run signatures.
///
/// Values must already use the command contract's chosen integer scale; this
/// type intentionally accepts no floating-point fields.
class TerrainPlayerCommandSignatureRecord {
  const TerrainPlayerCommandSignatureRecord({
    required this.tick,
    required this.kind,
    this.value0 = 0,
    this.value1 = 0,
  });

  final int tick;
  final String kind;
  final int value0;
  final int value1;
}

/// Complete integer/string input for one reviewed terrain player-run digest.
class TerrainPlayerRunSignatureInput {
  const TerrainPlayerRunSignatureInput({
    required this.seed,
    required this.characterId,
    required this.commands,
    required this.contactCheckpoints,
    required this.finalTick,
    required this.finalBodyXTicks,
    required this.finalBodyYTicks,
    required this.finalVelocityXTicks,
    required this.finalVelocityYTicks,
    required this.finalHealth100,
    required this.finalMana100,
    required this.finalStamina100,
    required this.distanceXTicks,
    required this.score,
    required this.eventCodes,
    required this.runEndReason,
    required this.rngState,
  });

  final int seed;
  final String characterId;
  final List<TerrainPlayerCommandSignatureRecord> commands;
  final List<TerrainPlayerDebugSnapshot> contactCheckpoints;
  final int finalTick;
  final int finalBodyXTicks;
  final int finalBodyYTicks;
  final int finalVelocityXTicks;
  final int finalVelocityYTicks;
  final int finalHealth100;
  final int finalMana100;
  final int finalStamina100;
  final int distanceXTicks;
  final int score;
  final List<String> eventCodes;
  final String runEndReason;
  final int rngState;
}

/// SHA-256 over canonical `terrain-contacts-v2` checkpoint records.
String terrainPlayerContactSignatureV2(
  Iterable<TerrainPlayerDebugSnapshot> snapshots,
) {
  final ordered = List<TerrainPlayerDebugSnapshot>.of(snapshots)
    ..sort((left, right) {
      final tickOrder = left.tick.compareTo(right.tick);
      return tickOrder != 0
          ? tickOrder
          : left.entityId.compareTo(right.entityId);
    });
  return _signature(ordered.map(_terrainPlayerContactRecordV2));
}

/// SHA-256 over one complete canonical `terrain-player-run-v1` record stream.
String terrainPlayerRunSignatureV1(TerrainPlayerRunSignatureInput input) {
  final records = <String>[
    _canonicalRecord([
      'terrain-player-run-v1',
      input.seed.toString(),
      input.characterId,
    ]),
  ];
  for (var index = 0; index < input.commands.length; index += 1) {
    final command = input.commands[index];
    records.add(
      _canonicalRecord([
        'command-v1',
        index.toString(),
        command.tick.toString(),
        command.kind,
        command.value0.toString(),
        command.value1.toString(),
      ]),
    );
  }
  final checkpoints =
      List<TerrainPlayerDebugSnapshot>.of(input.contactCheckpoints)
        ..sort((left, right) {
          final tickOrder = left.tick.compareTo(right.tick);
          return tickOrder != 0
              ? tickOrder
              : left.entityId.compareTo(right.entityId);
        });
  for (final checkpoint in checkpoints) {
    records.add(_terrainPlayerContactRecordV2(checkpoint));
  }
  for (var index = 0; index < input.eventCodes.length; index += 1) {
    records.add(
      _canonicalRecord(['event-v1', index.toString(), input.eventCodes[index]]),
    );
  }
  records.add(
    _canonicalRecord([
      'final-v1',
      input.finalTick.toString(),
      input.finalBodyXTicks.toString(),
      input.finalBodyYTicks.toString(),
      input.finalVelocityXTicks.toString(),
      input.finalVelocityYTicks.toString(),
      input.finalHealth100.toString(),
      input.finalMana100.toString(),
      input.finalStamina100.toString(),
      input.distanceXTicks.toString(),
      input.score.toString(),
      input.runEndReason,
      input.rngState.toString(),
    ]),
  );
  return _signature(records);
}

String _terrainPlayerContactRecordV2(TerrainPlayerDebugSnapshot snapshot) {
  final fields = <String>[
    'terrain-contacts-v2',
    snapshot.tick.toString(),
    snapshot.entityId.toString(),
    snapshot.capsuleCenterXTicks.toString(),
    snapshot.capsuleCenterYTicks.toString(),
    snapshot.capsuleRadiusTicks.toString(),
    snapshot.capsuleVerticalHalfSegmentTicks.toString(),
    snapshot.requestedXTicks.toString(),
    snapshot.requestedYTicks.toString(),
    snapshot.gravityXTicks.toString(),
    snapshot.gravityYTicks.toString(),
    snapshot.resolvedXTicks.toString(),
    snapshot.resolvedYTicks.toString(),
    snapshot.supportedTravelTicks.toString(),
    snapshot.finalBodyXTicks.toString(),
    snapshot.finalBodyYTicks.toString(),
    snapshot.finalVelocityXTicks.toString(),
    snapshot.finalVelocityYTicks.toString(),
    snapshot.geometryVersion.toString(),
    snapshot.grounded ? '1' : '0',
    snapshot.supportEdgeId?.canonicalKey ?? '',
    snapshot.supportPointXTicks.toString(),
    snapshot.supportPointYTicks.toString(),
    snapshot.supportNormalXTicks.toString(),
    snapshot.supportNormalYTicks.toString(),
    snapshot.supportTangentXTicks.toString(),
    snapshot.supportTangentYTicks.toString(),
    snapshot.hitLeft ? '1' : '0',
    snapshot.hitRight ? '1' : '0',
    snapshot.hitCeiling ? '1' : '0',
    snapshot.wallNormalXTicks.toString(),
    snapshot.wallNormalYTicks.toString(),
    snapshot.ceilingNormalXTicks.toString(),
    snapshot.ceilingNormalYTicks.toString(),
    snapshot.usedStep ? '1' : '0',
    snapshot.usedSnap ? '1' : '0',
    snapshot.usedRecovery ? '1' : '0',
    snapshot.contactIterations.toString(),
    snapshot.recoveryIterations.toString(),
    snapshot.candidateCount.toString(),
    snapshot.queryCellsVisited.toString(),
    snapshot.diagnostic.name,
    snapshot.blockingContacts.length.toString(),
  ];
  for (final contact in snapshot.blockingContacts) {
    fields
      ..add(contact.edgeId.canonicalKey)
      ..add(contact.kind.name)
      ..add(contact.feature.name)
      ..add(contact.normalXTicks.toString())
      ..add(contact.normalYTicks.toString());
  }
  return _canonicalRecord(fields);
}

String _canonicalRecord(List<String> fields) =>
    fields.map((field) => '${utf8.encode(field).length}:$field').join('|');

String _signature(Iterable<String> records) =>
    sha256.convert(utf8.encode(records.join('\n'))).toString();
