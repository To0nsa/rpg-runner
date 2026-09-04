import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_slice_id_convention.dart';

void main() {
  test('collection prefix prefers the reusable canonical atlas collection', () {
    expect(
      PrefabSliceIdConvention.collectionPrefix(
        'assets/images/level/atlases/Ancient Forest/props.png',
      ),
      'ancient_forest_',
    );
    expect(
      PrefabSliceIdConvention.collectionPrefix(
        'assets/images/level/atlases/Ancient Forest/props/trees.png',
      ),
      'ancient_forest_',
    );
    expect(
      PrefabSliceIdConvention.collectionPrefix('assets/decorations.png'),
      'assets_',
    );
  });

  test('new prefab slice convention validates prefix, shape, and variant', () {
    const source = 'assets/images/level/atlases/ancient_forest/props.png';

    expect(
      PrefabSliceIdConvention.validate(
        id: 'ancient_forest_crate_01',
        sourceImagePath: source,
      ),
      isNull,
    );
    expect(
      PrefabSliceIdConvention.validate(
        id: 'Ancient_Forest_Crate_01',
        sourceImagePath: source,
      ),
      'Use lowercase snake_case with ASCII letters and numbers.',
    );
    expect(
      PrefabSliceIdConvention.validate(
        id: 'village_crate_01',
        sourceImagePath: source,
      ),
      'Start the Slice ID with the atlas collection prefix '
      '"ancient_forest_".',
    );
    expect(
      PrefabSliceIdConvention.validate(
        id: 'ancient_forest_crate_1',
        sourceImagePath: source,
      ),
      'End the Slice ID with a two-digit variant from _01 to _99.',
    );
    expect(
      PrefabSliceIdConvention.validate(
        id: 'ancient_forest_',
        sourceImagePath: source,
      ),
      'Add an object name after "ancient_forest_" and before the variant '
      'suffix.',
    );
    expect(
      PrefabSliceIdConvention.validate(
        id: 'ancient_forest_01',
        sourceImagePath: source,
      ),
      'Add an object name after "ancient_forest_" and before the variant '
      'suffix.',
    );
  });
}
