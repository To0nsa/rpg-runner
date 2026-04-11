import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/app/pages/shared/editor_scene_view_utils.dart';
import 'package:runner_editor/src/app/pages/shared/ground_material_render_rules.dart';

void main() {
  test('detectGroundMaterialSourceRectForPreview matches field ground strip', () async {
    final root = _repoRootPath();
    final absolutePath = p.join(
      root,
      'assets',
      'images',
      'parallax',
      'field',
      'Field Layer 09.png',
    );
    final image = await EditorSceneViewUtils.loadFileImage(absolutePath);
    addTearDown(() {
      image?.dispose();
    });

    expect(image, isNotNull);

    final sourceRect = await detectGroundMaterialSourceRectForPreview(image!);

    expect(sourceRect, const Rect.fromLTWH(0, 241, 512, 15));
  });

  test('ground band rect and bottom anchor match runtime placement math', () {
    const materialSourceRect = Rect.fromLTWH(0, 241, 512, 15);

    final bandHeight = resolveGroundMaterialBandHeight(
      materialSourceRect: materialSourceRect,
      zoom: 2.0,
      maxHeight: 120.0,
    );
    final bandRect = buildViewportBottomGroundBandRect(
      viewportSize: const Size(300, 120),
      groundBandHeight: bandHeight,
    );
    final foregroundTopY = resolveBottomAnchoredLayerTopY(
      bottomAnchorY: bandRect.bottom,
      layerHeight: 80,
      yOffset: 4,
    );

    expect(bandHeight, 30.0);
    expect(bandRect, const Rect.fromLTWH(0, 90, 300, 30));
    expect(foregroundTopY, 44.0);
  });
}

String _repoRootPath() {
  final candidates = <String>[
    Directory.current.path,
    p.join(Directory.current.path, '..'),
    p.join(Directory.current.path, '..', '..'),
    p.join(Directory.current.path, '..', '..', '..'),
  ];
  for (final candidate in candidates) {
    final root = p.normalize(candidate);
    final assetPath = p.join(
      root,
      'assets',
      'images',
      'parallax',
      'field',
      'Field Layer 09.png',
    );
    if (File(assetPath).existsSync()) {
      return root;
    }
  }
  throw StateError(
    'Could not resolve repo root for ground material render rules tests.',
  );
}
