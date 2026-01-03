import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/ecs/hit/capsule_hit_utils.dart';

void main() {
  test('capsule intersects AABB along a horizontal segment', () {
    final hit = capsuleIntersectsAabb(
      ax: 0,
      ay: 0,
      bx: 10,
      by: 0,
      radius: 1,
      minX: 4,
      minY: -1,
      maxX: 6,
      maxY: 1,
    );

    expect(hit, isTrue);
  });

  test('capsule intersects AABB along a vertical segment', () {
    final hit = capsuleIntersectsAabb(
      ax: 0,
      ay: 0,
      bx: 0,
      by: 10,
      radius: 0.5,
      minX: -0.5,
      minY: 4.5,
      maxX: 0.5,
      maxY: 5.5,
    );

    expect(hit, isTrue);
  });

  test('capsule misses AABB when diagonal is far away', () {
    final hit = capsuleIntersectsAabb(
      ax: 0,
      ay: 0,
      bx: 10,
      by: 10,
      radius: 0.5,
      minX: 9.5,
      minY: -0.5,
      maxX: 10.5,
      maxY: 0.5,
    );

    expect(hit, isFalse);
  });

  test('capsule intersects AABB when diagonal passes through', () {
    final hit = capsuleIntersectsAabb(
      ax: 0,
      ay: 0,
      bx: 10,
      by: 10,
      radius: 0.5,
      minX: 4.5,
      minY: 4.5,
      maxX: 5.5,
      maxY: 5.5,
    );

    expect(hit, isTrue);
  });
}
