import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/chunks/chunk_scene_coordinate_policy.dart';

void main() {
  test('scene coordinate policy rounds exact ties away from zero', () {
    expect(quantizeChunkSceneCoordinate(8, step: 16), 16);
    expect(quantizeChunkSceneCoordinate(-8, step: 16), -16);
    expect(quantizeChunkSceneCoordinate(7.9, step: 16), 0);
    expect(quantizeChunkSceneCoordinate(-7.9, step: 16), 0);
  });

  test('prefab policy distinguishes grid and integer-pixel gestures', () {
    expect(
      quantizeChunkPrefabGestureCoordinate(
        23.5,
        tileSize: 16,
        snapToGrid: true,
      ),
      16,
    );
    expect(
      quantizeChunkPrefabGestureCoordinate(
        23.5,
        tileSize: 16,
        snapToGrid: false,
      ),
      24,
    );
    expect(preserveChunkExactPixelCoordinate(23), 23);
  });

  test('invalid coordinate inputs fail before candidate construction', () {
    expect(
      () => quantizeChunkSceneCoordinate(double.nan, step: 1),
      throwsArgumentError,
    );
    expect(() => quantizeChunkSceneCoordinate(1, step: 0), throwsArgumentError);
  });
}
