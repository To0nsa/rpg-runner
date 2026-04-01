import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/prefabs/prefab_models.dart';
import 'package:runner_editor/src/prefabs/prefab_validation.dart';

void main() {
  test('validatePrefabData accepts valid typed obstacle/platform prefabs', () {
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
      prefabs: [
        PrefabDef(
          prefabKey: 'crate_a',
          id: 'crate_a',
          revision: 1,
          status: PrefabStatus.active,
          kind: PrefabKind.obstacle,
          visualSource: PrefabVisualSource.atlasSlice('prefab_slice_a'),
          anchorXPx: 8,
          anchorYPx: 28,
          colliders: [
            PrefabColliderDef(offsetX: 0, offsetY: 0, width: 16, height: 16),
          ],
          tags: ['solid'],
          zIndex: 1,
          snapToGrid: true,
        ),
        PrefabDef(
          prefabKey: 'platform_a',
          id: 'platform_a',
          revision: 1,
          status: PrefabStatus.active,
          kind: PrefabKind.platform,
          visualSource: PrefabVisualSource.platformModule('module_a'),
          anchorXPx: 0,
          anchorYPx: 0,
          colliders: [
            PrefabColliderDef(offsetX: 0, offsetY: 0, width: 16, height: 16),
          ],
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

  test('validatePrefabData reports v2 identity and source contract failures', () {
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
      prefabs: [
        PrefabDef(
          prefabKey: 'prefab_dup',
          id: 'prefab_a',
          revision: 0,
          status: PrefabStatus.unknown,
          kind: PrefabKind.platform,
          visualSource: PrefabVisualSource.atlasSlice('missing_slice'),
          anchorXPx: 0,
          anchorYPx: 0,
          colliders: [
            PrefabColliderDef(offsetX: 0, offsetY: 0, width: 8, height: 8),
          ],
        ),
        PrefabDef(
          prefabKey: 'prefab_dup',
          id: 'prefab_a',
          revision: 1,
          status: PrefabStatus.active,
          kind: PrefabKind.obstacle,
          visualSource: PrefabVisualSource.platformModule('missing_module'),
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
    expect(errors, contains('Duplicate prefab key: prefab_dup'));
    expect(errors, contains('Prefab prefab_a has invalid revision 0.'));
    expect(errors, contains('Prefab prefab_a has unsupported status.'));
    expect(
      errors,
      contains(
        'Prefab prefab_a has incompatible kind/source (platform + atlas_slice).',
      ),
    );
    expect(
      errors,
      contains(
        'Prefab prefab_a has incompatible kind/source (obstacle + platform_module).',
      ),
    );
    expect(
      errors,
      contains(
        'Prefab prefab_a references missing prefab slice missing_slice.',
      ),
    );
    expect(
      errors,
      contains(
        'Prefab prefab_a references missing platform module missing_module.',
      ),
    );
  });

  test(
    'validatePrefabData reports anchor, tag, and platform snap violations',
    () {
      final data = PrefabData(
        prefabSlices: const [
          AtlasSliceDef(
            id: 'prefab_slice_a',
            sourceImagePath: 'assets/images/level/props/TX Village Props.png',
            x: 0,
            y: 0,
            width: 32,
            height: 32,
          ),
        ],
        tileSlices: const [
          AtlasSliceDef(
            id: 'tile_slice_a',
            sourceImagePath:
                'assets/images/level/tileset/TX Tileset Ground.png',
            x: 0,
            y: 0,
            width: 16,
            height: 16,
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
        prefabs: [
          PrefabDef(
            prefabKey: 'platform_bad',
            id: 'platform_bad',
            revision: 1,
            status: PrefabStatus.active,
            kind: PrefabKind.platform,
            visualSource: PrefabVisualSource.platformModule('module_a'),
            anchorXPx: 33,
            anchorYPx: 3,
            colliders: [
              PrefabColliderDef(offsetX: 3, offsetY: 5, width: 10, height: 9),
            ],
            tags: ['solid', 'solid'],
            snapToGrid: true,
          ),
        ],
      );

      final errors = validatePrefabData(
        data: data,
        atlasImageSizes: const {
          'assets/images/level/props/TX Village Props.png': Size(64, 64),
          'assets/images/level/tileset/TX Tileset Ground.png': Size(64, 64),
        },
      );

      expect(
        errors,
        contains(
          'Prefab platform_bad has anchor (33,3) outside source bounds 16x16.',
        ),
      );
      expect(
        errors,
        contains(
          'Prefab platform_bad anchor must be snapped to module tileSize 16.',
        ),
      );
      expect(
        errors,
        contains(
          'Prefab platform_bad collider[0] must be snapped to module tileSize 16.',
        ),
      );
      expect(
        errors,
        contains('Prefab platform_bad has duplicate tag "solid".'),
      );
    },
  );

  test(
    'validatePrefabData uses placed slice dimensions for platform module bounds',
    () {
      final data = PrefabData(
        tileSlices: const [
          AtlasSliceDef(
            id: 'tile_slice_wide',
            sourceImagePath:
                'assets/images/level/tileset/TX Tileset Ground.png',
            x: 0,
            y: 0,
            width: 48,
            height: 16,
          ),
        ],
        platformModules: const [
          TileModuleDef(
            id: 'module_wide',
            tileSize: 16,
            cells: [
              TileModuleCellDef(sliceId: 'tile_slice_wide', gridX: 0, gridY: 0),
            ],
          ),
        ],
        prefabs: [
          PrefabDef(
            prefabKey: 'platform_wide',
            id: 'platform_wide',
            revision: 1,
            status: PrefabStatus.active,
            kind: PrefabKind.platform,
            visualSource: PrefabVisualSource.platformModule('module_wide'),
            anchorXPx: 32,
            anchorYPx: 8,
            colliders: [
              PrefabColliderDef(offsetX: 0, offsetY: 0, width: 16, height: 16),
            ],
          ),
        ],
      );

      final errors = validatePrefabData(
        data: data,
        atlasImageSizes: const {
          'assets/images/level/tileset/TX Tileset Ground.png': Size(64, 64),
        },
      );

      expect(
        errors.where((error) => error.contains('outside source bounds')),
        isEmpty,
      );
    },
  );

  test('validatePrefabDataIssues reports module lifecycle violations', () {
    final data = PrefabData(
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
      platformModules: const [
        TileModuleDef(
          id: 'module_bad',
          revision: 0,
          status: TileModuleStatus.unknown,
          tileSize: 16,
          cells: [
            TileModuleCellDef(sliceId: 'tile_slice_a', gridX: 0, gridY: 0),
          ],
        ),
        TileModuleDef(
          id: 'module_empty',
          revision: 1,
          status: TileModuleStatus.active,
          tileSize: 16,
          cells: [],
        ),
      ],
    );

    final issues = validatePrefabDataIssues(
      data: data,
      atlasImageSizes: const {
        'assets/images/level/tileset/TX Tileset Ground.png': Size(64, 64),
      },
    );
    final codes = issues.map((issue) => issue.code).toSet();

    expect(codes, contains('platform_module_revision_invalid'));
    expect(codes, contains('platform_module_status_invalid'));
    expect(codes, contains('platform_module_cells_missing'));
  });

  test('validatePrefabDataIssues exposes stable issue codes', () {
    final data = PrefabData(
      prefabs: [
        PrefabDef(
          prefabKey: '',
          id: '',
          revision: 0,
          status: PrefabStatus.unknown,
          kind: PrefabKind.unknown,
          visualSource: const PrefabVisualSource.unknown(),
          anchorXPx: 0,
          anchorYPx: 0,
          colliders: const [],
        ),
      ],
    );

    final issues = validatePrefabDataIssues(
      data: data,
      atlasImageSizes: const {},
    );
    final codes = issues.map((issue) => issue.code).toSet();

    expect(codes, contains('prefab_id_missing'));
    expect(codes, contains('prefab_key_missing'));
    expect(codes, contains('prefab_revision_invalid'));
    expect(codes, contains('prefab_status_invalid'));
    expect(codes, contains('prefab_kind_invalid'));
    expect(codes, contains('prefab_source_type_invalid'));
    expect(codes, contains('prefab_collider_missing'));
  });
}
