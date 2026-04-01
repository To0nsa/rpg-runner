import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'phase-0 level atlases are loadable from the app asset bundle',
    () async {
      final propsBytes = await rootBundle.load(
        'assets/images/level/props/TX Village Props.png',
      );
      final tileBytes = await rootBundle.load(
        'assets/images/level/tileset/TX Tileset Ground.png',
      );

      expect(propsBytes.lengthInBytes, greaterThan(0));
      expect(tileBytes.lengthInBytes, greaterThan(0));
    },
  );
}
