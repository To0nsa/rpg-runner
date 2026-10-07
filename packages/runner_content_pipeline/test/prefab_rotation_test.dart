import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:test/test.dart';

void main() {
  test('source rejects explicit null, wrong types and noncanonical angles', () {
    for (final value in [
      null,
      '90',
      true,
      -1,
      360,
      double.nan,
      double.infinity,
    ]) {
      expect(
        () => decodePrefabRotationDegrees(
          value,
          sourcePath: 'placement.rotationDegrees',
        ),
        throwsFormatException,
      );
    }
    expect(decodePrefabRotationDegrees(22.5, sourcePath: 'rotation'), 22.5);
  });
  test('author input wraps clockwise and counterclockwise turns', () {
    expect(normalizePrefabRotationDegrees(-90), 270);
    expect(normalizePrefabRotationDegrees(450.5), 90.5);
    expect(normalizePrefabRotationDegrees(360), 0);
    expect(
      () => normalizePrefabRotationDegrees(double.nan),
      throwsArgumentError,
    );
  });
}
