import 'package:runner_core/ecs/world.dart';
import 'package:test/test.dart';

void main() {
  test('committed flight stays with its actor across removal and ID reuse', () {
    final world = EcsWorld(seed: 7);
    final first = world.createEntity();
    final second = world.createEntity();
    final store = world.flyingEnemyCombatMode;
    store.add(first);
    store.add(second);
    store.strikeVelocityX[store.indexOf(first)] = 200;
    store.strikeVelocityX[store.indexOf(second)] = -150;

    world.destroyEntity(first);
    expect(store.has(first), isFalse);
    expect(store.strikeVelocityX[store.indexOf(second)], -150);

    final recycled = world.createEntity();
    expect(recycled, first);
    store.add(recycled);
    expect(store.strikeVelocityX[store.indexOf(recycled)], 0);
    expect(store.strikeVelocityX[store.indexOf(second)], -150);

    world.destroyEntity(recycled);
    world.destroyEntity(second);
    expect(store.strikeVelocityX, isEmpty);
  });
}
