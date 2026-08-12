import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/ecs/hit/capsule_hit_utils.dart';

void main() {
  test('crossing capsule spines overlap', () {
    expect(
      capsulesOverlap(
        firstAx: -5,
        firstAy: 0,
        firstBx: 5,
        firstBy: 0,
        firstRadius: 1,
        secondAx: 0,
        secondAy: -5,
        secondBx: 0,
        secondBy: 5,
        secondRadius: 1,
      ),
      isTrue,
    );
  });

  test('parallel capsules separated beyond their radii miss', () {
    expect(
      capsulesOverlap(
        firstAx: 0,
        firstAy: 0,
        firstBx: 10,
        firstBy: 0,
        firstRadius: 1,
        secondAx: 0,
        secondAy: 2.01,
        secondBx: 10,
        secondBy: 2.01,
        secondRadius: 1,
      ),
      isFalse,
    );
  });

  test('capsule tangency counts as contact', () {
    expect(
      capsulesOverlap(
        firstAx: 0,
        firstAy: 0,
        firstBx: 10,
        firstBy: 0,
        firstRadius: 1,
        secondAx: 0,
        secondAy: 2,
        secondBx: 10,
        secondBy: 2,
        secondRadius: 1,
      ),
      isTrue,
    );
  });

  test('endpoint contact is detected', () {
    expect(
      capsulesOverlap(
        firstAx: 0,
        firstAy: 0,
        firstBx: 4,
        firstBy: 0,
        firstRadius: 1,
        secondAx: 6,
        secondAy: 0,
        secondBx: 10,
        secondBy: 0,
        secondRadius: 1,
      ),
      isTrue,
    );
  });

  test('circle-circle and circle-segment degeneracies are supported', () {
    expect(
      capsulesOverlap(
        firstAx: 0,
        firstAy: 0,
        firstBx: 0,
        firstBy: 0,
        firstRadius: 1,
        secondAx: 2,
        secondAy: 0,
        secondBx: 2,
        secondBy: 0,
        secondRadius: 1,
      ),
      isTrue,
    );
    expect(
      capsulesOverlap(
        firstAx: 0,
        firstAy: 3.01,
        firstBx: 0,
        firstBy: 3.01,
        firstRadius: 1,
        secondAx: -4,
        secondAy: 0,
        secondBx: 4,
        secondBy: 0,
        secondRadius: 2,
      ),
      isFalse,
    );
  });

  test('overlapping enclosing AABB corners do not imply capsule contact', () {
    expect(
      capsulesOverlap(
        firstAx: 0,
        firstAy: -4,
        firstBx: 0,
        firstBy: 4,
        firstRadius: 2,
        secondAx: 3.9,
        secondAy: 7.9,
        secondBx: 3.9,
        secondBy: 15.9,
        secondRadius: 2,
      ),
      isFalse,
    );
  });
}
