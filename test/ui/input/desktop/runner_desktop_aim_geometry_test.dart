import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:runner_core/snapshots/camera_snapshot.dart';
import 'package:rpg_runner/ui/input/desktop/runner_desktop_aim_geometry.dart';
import 'package:rpg_runner/ui/viewport/viewport_metrics.dart';

void main() {
  test('maps camera-relative player position through a fitted viewport', () {
    final geometry = RunnerDesktopAimGeometry.fromWorld(
      metrics: const ViewportMetrics(
        viewW: 640,
        viewH: 360,
        offsetX: 80,
        offsetY: 40,
      ),
      camera: const CameraSnapshot(
        centerX: 100.25,
        centerY: 50.75,
        viewWidth: 320,
        viewHeight: 180,
      ),
      playerWorldPosition: const Offset(116.6, 42.4),
    );

    expect(geometry.viewportRect, const Rect.fromLTWH(80, 40, 640, 360));
    expect(geometry.playerPosition, const Offset(432, 204));
    expect(geometry.directionFor(const Offset(442, 204)), const Offset(1, 0));
    expect(geometry.directionFor(const Offset(432, 184)), const Offset(0, -1));
  });

  test('normalizes diagonal aim with non-centered viewport alignment', () {
    const geometry = RunnerDesktopAimGeometry(
      viewportRect: Rect.fromLTWH(12, 30, 400, 200),
      playerPosition: Offset(100, 100),
    );

    final direction = geometry.directionFor(const Offset(130, 140));

    expect(direction, isNotNull);
    expect(direction!.dx, closeTo(0.6, 1e-12));
    expect(direction.dy, closeTo(0.8, 1e-12));
  });

  test('letterbox and zero-length positions produce no aim', () {
    const geometry = RunnerDesktopAimGeometry(
      viewportRect: Rect.fromLTWH(100, 50, 320, 180),
      playerPosition: Offset(260, 140),
    );

    expect(geometry.directionFor(const Offset(99, 140)), isNull);
    expect(geometry.directionFor(const Offset(260, 49)), isNull);
    expect(geometry.directionFor(const Offset(260, 140)), isNull);
    expect(geometry.contains(const Offset(100, 50)), isTrue);
    expect(geometry.contains(const Offset(420, 230)), isFalse);
  });
}
