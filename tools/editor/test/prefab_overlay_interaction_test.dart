import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/shared/prefab_overlay_interaction.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/shared/prefab_scene_values.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';

void main() {
  test('anchor drag is clamped to authoring bounds', () {
    const drag = PrefabOverlayDragState(
      pointer: 1,
      handle: PrefabOverlayHandleType.anchor,
      startLocal: Offset(0, 0),
      startValues: PrefabSceneValues(
        anchorX: 8,
        anchorY: 8,
        colliders: <PrefabColliderDef>[
          PrefabColliderDef(offsetX: 0, offsetY: 0, width: 16, height: 16),
        ],
        selectedColliderIndex: 0,
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
        colliders: <PrefabColliderDef>[
          PrefabColliderDef(offsetX: 0, offsetY: 0, width: 10, height: 8),
        ],
        selectedColliderIndex: 0,
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

  test('dragging the selected collider preserves other collider drafts', () {
    const drag = PrefabOverlayDragState(
      pointer: 1,
      handle: PrefabOverlayHandleType.colliderRight,
      startLocal: Offset(0, 0),
      startValues: PrefabSceneValues(
        anchorX: 0,
        anchorY: 0,
        colliders: <PrefabColliderDef>[
          PrefabColliderDef(offsetX: 0, offsetY: 0, width: 16, height: 16),
          PrefabColliderDef(offsetX: 5, offsetY: 6, width: 10, height: 8),
        ],
        selectedColliderIndex: 1,
      ),
      zoom: 1,
      boundsWidthPx: 100,
      boundsHeightPx: 100,
    );

    final next = PrefabOverlayInteraction.valuesFromDrag(
      drag: drag,
      currentLocal: const Offset(4, 0),
    );

    expect(next.colliders, hasLength(2));
    expect(next.colliders[0].offsetX, 0);
    expect(next.colliders[0].width, 16);
    expect(next.colliders[1].offsetX, 7);
    expect(next.colliders[1].width, 14);
    expect(next.selectedColliderIndex, 1);
  });

  test(
    'hit testing selects collider rectangles by authored overlay bounds',
    () {
      const values = PrefabSceneValues(
        anchorX: 32,
        anchorY: 32,
        colliders: <PrefabColliderDef>[
          PrefabColliderDef(offsetX: 0, offsetY: 0, width: 16, height: 16),
          PrefabColliderDef(offsetX: 20, offsetY: 0, width: 12, height: 12),
        ],
        selectedColliderIndex: 0,
      );
      final geometry = PrefabOverlayHandleGeometry.fromValues(
        values: values,
        anchorCanvasBase: Offset.zero,
        zoom: 2,
      );

      final colliderIndex = PrefabOverlayHitTest.hitTestColliderIndex(
        point: const Offset(104, 64),
        geometry: geometry,
      );

      expect(colliderIndex, 1);
      final next = PrefabOverlayInteraction.valuesWithSelectedCollider(
        values: values,
        selectedColliderIndex: colliderIndex!,
      );
      expect(next.selectedColliderIndex, 1);
    },
  );
}
