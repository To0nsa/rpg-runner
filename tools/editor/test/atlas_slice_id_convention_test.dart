import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/prefabs/domain/atlas_slice_id_convention.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';

void main() {
  const source = 'assets/images/level/atlases/ancient_forest/terrain.png';

  test('suggested prefix distinguishes prefab and tile slices', () {
    expect(
      AtlasSliceIdConvention.suggestedPrefix(
        kind: AtlasSliceKind.prefab,
        sourcePath: source,
      ),
      'ancient_forest_',
    );
    expect(
      AtlasSliceIdConvention.suggestedPrefix(
        kind: AtlasSliceKind.tile,
        sourcePath: source,
      ),
      'ancient_forest_terrain_',
    );
    expect(
      AtlasSliceIdConvention.collectionPrefix(
        'assets/images/level/atlases/Ancient Forest/props/trees.png',
      ),
      'ancient_forest_',
    );
    expect(
      AtlasSliceIdConvention.suggestedPrefix(
        kind: AtlasSliceKind.tile,
        sourcePath: 'assets/decorations.png',
      ),
      'assets_decorations_',
    );
  });

  test('displayed convention resolves the selected kind and dimensions', () {
    expect(
      AtlasSliceIdConvention.pattern(AtlasSliceKind.prefab),
      '<collection>_<object>[_<descriptor>]_<nn>',
    );
    expect(
      AtlasSliceIdConvention.contextualPattern(
        kind: AtlasSliceKind.prefab,
        sourcePath: source,
        width: 48,
        height: 32,
      ),
      'ancient_forest_<object>[_<descriptor>]_<nn>',
    );
    expect(
      AtlasSliceIdConvention.exampleId(
        kind: AtlasSliceKind.prefab,
        sourcePath: source,
        width: 48,
        height: 32,
      ),
      'ancient_forest_crate_01',
    );

    expect(
      AtlasSliceIdConvention.pattern(AtlasSliceKind.tile),
      '<collection>_<sheet>_<object>[_<descriptor>]_<nn>_<W>x<H>',
    );
    expect(
      AtlasSliceIdConvention.contextualPattern(
        kind: AtlasSliceKind.tile,
        sourcePath: source,
        width: 48,
        height: 32,
      ),
      'ancient_forest_terrain_<object>[_<descriptor>]_<nn>_48x32',
    );
    expect(
      AtlasSliceIdConvention.exampleId(
        kind: AtlasSliceKind.tile,
        sourcePath: source,
        width: 48,
        height: 32,
      ),
      'ancient_forest_terrain_grass_01_48x32',
    );
    expect(
      AtlasSliceIdConvention.contextualPattern(
        kind: AtlasSliceKind.tile,
        sourcePath: null,
      ),
      '<collection>_<sheet>_<object>[_<descriptor>]_<nn>_<W>x<H>',
    );
  });

  test('tile size suffix is appended and updated only after a variant', () {
    expect(
      AtlasSliceIdConvention.withTileSelectionSize(
        id: 'ancient_forest_terrain_grass_01',
        width: 48,
        height: 32,
      ),
      'ancient_forest_terrain_grass_01_48x32',
    );
    expect(
      AtlasSliceIdConvention.withTileSelectionSize(
        id: 'ancient_forest_terrain_grass_01_16x16',
        width: 48,
        height: 32,
      ),
      'ancient_forest_terrain_grass_01_48x32',
    );
    expect(
      AtlasSliceIdConvention.withTileSelectionSize(
        id: 'ancient_forest_terrain_grass',
        width: 48,
        height: 32,
      ),
      'ancient_forest_terrain_grass',
    );
    expect(
      AtlasSliceIdConvention.withTileSelectionSize(
        id: 'ancient_forest_terrain_grass_01',
        width: null,
        height: 32,
      ),
      'ancient_forest_terrain_grass_01',
    );
  });

  test('slice convention applies size only to tile slices', () {
    expect(
      AtlasSliceIdConvention.validate(
        kind: AtlasSliceKind.prefab,
        id: 'ancient_forest_crate_01',
        sourceImagePath: source,
        width: 32,
        height: 48,
      ),
      isNull,
    );
    expect(
      AtlasSliceIdConvention.validate(
        kind: AtlasSliceKind.tile,
        id: 'ancient_forest_terrain_grass_01_32x32',
        sourceImagePath: source,
        width: 32,
        height: 32,
      ),
      isNull,
    );
    expect(
      AtlasSliceIdConvention.validate(
        kind: AtlasSliceKind.prefab,
        id: 'Ancient_Forest_Crate_01',
        sourceImagePath: source,
      ),
      'Use lowercase snake_case with ASCII letters and numbers.',
    );
    expect(
      AtlasSliceIdConvention.validate(
        kind: AtlasSliceKind.tile,
        id: 'ancient_forest_grass_01_32x32',
        sourceImagePath: source,
      ),
      'Start the Slice ID with the source prefix '
      '"ancient_forest_terrain_".',
    );
    expect(
      AtlasSliceIdConvention.validate(
        kind: AtlasSliceKind.tile,
        id: 'ancient_forest_terrain_grass_01',
        sourceImagePath: source,
        width: 32,
        height: 32,
      ),
      'End the Tile Slice ID with its pixel size "_32x32".',
    );
    expect(
      AtlasSliceIdConvention.validate(
        kind: AtlasSliceKind.prefab,
        id: 'ancient_forest_crate_1',
        sourceImagePath: source,
      ),
      'End the Prefab Slice ID with a two-digit variant from _01 to _99.',
    );
    expect(
      AtlasSliceIdConvention.validate(
        kind: AtlasSliceKind.prefab,
        id: 'ancient_forest_01',
        sourceImagePath: source,
      ),
      'Add an object name after "ancient_forest_" and before the variant.',
    );
    expect(
      AtlasSliceIdConvention.validate(
        kind: AtlasSliceKind.tile,
        id: 'ancient_forest_terrain_grass_01_16x16',
        sourceImagePath: source,
        width: 32,
        height: 48,
      ),
      'The Tile Slice ID size must match the selection: "_32x48".',
    );
    expect(
      AtlasSliceIdConvention.validate(
        kind: AtlasSliceKind.prefab,
        id: 'ancient_forest_crate_01_32x48',
        sourceImagePath: source,
      ),
      'End the Prefab Slice ID with a two-digit variant from _01 to _99.',
    );
  });
}
