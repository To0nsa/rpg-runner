import 'dart:math' as math;

import '../snapshots/enums.dart';
import 'trap_catalog.dart';
import 'trap_geometry.dart';
import 'trap_id.dart';
import 'trap_placement.dart';

/// Shared source/runtime admission: strict order, full envelopes, eight traps.
void validateTrapPlacements(
  List<TrapPlacement> placements, {
  required int chunkWidth,
  required int chunkHeight,
}) {
  if (placements.length > 8) {
    throw ArgumentError('At most eight traps fit one chunk.');
  }
  for (var i = 0; i < placements.length; i++) {
    final p = placements[i];
    if (p.damage100 < 1 || p.damage100 > TrapPlacement.maxDamage100) {
      throw ArgumentError('Trap damage must be between 0.01 and 1000 HP.');
    }
    if (p.windupMs < 0 || p.windupMs > TrapPlacement.maxWindupMs) {
      throw ArgumentError('Trap wind-up must be between 0 and 30 seconds.');
    }
    if (i > 0 && compareTrapPlacements(placements[i - 1], p) >= 0) {
      throw ArgumentError(
        'Trap placements must be canonical without exact duplicates.',
      );
    }
    if (p.trapId == TrapId.spike && p.facing != Facing.right) {
      throw ArgumentError('Spikes have no facing variant.');
    }
    bool contains(double l, double t, double r, double b) =>
        l >= 0 &&
        t >= 0 &&
        r <= chunkWidth &&
        b <= chunkHeight &&
        r > l &&
        b > t;
    void rectangle(TrapRect rect, String label, {bool mirrored = false}) {
      final r = mirrored ? rect.mirrored() : rect;
      if (!contains(
        (p.x + r.offsetX).toDouble(),
        (p.y + r.offsetY).toDouble(),
        (p.x + r.right).toDouble(),
        (p.y + r.bottom).toDouble(),
      )) {
        throw ArgumentError(
          'Trap ${p.trapId.sourceKey} $label must fit inside the chunk.',
        );
      }
    }

    if (p.x < 0 || p.x > chunkWidth || p.y < 0 || p.y > chunkHeight) {
      throw ArgumentError('Trap anchor must fit inside the chunk.');
    }
    rectangle(p.trigger, 'trigger');
    final def = TrapCatalog.get(p.trapId);
    rectangle(def.spriteBounds, 'sprite', mirrored: p.facing == Facing.left);
    final sign = p.facing == Facing.left ? -1 : 1;
    for (var frameIndex = 0; frameIndex < def.frames.length; frameIndex++) {
      final frame = def.frames[frameIndex];
      final h = frame.hitbox;
      if (h == null) continue;
      final previous = frameIndex > 0
          ? def.frames[frameIndex - 1].hitbox ?? h
          : h;
      final radius = math.max(h.radius, previous.radius);
      final xs = [
        h.ax,
        h.bx,
        previous.ax,
        previous.bx,
      ].map((x) => p.x + x * sign);
      final ys = [h.ay, h.by, previous.ay, previous.by].map((y) => p.y + y);
      if (!contains(
        xs.reduce(math.min) - radius,
        ys.reduce(math.min) - radius,
        xs.reduce(math.max) + radius,
        ys.reduce(math.max) + radius,
      )) {
        throw ArgumentError(
          'Trap ${p.trapId.sourceKey} damage sweep must fit inside the chunk.',
        );
      }
    }
  }
}
