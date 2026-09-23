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
    for (final frame in def.frames) {
      final h = frame.hitbox;
      if (h == null) continue;
      final ax = p.x + h.ax * sign, bx = p.x + h.bx * sign;
      final ay = p.y + h.ay, by = p.y + h.by;
      if (!contains(
        (ax < bx ? ax : bx) - h.radius,
        (ay < by ? ay : by) - h.radius,
        (ax > bx ? ax : bx) + h.radius,
        (ay > by ? ay : by) + h.radius,
      )) {
        throw ArgumentError(
          'Trap ${p.trapId.sourceKey} damage sweep must fit inside the chunk.',
        );
      }
    }
  }
}
