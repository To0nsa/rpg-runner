import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds parallax asset images from generated theme data', () async {
    final lifecycle = UiAssetLifecycle();
    addTearDown(lifecycle.dispose);

    final layers = await lifecycle.getParallaxLayers('forest');

    expect(layers.map((layer) => layer.assetName).toList(), <String>[
      'assets/images/parallax/forest/layer_01.png',
      'assets/images/parallax/forest/layer_02.png',
      'assets/images/parallax/forest/layer_03.png',
    ]);
  });
}
