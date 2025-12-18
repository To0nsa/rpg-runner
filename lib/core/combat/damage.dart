import '../ecs/entity_id.dart';

class DamageRequest {
  const DamageRequest({
    required this.target,
    required this.amount,
    this.source,
  });

  final EntityId target;
  final double amount;
  final EntityId? source;
}

