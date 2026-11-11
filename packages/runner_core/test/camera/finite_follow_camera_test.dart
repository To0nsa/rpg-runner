import 'package:runner_core/camera/finite_follow_camera.dart';
import 'package:test/test.dart';

void main() {
  for (final tickHz in [30, 60, 90]) {
    test(
      'follows right and left without autonomous scrolling at $tickHz Hz',
      () {
        final camera = _camera();
        for (var i = 0; i < tickHz; i++) {
          camera.updateTick(dtSeconds: 1 / tickHz, playerX: 300);
        }
        expect(camera.state.centerX, 300);
        expect(camera.state.speedX, 0);
        for (var i = 0; i < tickHz; i++) {
          final previous = camera.state.centerX;
          camera.updateTick(dtSeconds: 1 / tickHz, playerX: 1500);
          expect(camera.state.centerX, greaterThan(previous));
          expect(camera.right(), lessThanOrEqualTo(1800));
        }
        expect(camera.state.centerX, closeTo(1500, 0.5));
        for (var i = 0; i < tickHz; i++) {
          final previous = camera.state.centerX;
          camera.updateTick(dtSeconds: 1 / tickHz, playerX: 0);
          expect(camera.state.centerX, lessThan(previous));
          expect(camera.state.speedX, isNegative);
          expect(camera.left(), greaterThanOrEqualTo(0));
        }
        expect(camera.state.centerX, closeTo(300, 0.5));
        expect(camera.top(), 0);
        expect(camera.bottom(), 270);
      },
    );
  }

  test('freezes immediately when no living player is supplied', () {
    final camera = _camera();
    camera.updateTick(dtSeconds: 1 / 60, playerX: 1500);
    final x = camera.state.centerX;
    for (var i = 0; i < 120; i++) {
      camera.updateTick(dtSeconds: 1 / 60, playerX: null);
    }
    expect(camera.state.centerX, x);
    expect(camera.state.targetX, x);
    expect(camera.state.speedX, 0);
  });

  test('centers narrow and exactly viewport-sized worlds', () {
    for (final width in [200.0, 600.0]) {
      final camera = _camera(left: 100, right: 100 + width);
      for (final x in [-500.0, 0.0, 5000.0]) {
        camera.updateTick(dtSeconds: 1 / 60, playerX: x);
        expect(camera.state.centerX, 100 + width / 2);
        expect(camera.state.targetX, camera.state.centerX);
        expect(camera.state.speedX, 0);
      }
    }
  });

  test('identical fixed-tick inputs produce identical states', () {
    final first = _camera();
    final second = _camera();
    for (var tick = 0; tick < 240; tick++) {
      final playerX = tick < 120
          ? 300.0 + tick * 10
          : 1500.0 - (tick - 120) * 10;
      first.updateTick(dtSeconds: 1 / 60, playerX: playerX);
      second.updateTick(dtSeconds: 1 / 60, playerX: playerX);
      expect(first.state.centerX, second.state.centerX);
      expect(first.state.targetX, second.state.targetX);
      expect(first.state.speedX, second.state.speedX);
    }
  });

  test('rejects invalid bounds and inputs without corrupting state', () {
    for (final right in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => _camera(right: right), throwsArgumentError);
    }
    for (final invalid in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => _camera(width: invalid), throwsArgumentError);
      expect(() => _camera(rate: invalid), throwsArgumentError);
      final camera = _camera();
      final state = camera.state;
      expect(
        () => camera.updateTick(dtSeconds: invalid, playerX: 400),
        throwsArgumentError,
      );
      expect(camera.state, same(state));
    }
    final camera = _camera();
    final state = camera.state;
    expect(
      () => camera.updateTick(dtSeconds: 1 / 60, playerX: double.nan),
      throwsArgumentError,
    );
    expect(camera.state, same(state));
  });
}

FiniteFollowCamera _camera({
  double left = 0,
  double right = 1800,
  double width = 600,
  double rate = 8,
}) => FiniteFollowCamera(
  worldLeft: left,
  worldRight: right,
  viewWidth: width,
  viewHeight: 270,
  centerY: 135,
  playerX: 300,
  followRate: rate,
);
