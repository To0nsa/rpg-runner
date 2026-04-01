import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/widgets/prefab_overlay_interaction.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/widgets/prefab_scene_values.dart';

void main() {
  test('anchor drag is clamped to authoring bounds', () {
    const drag = PrefabOverlayDragState(
      pointer: 1,
      handle: PrefabOverlayHandleType.anchor,
      startLocal: Offset(0, 0),
      startValues: PrefabSceneValues(
        anchorX: 8,
        anchorY: 8,
        colliderOffsetX: 0,
        colliderOffsetY: 0,
        colliderWidth: 16,
        colliderHeight: 16,
      ),
      zoom: 2,
      boundsWidthPx: 12,
      boundsHeightPx: 10,
    );

    final next = PrefabOverlayInteraction.valuesFromDrag(
      drag: drag,
      currentLocal: const Offset(20, 12),
    );

    expect(next.anchorX, 12);
    expect(next.anchorY, 10);
    expect(next.colliderWidth, 16);
    expect(next.colliderHeight, 16);
  });

  test('collider right drag resizes width and updates center offset', () {
    const drag = PrefabOverlayDragState(
      pointer: 1,
      handle: PrefabOverlayHandleType.colliderRight,
      startLocal: Offset(0, 0),
      startValues: PrefabSceneValues(
        anchorX: 0,
        anchorY: 0,
        colliderOffsetX: 0,
        colliderOffsetY: 0,
        colliderWidth: 10,
        colliderHeight: 8,
      ),
      zoom: 1,
      boundsWidthPx: 100,
      boundsHeightPx: 100,
    );

    final next = PrefabOverlayInteraction.valuesFromDrag(
      drag: drag,
      currentLocal: const Offset(4, 0),
    );

    expect(next.colliderWidth, 14);
    expect(next.colliderOffsetX, 2);
    expect(next.colliderHeight, 8);
  });
}
