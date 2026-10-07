import '../combat/ai_target_policy.dart';
import '../enemies/enemy_id.dart';
import '../npcs/npc_id.dart';
import '../snapshots/enums.dart';
import '../track/chunk_pattern.dart';
import 'encounter_limits.dart';

/// Chunk-local entry rectangle, in world units; boundary contact activates it.
final class EncounterTrigger {
  EncounterTrigger({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  }) {
    if (![x, y, width, height].every((v) => v.isFinite) ||
        width <= 0 ||
        height <= 0 ||
        !(x + width).isFinite ||
        !(y + height).isFinite) {
      throw ArgumentError(
        'Encounter trigger must be a finite positive rectangle.',
      );
    }
  }
  final double x;
  final double y;
  final double width;
  final double height;

  /// Inclusive slab intersection also handles an initial stationary sample.
  bool intersectsSweep(double fromX, double fromY, double toX, double toY) {
    var enter = 0.0;
    var exit = 1.0;
    for (final axis in [
      (fromX, toX - fromX, x, x + width),
      (fromY, toY - fromY, y, y + height),
    ]) {
      final (origin, delta, low, high) = axis;
      if (delta == 0) {
        if (origin < low || origin > high) return false;
        continue;
      }
      var a = (low - origin) / delta;
      var b = (high - origin) / delta;
      if (a > b) {
        final swap = a;
        a = b;
        b = swap;
      }
      if (a > enter) enter = a;
      if (b < exit) exit = b;
      if (enter > exit) return false;
    }
    return true;
  }
}

/// Immutable authored placement; vertical support is resolved by terrain.
sealed class EncounterParticipant {
  EncounterParticipant({
    required this.id,
    required this.x,
    required this.facing,
    required this.placement,
  }) {
    _validateId(id);
    if (!x.isFinite || x < 0) throw ArgumentError.value(x, 'x');
  }
  final String id;
  final double x;
  final Facing facing;
  final SpawnPlacementMode placement;
}

final class EncounterNpcPlacement extends EncounterParticipant {
  EncounterNpcPlacement({
    required super.id,
    required this.npcId,
    required super.x,
    super.facing = Facing.right,
    super.placement = SpawnPlacementMode.ground,
  });
  final NpcId npcId;
}

final class EncounterEnemyPlacement extends EncounterParticipant {
  EncounterEnemyPlacement({
    required super.id,
    required this.enemyId,
    required super.x,
    super.facing = Facing.left,
    super.placement = SpawnPlacementMode.ground,
    this.targetPolicy,
  });
  final EnemyId enemyId;
  final AiTargetPolicy? targetPolicy;
}

/// Frozen rescue roster. Empty roles may be saved, but cannot enter runtime.
final class EncounterDefinition {
  EncounterDefinition({
    required this.id,
    required this.name,
    required this.trigger,
    Iterable<EncounterNpcPlacement> npcs = const [],
    Iterable<EncounterEnemyPlacement> enemies = const [],
    this.targetPolicy = AiTargetPolicy.preferEncounterNpcs,
    this.pointsPerNpc,
  }) : npcs = List.unmodifiable(npcs),
       enemies = List.unmodifiable(enemies) {
    _validateId(id);
    if (name.trim().isEmpty) throw ArgumentError.value(name, 'name');
    if (this.enemies.any((enemy) => enemy.enemyId.isArenaOnly)) {
      throw ArgumentError(
        'Bosses require their own arena, outside rescue rosters.',
      );
    }
    if (pointsPerNpc != null) EncounterLimits.validatePoints(pointsPerNpc!);
    if (this.npcs.length > EncounterLimits.maxNpcsPerEncounter ||
        this.enemies.length > EncounterLimits.maxEnemiesPerEncounter) {
      throw ArgumentError('Encounter participant capacity exceeded.');
    }
    final ids = <String>{};
    for (final member in [...this.npcs, ...this.enemies]) {
      if (!ids.add(member.id)) {
        throw ArgumentError('Duplicate member ${member.id}.');
      }
    }
  }
  final String id;
  final String name;
  final EncounterTrigger trigger;
  final List<EncounterNpcPlacement> npcs;
  final List<EncounterEnemyPlacement> enemies;
  final AiTargetPolicy targetPolicy;
  final int? pointsPerNpc;

  /// Shared readiness gate; precise full-body support is checked at placement.
  void validateForChunk(double width, {bool requireComplete = true}) {
    if (!width.isFinite ||
        width <= 0 ||
        trigger.x < 0 ||
        trigger.x + trigger.width > width ||
        [...npcs, ...enemies].any((member) => member.x >= width)) {
      throw ArgumentError('Encounter $id must fit its owning chunk.');
    }
    if (requireComplete && (npcs.isEmpty || enemies.isEmpty)) {
      throw ArgumentError(
        'Encounter $id needs at least one NPC and one enemy.',
      );
    }
  }
}

void _validateId(String id) {
  if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(id)) {
    throw ArgumentError.value(
      id,
      'id',
      'Use a stable lowercase snake_case ID.',
    );
  }
}
