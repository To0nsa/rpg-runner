import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/util/velocity_math.dart';

void main() {
  test('applyAccelDecel accelerates toward the desired velocity', () {
    final next = applyAccelDecel(
      current: 0.0,
      desired: 10.0,
      dtSeconds: 0.1,
      accelPerSecond: 20.0,
      decelPerSecond: 5.0,
    );

    expect(next, closeTo(2.0, 1e-9));
  });

  test('applyAccelDecel decelerates toward zero', () {
    final next = applyAccelDecel(
      current: 10.0,
      desired: 0.0,
      dtSeconds: 0.1,
      accelPerSecond: 20.0,
      decelPerSecond: 5.0,
    );

    expect(next, closeTo(9.5, 1e-9));
  });

  test('applyAccelDecel snaps to zero under minStopSpeed', () {
    final next = applyAccelDecel(
      current: 0.4,
      desired: 0.0,
      dtSeconds: 0.1,
      accelPerSecond: 20.0,
      decelPerSecond: 5.0,
      minStopSpeed: 0.5,
    );

    expect(next, closeTo(0.0, 1e-9));
  });
}
