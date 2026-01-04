import '../ecs/entity_id.dart';
import '../enemies/enemy_id.dart';
import '../events/game_event.dart';
import '../projectiles/projectile_id.dart';
import '../spells/spell_id.dart';

class DamageRequest {
  const DamageRequest({
    required this.target,
    required this.amount,
    this.source,
    this.sourceKind = DeathSourceKind.unknown,
    this.sourceEnemyId,
    this.sourceProjectileId,
    this.sourceSpellId,
  });

  final EntityId target;
  final double amount;
  final EntityId? source;
  final DeathSourceKind sourceKind;
  final EnemyId? sourceEnemyId;
  final ProjectileId? sourceProjectileId;
  final SpellId? sourceSpellId;
}
