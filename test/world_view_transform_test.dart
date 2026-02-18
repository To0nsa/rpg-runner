import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/spatial/world_view_transform.dart';

void main() {
  test('maps world center to view center', () {
    const transform = WorldViewTransform(
      cameraCenterX: 300.0,
      cameraCenterY: 135.0,
      viewWidth: 600.0,
      viewHeight: 270.0,
    );

    expect(transform.worldToViewX(300.0), closeTo(300.0, 1e-9));
    expect(transform.worldToViewY(135.0), closeTo(135.0, 1e-9));
  });

  test('maps view edges correctly', () {
    const transform = WorldViewTransform(
      cameraCenterX: 300.0,
      cameraCenterY: 135.0,
      viewWidth: 600.0,
      viewHeight: 270.0,
    );

    expect(transform.viewLeftX, closeTo(0.0, 1e-9));
    expect(transform.viewRightX, closeTo(600.0, 1e-9));
    expect(transform.viewTopY, closeTo(0.0, 1e-9));
    expect(transform.viewBottomY, closeTo(270.0, 1e-9));
  });

  test('world-view roundtrip is stable', () {
    const transform = WorldViewTransform(
      cameraCenterX: -120.0,
      cameraCenterY: 40.0,
      viewWidth: 600.0,
      viewHeight: 270.0,
    );

    const worldX = 1234.25;
    const worldY = -876.5;
    final viewX = transform.worldToViewX(worldX);
    final viewY = transform.worldToViewY(worldY);

    expect(transform.viewToWorldX(viewX), closeTo(worldX, 1e-9));
    expect(transform.viewToWorldY(viewY), closeTo(worldY, 1e-9));
  });
}
