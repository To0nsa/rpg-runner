import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/navigation/utils/jump_template.dart';

void main() {
  test('jump template is deterministic for the same profile', () {
    const profile = JumpProfile(
      jumpSpeed: 600.0,
      gravityY: 1200.0,
      maxAirTicks: 60,
      airSpeedX: 240.0,
      dtSeconds: 1.0 / 60.0,
      agentHalfWidth: 12.0,
    );

    final a = JumpReachabilityTemplate.build(profile);
    final b = JumpReachabilityTemplate.build(profile);

    expect(a.samples.length, b.samples.length);
    for (var i = 0; i < a.samples.length; i += 1) {
      final sa = a.samples[i];
      final sb = b.samples[i];
      expect(sa.tick, sb.tick);
      expect(sa.prevY, closeTo(sb.prevY, 1e-12));
      expect(sa.y, closeTo(sb.y, 1e-12));
      expect(sa.velY, closeTo(sb.velY, 1e-12));
      expect(sa.maxDx, closeTo(sb.maxDx, 1e-12));
    }
  });

  test('finds earliest landing tick that matches discrete integration', () {
    const profile = JumpProfile(
      jumpSpeed: 600.0,
      gravityY: 1200.0,
      maxAirTicks: 120,
      airSpeedX: 200.0,
      dtSeconds: 0.1,
      agentHalfWidth: 12.0,
    );

    final template = JumpReachabilityTemplate.build(profile);
    final landing = template.findFirstLanding(dy: 0.0, dxMin: 0.0, dxMax: 0.0);
    expect(landing, isNotNull);

    var y = 0.0;
    var velY = -profile.jumpSpeed;
    int? foundTick;
    for (var tick = 1; tick <= profile.maxAirTicks; tick += 1) {
      final prevY = y;
      velY += profile.gravityY * profile.dtSeconds;
      y += velY * profile.dtSeconds;
      if (velY >= 0 && prevY <= 0.0 && y >= 0.0) {
        foundTick = tick;
        break;
      }
    }

    expect(foundTick, isNotNull);
    expect(landing!.tick, foundTick);
  });

  test('rejects landing when horizontal range is out of reach', () {
    const profile = JumpProfile(
      jumpSpeed: 600.0,
      gravityY: 1200.0,
      maxAirTicks: 60,
      airSpeedX: 100.0,
      dtSeconds: 1.0 / 60.0,
      agentHalfWidth: 12.0,
    );

    final template = JumpReachabilityTemplate.build(profile);
    final landing = template.findFirstLanding(
      dy: 0.0,
      dxMin: 1000.0,
      dxMax: 1100.0,
    );
    expect(landing, isNull);
  });
}

