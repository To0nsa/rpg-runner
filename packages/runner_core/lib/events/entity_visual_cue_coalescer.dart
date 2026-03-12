import '../combat/damage_type.dart';
import '../combat/status/status.dart';
import '../ecs/entity_id.dart';
import 'game_event.dart';

/// Per-tick coalescer for entity visual cues.
///
/// This avoids render spam when multiple impacts resolve in the same tick by
/// keeping only one cue per `(entity, kind)` pair using the highest intensity.
class EntityVisualCueCoalescer {
  int _tick = -1;
  final Map<int, _EntityVisualCueAggregate> _byKey =
      <int, _EntityVisualCueAggregate>{};

  /// Starts a new aggregation window for [tick].
  void resetForTick(int tick) {
    _tick = tick;
    _byKey.clear();
  }

  /// Records a cue candidate for the active tick.
  void record({
    required int tick,
    required EntityId entityId,
    required EntityVisualCueKind kind,
    required int intensityBp,
    DamageType? damageType,
    StatusResourceType? resourceType,
  }) {
    if (_tick != tick) return;
    if (intensityBp <= 0) return;

    final key = _aggregateKey(entityId, kind);
    final existing = _byKey[key];
    if (existing == null) {
      _byKey[key] = _EntityVisualCueAggregate(
        entityId: entityId,
        kind: kind,
        intensityBp: intensityBp,
        damageType: damageType,
        resourceType: resourceType,
      );
      return;
    }

    if (intensityBp > existing.intensityBp) {
      existing.intensityBp = intensityBp;
      existing.damageType = damageType;
      existing.resourceType = resourceType;
    }
  }

  /// Emits coalesced events for the current tick.
  void emit(void Function(EntityVisualCueEvent event) sink) {
    if (_byKey.isEmpty) return;
    for (final aggregate in _byKey.values) {
      sink(
        EntityVisualCueEvent(
          tick: _tick,
          entityId: aggregate.entityId,
          kind: aggregate.kind,
          intensityBp: aggregate.intensityBp,
          damageType: aggregate.damageType,
          resourceType: aggregate.resourceType,
        ),
      );
    }
  }

  int _aggregateKey(int entityId, EntityVisualCueKind kind) {
    return (entityId << 3) ^ kind.index;
  }
}

class _EntityVisualCueAggregate {
  _EntityVisualCueAggregate({
    required this.entityId,
    required this.kind,
    required this.intensityBp,
    required this.damageType,
    required this.resourceType,
  });

  final int entityId;
  final EntityVisualCueKind kind;
  int intensityBp;
  DamageType? damageType;
  StatusResourceType? resourceType;
}
