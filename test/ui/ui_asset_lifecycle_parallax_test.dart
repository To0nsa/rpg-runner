import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds parallax asset images from generated theme data', () async {
    final lifecycle = UiAssetLifecycle();
    addTearDown(lifecycle.dispose);

    final layers = await lifecycle.getParallaxLayers('forest');

    expect(layers.map((layer) => layer.assetName).toList(), <String>[
      'assets/images/parallax/forest/Forest Layer 01.png',
      'assets/images/parallax/forest/Forest Layer 02.png',
      'assets/images/parallax/forest/Forest Layer 03.png',
      'assets/images/parallax/forest/Forest Layer 04.png',
      'assets/images/parallax/forest/Forest Layer 05.png',
    ]);
  });
}
