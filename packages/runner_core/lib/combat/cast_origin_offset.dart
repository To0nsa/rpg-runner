import '../ecs/entity_id.dart';
import '../ecs/world.dart';

/// Resolves projectile spawn origin offset from caster-owned configuration.
///
/// Precedence:
/// 1. [authoredCasterOffset] when provided.
/// 2. Fallback derived from caster collider size.
double resolveCasterProjectileOriginOffset(
  EcsWorld world,
  EntityId caster, {
  double? authoredCasterOffset,
}) {
  if (authoredCasterOffset != null) return authoredCasterOffset;

  var maxHalfExtent = 0.0;
  if (world.colliderAabb.has(caster)) {
    final aabbi = world.colliderAabb.indexOf(caster);
    final halfX = world.colliderAabb.halfX[aabbi];
    final halfY = world.colliderAabb.halfY[aabbi];
    maxHalfExtent = halfX > halfY ? halfX : halfY;
  }
  return maxHalfExtent * 0.5;
}
