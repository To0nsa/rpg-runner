import 'package:flutter_test/flutter_test.dart';
import 'package:walkscape_runner/core/ecs/world.dart';

void main() {
  test('EcsWorld double-free bug', () {
    final world = EcsWorld();
    final e1 = world.createEntity();
    expect(e1, equals(1));

    world.destroyEntity(e1);
    // Double free
    world.destroyEntity(e1);

    final e2 = world.createEntity();
    final e3 = world.createEntity();

    // If bug exists, e2 == e3 because 1 was added to free list twice
    expect(e2, isNot(equals(e3)), reason: 'Entities should have unique IDs');
  });
}
