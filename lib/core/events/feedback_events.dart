part of 'game_event.dart';

/// Emitted when the player takes a direct combat impact.
///
/// This event is intended for non-authoritative render/UI feedback (camera
/// shake, haptics, edge flash). It is not emitted for status-effect ticks.
class PlayerImpactFeedbackEvent extends GameEvent {
  const PlayerImpactFeedbackEvent({
    required this.tick,
    required this.amount100,
    required this.sourceKind,
  });

  /// Simulation tick when the impact occurred.
  final int tick;

  /// Final damage applied to the player in fixed-point units (`100 == 1.0`).
  final int amount100;

  /// Source category that produced the impact.
  final DeathSourceKind sourceKind;
}

/// Visual pulse categories consumed by the render layer.
enum EntityVisualCueKind { directHit, dotPulse, resourcePulse }

/// Coalesced, per-entity visual pulse emitted by Core.
///
/// This event is render-only and intentionally does not encode style (colors,
/// shader choice). The Game layer maps these semantics to visuals.
class EntityVisualCueEvent extends GameEvent {
  const EntityVisualCueEvent({
    required this.tick,
    required this.entityId,
    required this.kind,
    required this.intensityBp,
    this.damageType,
    this.resourceType,
  });

  /// Simulation tick when the cue was produced.
  final int tick;

  /// Entity receiving the visual cue.
  final int entityId;

  /// Cue semantics (hit pulse vs DoT pulse vs RoT pulse).
  final EntityVisualCueKind kind;

  /// Relative strength in basis points (`10000 == 1.0`).
  final int intensityBp;

  /// Damage type metadata for DoT pulses (optional).
  final DamageType? damageType;

  /// Resource type metadata for resource pulses (optional).
  final StatusResourceType? resourceType;
}
