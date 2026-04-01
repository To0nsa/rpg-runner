import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/prefabs/prefab_models.dart';
import 'package:runner_editor/src/prefabs/prefab_validation.dart';

void main() {
  test('validatePrefabData accepts valid bounded slices and references', () {
    final data = PrefabData(
      prefabSlices: const [
        AtlasSliceDef(
          id: 'prefab_slice_a',
          sourceImagePath: 'assets/images/level/props/TX Village Props.png',
          x: 16,
          y: 16,
          width: 32,
          height: 32,
        ),
      ],
      tileSlices: const [
        AtlasSliceDef(
          id: 'tile_slice_a',
          sourceImagePath: 'assets/images/level/tileset/TX Tileset Ground.png',
          x: 0,
          y: 0,
          width: 16,
          height: 16,
        ),
      ],
      prefabs: const [
        PrefabDef(
          id: 'crate_a',
          sliceId: 'prefab_slice_a',
          anchorXPx: 8,
          anchorYPx: 28,
          colliders: [
            PrefabColliderDef(offsetX: 0, offsetY: 0, width: 16, height: 16),
          ],
          tags: ['solid'],
          zIndex: 1,
          snapToGrid: true,
        ),
      ],
      platformModules: const [
        TileModuleDef(
          id: 'module_a',
          tileSize: 16,
          cells: [
            TileModuleCellDef(sliceId: 'tile_slice_a', gridX: 0, gridY: 0),
          ],
        ),
      ],
    );

    final errors = validatePrefabData(
      data: data,
      atlasImageSizes: const {
        'assets/images/level/props/TX Village Props.png': Size(256, 256),
        'assets/images/level/tileset/TX Tileset Ground.png': Size(64, 64),
      },
    );

    expect(errors, isEmpty);
  });

  test('validatePrefabData reports missing atlas source and out-of-bounds', () {
    final data = PrefabData(
      prefabSlices: const [
        AtlasSliceDef(
          id: 'missing_atlas_slice',
          sourceImagePath: 'assets/images/level/props/missing.png',
          x: 0,
          y: 0,
          width: 16,
          height: 16,
        ),
      ],
      tileSlices: const [
        AtlasSliceDef(
          id: 'tile_out_of_bounds',
          sourceImagePath: 'assets/images/level/tileset/TX Tileset Ground.png',
          x: 12,
          y: 0,
          width: 8,
          height: 8,
        ),
      ],
    );

    final errors = validatePrefabData(
      data: data,
      atlasImageSizes: const {
        'assets/images/level/tileset/TX Tileset Ground.png': Size(16, 16),
      },
    );

    expect(
      errors,
      contains(
        'Prefab slice missing_atlas_slice references missing atlas image '
        'assets/images/level/props/missing.png.',
      ),
    );
    expect(
      errors,
      contains(
        'Tile slice tile_out_of_bounds exceeds atlas bounds for '
        'assets/images/level/tileset/TX Tileset Ground.png (16x16).',
      ),
    );
  });

  test('validatePrefabData still reports duplicate ids and broken refs', () {
    final data = PrefabData(
      prefabSlices: const [
        AtlasSliceDef(
          id: 'slice_dup',
          sourceImagePath: 'assets/images/level/props/TX Village Props.png',
          x: 0,
          y: 0,
          width: 8,
          height: 8,
        ),
        AtlasSliceDef(
          id: 'slice_dup',
          sourceImagePath: 'assets/images/level/props/TX Village Props.png',
          x: 8,
          y: 0,
          width: 8,
          height: 8,
        ),
      ],
      prefabs: const [
        PrefabDef(
          id: 'prefab_a',
          sliceId: 'missing_slice',
          anchorXPx: 0,
          anchorYPx: 0,
          colliders: [
            PrefabColliderDef(offsetX: 0, offsetY: 0, width: 8, height: 8),
          ],
        ),
        PrefabDef(
          id: 'prefab_a',
          sliceId: 'missing_slice',
          anchorXPx: 0,
          anchorYPx: 0,
          colliders: [
            PrefabColliderDef(offsetX: 0, offsetY: 0, width: 8, height: 8),
          ],
        ),
      ],
    );

    final errors = validatePrefabData(
      data: data,
      atlasImageSizes: const {
        'assets/images/level/props/TX Village Props.png': Size(64, 64),
      },
    );

    expect(errors, contains('Duplicate prefab slice id: slice_dup'));
    expect(errors, contains('Duplicate prefab id: prefab_a'));
    expect(
      errors,
      contains(
        'Prefab prefab_a references missing prefab slice missing_slice.',
      ),
    );
  });
}
