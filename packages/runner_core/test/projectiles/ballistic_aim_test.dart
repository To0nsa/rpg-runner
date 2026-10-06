import 'dart:math' as math;

import 'package:runner_core/projectiles/ballistic_aim.dart';
import 'package:test/test.dart';

void main() {
  for (final hz in [30, 60, 120]) {
    for (final direction in [-1, 1]) {
      for (final velocity in [(0.0, 0.0), (40.0, -15.0)]) {
        test(
          'intercepts from $direction at $hz Hz with target motion $velocity',
          () {
            const speed = 420.0;
            const gravity = 600.0;
            const windup = .6;
            const offset = 18.0;
            final x = direction * 230.0;
            final vx = direction * velocity.$1;
            final vy = velocity.$2;
            final aim = solveBallisticAim(
              sourceX: 0,
              sourceY: -31.5,
              targetX: x,
              targetY: 0,
              targetVelX: vx,
              targetVelY: vy,
              windupSeconds: windup,
              originOffset: offset,
              speed: speed,
              gravityY: gravity,
              tickHz: hz,
              maxFlightSeconds: 6,
            )!;
            final t = aim.flightSeconds;
            expect(aim.dirX.sign, direction);
            expect(aim.dirY, lessThan(0));
            expect(t, lessThan(1.3));
            expect(
              aim.dirX * aim.dirX + aim.dirY * aim.dirY,
              closeTo(1, 1e-12),
            );
            expect(
              aim.dirX * (offset + speed * t),
              closeTo(x + vx * (windup + t), 1e-7),
            );
            expect(
              -31.5 +
                  aim.dirY * (offset + speed * t) +
                  gravity * t * (t + 1 / hz) / 2,
              closeTo(vy * (windup + t), 1e-7),
            );
          },
        );
      }
    }
  }

  test('chooses the low arc and keeps a tangent maximum-range solution', () {
    BallisticAim? solve(double x) => solveBallisticAim(
      sourceX: 0,
      sourceY: 0,
      targetX: x,
      targetY: 0,
      targetVelX: 0,
      // Cancels the half-tick term so the continuous maximum has an exact fixture.
      targetVelY: 600 / 120,
      speed: 420,
      gravityY: 600,
      tickHz: 60,
      maxFlightSeconds: 6,
    );
    expect(solve(200)!.flightSeconds, lessThan(.7));
    final tangent = solve(420 * 420 / 600)!;
    expect(tangent.flightSeconds, closeTo(math.sqrt(2) * 420 / 600, 1e-7));
    expect(solve(420 * 420 / 600 + 1), isNull);
  });

  test('rejects unreachable targets and intercepts beyond expiry', () {
    BallisticAim? solve({double x = 100, double vx = 0, double lifetime = 6}) =>
        solveBallisticAim(
          sourceX: 0,
          sourceY: 0,
          targetX: x,
          targetY: 0,
          targetVelX: vx,
          targetVelY: 0,
          speed: 420,
          gravityY: 600,
          tickHz: 60,
          maxFlightSeconds: lifetime,
        );
    expect(solve(x: 1000), isNull);
    expect(solve(vx: 500), isNull);
    expect(solve(lifetime: .1), isNull);
  });

  test('zero-gravity levels retain straight intercepts', () {
    final aim = solveBallisticAim(
      sourceX: 0,
      sourceY: 0,
      targetX: 230,
      targetY: 0,
      targetVelX: 40,
      targetVelY: 0,
      windupSeconds: .5,
      originOffset: 18,
      speed: 420,
      gravityY: 0,
      tickHz: 60,
      maxFlightSeconds: 6,
    )!;
    expect(aim.dirX, 1);
    expect(aim.dirY, 0);
    expect(aim.flightSeconds, closeTo((250 - 18) / (420 - 40), 1e-10));
  });
}
