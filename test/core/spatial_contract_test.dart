import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/contracts/render_contract.dart';
import 'package:rpg_runner/core/contracts/spatial_contract.dart';
import 'package:rpg_runner/core/levels/level_world_constants.dart';

void main() {
  test('spatial contract constants match render contract aliases', () {
    expect(virtualViewportWidth, virtualWidth);
    expect(virtualViewportHeight, virtualHeight);
    expect(virtualCameraCenterY, defaultLevelCameraCenterY);
  });

  test('spatial contract uses positive dimensions and y-down orientation', () {
    expect(virtualViewportWidth, greaterThan(0));
    expect(virtualViewportHeight, greaterThan(0));
    expect(virtualCameraCenterX, closeTo(virtualViewportWidth * 0.5, 1e-9));
    expect(virtualCameraCenterY, closeTo(virtualViewportHeight * 0.5, 1e-9));
    expect(yAxisPointsDown, isTrue);
  });
}
