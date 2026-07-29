import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:test/test.dart';

void main() {
  test('terrain request composes control and gravity without mutation', () {
    final request = TerrainMotionRequest(
      displacementXTicks: 11,
      displacementYTicks: -7,
      gravityXTicks: 3,
      gravityYTicks: 5,
      surfaceDirectionSign: -1,
      mode: TerrainMotionMode.groundedSurface,
    );
    expect(request.composedXTicks, 14);
    expect(request.composedYTicks, -2);
    expect(request.surfaceDirectionSign, -1);
    expect(request.mode, TerrainMotionMode.groundedSurface);
  });

  test('terrain request rejects an invalid direction', () {
    expect(
      () => TerrainMotionRequest(
        displacementXTicks: 0,
        displacementYTicks: 0,
        surfaceDirectionSign: 0,
        mode: TerrainMotionMode.worldSpace,
      ),
      throwsArgumentError,
    );
  });
}
