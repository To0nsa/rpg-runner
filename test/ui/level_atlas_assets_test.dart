import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('level atlases are loadable from the app asset bundle', () async {
    const atlasPaths = <String>[
      'assets/images/level/atlases/ancient_forest/props.png',
      'assets/images/level/atlases/ancient_forest/terrain.png',
      'assets/images/level/atlases/dark_forest/ground.png',
      'assets/images/level/atlases/dark_forest/rock_terrain.png',
      'assets/images/level/atlases/dark_forest/trees.png',
      'assets/images/level/atlases/fantasy_environment/mixed_biomes.png',
      'assets/images/level/atlases/rune_rocks/props.png',
      'assets/images/level/atlases/tiny_swords/ground.png',
      'assets/images/level/atlases/tiny_swords/village_props.png',
      'assets/images/level/atlases/weird_nature/props.png',
      'assets/images/level/atlases/woods/decor.png',
      'assets/images/level/atlases/woods/terrain.png',
    ];

    for (final path in atlasPaths) {
      final bytes = await rootBundle.load(path);
      expect(bytes.lengthInBytes, greaterThan(0), reason: path);
    }
  });
}
