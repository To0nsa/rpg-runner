import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/ecs/world.dart';

void main() {
  test('Entity ID recycling reuses destroyed IDs', () {
    final world = EcsWorld(seed: 0);

    // 1. Create entities (consume nextEntityId 1, 2, 3)
    final e1 = world.createEntity();
    final e2 = world.createEntity();
    final e3 = world.createEntity();

    expect(e1, 1);
    expect(e2, 2);
    expect(e3, 3);

    // 2. Destroy entity 2 (adds 2 to free list)
    world.destroyEntity(e2);

    // 3. Create a new entity (should reuse 2)
    final e4 = world.createEntity();
    expect(e4, 2);

    // 4. Create another entity (should consume nextEntityId 4)
    final e5 = world.createEntity();
    expect(e5, 4);

    // 5. Destroy entity 1 (adds 1 to free list)
    world.destroyEntity(e1);
    
    // 6. Reuse 1
    final e6 = world.createEntity();
    expect(e6, 1);
  });

  test('Recycled IDs work correctly with stores', () {
    final world = EcsWorld(seed: 0);
    final e1 = world.createEntity(); // ID 1

    world.transform.add(e1, posX: 10, posY: 20, velX: 0, velY: 0);
    expect(world.transform.has(e1), isTrue);

    world.destroyEntity(e1); // ID 1 recycled, components removed
    expect(world.transform.has(e1), isFalse);

    // e2 reuses ID 1
    final e2 = world.createEntity();
    expect(e2, e1);
    
    // Should be clean slate
    expect(world.transform.has(e2), isFalse);

    world.transform.add(e2, posX: 50, posY: 60, velX: 0, velY: 0);
    expect(world.transform.has(e2), isTrue);
    final idx = world.transform.indexOf(e2);
    expect(world.transform.posX[idx], 50.0);
  });
}
