import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/app/pages/chunkCreator/widgets/chunk_scene_ground.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';

void main() {
  test(
    'buildChunkGroundLayoutWithFillDepth splits solid spans around clamped gaps',
    () {
      const chunk = LevelChunkDef(
        chunkKey: 'chunk_ground',
        id: 'chunk_ground',
        revision: 1,
        schemaVersion: 1,
        levelId: 'field',
        tileSize: 16,
        width: 600,
        height: 270,
        difficulty: chunkDifficultyNormal,
        groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
        groundGaps: <GroundGapDef>[
          GroundGapDef(gapId: 'gap_a', x: -16, width: 48),
          GroundGapDef(gapId: 'gap_b', x: 320, width: 160),
          GroundGapDef(gapId: 'gap_c', x: 580, width: 64),
        ],
      );

      final layout = buildChunkGroundLayoutWithFillDepth(chunk, fillDepth: 15);

      expect(layout.solidWorldRects, <Rect>[
        const Rect.fromLTWH(32, 224, 288, 15),
        const Rect.fromLTWH(480, 224, 100, 15),
      ]);
      expect(layout.gapWorldRects, <Rect>[
        const Rect.fromLTWH(0, 224, 32, 15),
        const Rect.fromLTWH(320, 224, 160, 15),
        const Rect.fromLTWH(580, 224, 20, 15),
      ]);
    },
  );

  test(
    'buildChunkGroundLayoutWithFillDepth clamps overlarge depth to viewport',
    () {
      const chunk = LevelChunkDef(
        chunkKey: 'chunk_ground',
        id: 'chunk_ground',
        revision: 1,
        schemaVersion: 1,
        levelId: 'field',
        tileSize: 16,
        width: 600,
        height: 270,
        difficulty: chunkDifficultyNormal,
        groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
      );

      final layout = buildChunkGroundLayoutWithFillDepth(chunk, fillDepth: 80);

      expect(layout.solidWorldRects, <Rect>[
        const Rect.fromLTWH(0, 224, 600, 46),
      ]);
      expect(layout.gapWorldRects, isEmpty);
    },
  );

  test('resolveChunkGroundMaterialSpec fails fast for unknown levels', () {
    expect(
      () => resolveChunkGroundMaterialSpec('unknown'),
      throwsA(isA<StateError>()),
    );
    expect(
      () => resolveChunkParallaxPreviewSpec('unknown'),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'chunk scene preview theme registry stays aligned with runtime themes',
    () {
      final runtimeThemes = _loadRuntimeThemes();
      final editorThemeIds = chunkScenePreviewLevelIds().toSet();

      expect(editorThemeIds, runtimeThemes.keys.toSet());
      for (final levelId in editorThemeIds) {
        final runtimeTheme = runtimeThemes[levelId];
        expect(runtimeTheme, isNotNull);
        expect(
          _normalizeEditorAssetPath(
            resolveChunkGroundMaterialSpec(levelId).sourceImagePath,
          ),
          runtimeTheme!.groundAssetPath,
        );
        expect(
          _editorLayerEntries(
            resolveChunkParallaxPreviewSpec(levelId).backgroundLayers,
          ),
          runtimeTheme.backgroundLayers,
        );
        expect(
          _editorLayerEntries(
            resolveChunkParallaxPreviewSpec(levelId).foregroundLayers,
          ),
          runtimeTheme.foregroundLayers,
        );
      }
    },
  );
}

Map<String, _RuntimeThemeSpec> _loadRuntimeThemes() {
  final root = _repoRootPath();
  final source = File(
    p.join(root, 'lib', 'game', 'themes', 'parallax_theme_registry.dart'),
  ).readAsStringSync();

  final themeBodiesByAlias = <String, String>{};
  final themeBlockPattern = RegExp(
    r"const ParallaxTheme _([A-Za-z0-9_]+) = ParallaxTheme\(([\s\S]*?)\n\);",
    multiLine: true,
  );
  for (final match in themeBlockPattern.allMatches(source)) {
    themeBodiesByAlias[match.group(1)!] = match.group(2)!;
  }

  final themeById = <String, _RuntimeThemeSpec>{};
  final switchCasePattern = RegExp(
    r"case '([^']+)':\s*return _([A-Za-z0-9_]+);",
    multiLine: true,
  );
  for (final match in switchCasePattern.allMatches(source)) {
    final levelId = match.group(1)!;
    final alias = match.group(2)!;
    final body = themeBodiesByAlias[alias];
    if (body == null) {
      continue;
    }
    themeById[levelId] = _parseRuntimeTheme(body);
  }
  return themeById;
}

_RuntimeThemeSpec _parseRuntimeTheme(String body) {
  final backgroundLayersMatch = RegExp(
    r'backgroundLayers:\s*<PixelParallaxLayerSpec>\[(.*?)\],\s*groundLayerAsset:',
    dotAll: true,
  ).firstMatch(body);
  final foregroundLayersMatch = RegExp(
    r'foregroundLayers:\s*<PixelParallaxLayerSpec>\[(.*?)\],',
    dotAll: true,
  ).firstMatch(body);
  final groundAssetMatch = RegExp(
    r"groundLayerAsset:\s*'([^']+)'",
  ).firstMatch(body);

  return _RuntimeThemeSpec(
    groundAssetPath: groundAssetMatch!.group(1)!,
    backgroundLayers: _parseRuntimeLayerEntries(
      backgroundLayersMatch?.group(1) ?? '',
    ),
    foregroundLayers: _parseRuntimeLayerEntries(
      foregroundLayersMatch?.group(1) ?? '',
    ),
  );
}

List<String> _parseRuntimeLayerEntries(String section) {
  final pattern = RegExp(
    r"PixelParallaxLayerSpec\(\s*assetPath:\s*'([^']+)',\s*parallaxFactor:\s*([0-9.]+),",
    dotAll: true,
  );
  return pattern
      .allMatches(section)
      .map(
        (match) =>
            '${match.group(1)!}|${double.parse(match.group(2)!).toStringAsFixed(2)}',
      )
      .toList(growable: false);
}

List<String> _editorLayerEntries(List<ChunkParallaxLayerPreviewSpec> layers) {
  return layers
      .map(
        (layer) =>
            '${_normalizeEditorAssetPath(layer.assetPath)}|${layer.parallaxFactor.toStringAsFixed(2)}',
      )
      .toList(growable: false);
}

String _normalizeEditorAssetPath(String assetPath) {
  return assetPath.replaceFirst('assets/images/', '');
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
    final registryPath = p.join(
      root,
      'lib',
      'game',
      'themes',
      'parallax_theme_registry.dart',
    );
    if (File(registryPath).existsSync()) {
      return root;
    }
  }
  throw StateError('Could not resolve repo root for chunk scene ground tests.');
}

class _RuntimeThemeSpec {
  const _RuntimeThemeSpec({
    required this.groundAssetPath,
    required this.backgroundLayers,
    required this.foregroundLayers,
  });

  final String groundAssetPath;
  final List<String> backgroundLayers;
  final List<String> foregroundLayers;
}
