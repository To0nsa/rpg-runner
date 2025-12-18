import '../world.dart';

class CooldownSystem {
  void step(EcsWorld world) {
    final store = world.cooldown;
    for (var i = 0; i < store.denseEntities.length; i += 1) {
      if (store.castCooldownTicksLeft[i] > 0) {
        store.castCooldownTicksLeft[i] -= 1;
      }
      if (store.meleeCooldownTicksLeft[i] > 0) {
        store.meleeCooldownTicksLeft[i] -= 1;
      }
    }
  }
}
