import '../snapshots/enums.dart';
import 'trap_geometry.dart';
import 'trap_catalog.dart';
import 'trap_id.dart';

/// Immutable authored placement. Trigger offsets never change when facing does.
/// List order is canonical; its ordinal identifies a placement within a chunk.
final class TrapPlacement {
  const TrapPlacement({
    required this.trapId,
    required this.x,
    required this.y,
    required this.trigger,
    this.facing = Facing.right,
    int? damage100,
    int? windupMs,
  }) : _damage100 = damage100,
       _windupMs = windupMs;

  static const maxDamage100 = 100000;
  static const maxWindupMs = 30000;
  final int? _damage100, _windupMs;

  /// Base impact damage in hundredths of HP; omission uses the catalog default.
  int get damage100 => _damage100 ?? TrapCatalog.get(trapId).damage100;

  /// Time to the first harmful pose (or dart launch), in integer milliseconds.
  int get windupMs => _windupMs ?? TrapCatalog.get(trapId).windupMs;

  final TrapId trapId;
  final int x;
  final int y;
  final Facing facing;
  final TrapRect trigger;

  TrapPlacement copyWith({
    int? x,
    int? y,
    Facing? facing,
    TrapRect? trigger,
    int? damage100,
    int? windupMs,
  }) => TrapPlacement(
    trapId: trapId,
    x: x ?? this.x,
    y: y ?? this.y,
    facing: facing ?? this.facing,
    trigger: trigger ?? this.trigger,
    damage100: damage100 ?? this.damage100,
    windupMs: windupMs ?? this.windupMs,
  );

  Map<String, Object> toJson() => {
    'trapId': trapId.sourceKey,
    'x': x,
    'y': y,
    if (trapId != TrapId.spike) 'facing': facing.name,
    'trigger': trigger.toJson(),
    if (damage100 != TrapCatalog.get(trapId).damage100) 'damage100': damage100,
    if (windupMs != TrapCatalog.get(trapId).windupMs) 'windupMs': windupMs,
  };

  @override
  bool operator ==(Object other) =>
      other is TrapPlacement && compareTrapPlacements(this, other) == 0;
  @override
  int get hashCode =>
      Object.hash(trapId, x, y, facing, trigger, damage100, windupMs);
}

/// Lexicographic source order: position, type, facing, trigger, then combat tuning.
int compareTrapPlacements(TrapPlacement a, TrapPlacement b) {
  final pairs = [
    (a.x, b.x),
    (a.y, b.y),
    (a.trapId.index, b.trapId.index),
    (a.facing.index, b.facing.index),
    (a.trigger.offsetX, b.trigger.offsetX),
    (a.trigger.offsetY, b.trigger.offsetY),
    (a.trigger.width, b.trigger.width),
    (a.trigger.height, b.trigger.height),
    (a.damage100, b.damage100),
    (a.windupMs, b.windupMs),
  ];
  for (final (left, right) in pairs) {
    final order = left.compareTo(right);
    if (order != 0) return order;
  }
  return 0;
}

/// Value attribution survives launcher culling and later Poison refreshes.
final class TrapSourceRef {
  const TrapSourceRef({
    required this.trapId,
    required this.chunkKey,
    required this.chunkIndex,
    required this.placementOrdinal,
  });
  final TrapId trapId;
  final String chunkKey;
  final int chunkIndex;
  final int placementOrdinal;
  String get runtimeId => '$chunkIndex:$chunkKey:$placementOrdinal';
  @override
  bool operator ==(Object other) =>
      other is TrapSourceRef &&
      trapId == other.trapId &&
      chunkKey == other.chunkKey &&
      chunkIndex == other.chunkIndex &&
      placementOrdinal == other.placementOrdinal;
  @override
  int get hashCode =>
      Object.hash(trapId, chunkKey, chunkIndex, placementOrdinal);
}
