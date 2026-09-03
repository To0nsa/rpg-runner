import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../../prefabs/collision_fitting/prefab_collision_fitting.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../workspace/editor_workspace.dart';
import '../../shared/editor_scene_view_utils.dart';
import 'prefab_polygon_visual_source.dart';

/// One digest-bound mask composed with the exact Prefab visual projection.
final class PrefabVisualAlphaMaskResult {
  PrefabVisualAlphaMaskResult.accepted({
    required this.mask,
    required this.sourceIdentity,
  }) : diagnostics = const <String>[];

  PrefabVisualAlphaMaskResult.rejected(Iterable<String> diagnostics)
    : mask = null,
      sourceIdentity = null,
      diagnostics = List<String>.unmodifiable(diagnostics);

  final PrefabAlphaMask? mask;
  final String? sourceIdentity;
  final List<String> diagnostics;

  bool get accepted => mask != null && sourceIdentity != null;
}

/// Workspace-owned cache of immutable, digest-bound composed alpha masks.
final class PrefabVisualAlphaMaskCache {
  final Map<String, PrefabAlphaMask> _masks = <String, PrefabAlphaMask>{};

  int get length => _masks.length;

  PrefabAlphaMask? maskFor(String sourceIdentity) => _masks[sourceIdentity];

  void store(String sourceIdentity, PrefabAlphaMask mask) {
    _masks[sourceIdentity] = mask;
  }

  void clear() => _masks.clear();
}

/// Decodes and composites alpha without changing the preview's layout math.
abstract final class PrefabVisualAlphaMaskLoader {
  static Future<PrefabVisualAlphaMaskResult> load({
    required String workspaceRootPath,
    required PrefabPolygonVisualProjection projection,
    required EditorUiImageCache imageCache,
    PrefabVisualAlphaMaskCache? maskCache,
    bool refreshSources = true,
  }) async {
    final bounds = projection.visualBoundsPx;
    if (!_isWhole(bounds.left) ||
        !_isWhole(bounds.top) ||
        !_isWhole(bounds.width) ||
        !_isWhole(bounds.height) ||
        bounds.width <= 0 ||
        bounds.height <= 0) {
      return PrefabVisualAlphaMaskResult.rejected(const <String>[
        'The Prefab visual bounds must resolve to positive whole pixels.',
      ]);
    }
    final width = bounds.width.toInt();
    final height = bounds.height.toInt();
    if (width > PrefabAlphaMask.maximumPixelCount ~/ height) {
      return PrefabVisualAlphaMaskResult.rejected(<String>[
        'The Prefab visual needs ${width * height} pixels, above the '
            '${PrefabAlphaMask.maximumPixelCount} pixel fitting safety limit.',
      ]);
    }
    final recordsByPath = <String, EditorUiImageRaster>{};
    final resolvedTiles = <_ResolvedVisualTile>[];
    final identityParts = <Object?>[
      bounds.left.toInt(),
      bounds.top.toInt(),
      width,
      height,
    ];

    for (
      var tileIndex = 0;
      tileIndex < projection.tiles.length;
      tileIndex += 1
    ) {
      final tile = projection.tiles[tileIndex];
      final slice = tile.slice;
      if (slice == null || slice.sourceImagePath.trim().isEmpty) {
        return PrefabVisualAlphaMaskResult.rejected(<String>[
          'Visual tile ${tile.sourceId} has no authored PNG slice.',
        ]);
      }
      final destination = tile.destinationRectPx;
      if (!_isWhole(destination.left) ||
          !_isWhole(destination.top) ||
          !_isWhole(destination.width) ||
          !_isWhole(destination.height) ||
          destination.width.toInt() != slice.width ||
          destination.height.toInt() != slice.height) {
        return PrefabVisualAlphaMaskResult.rejected(<String>[
          'Visual tile ${tile.sourceId} does not resolve to its exact integer slice size.',
        ]);
      }
      final destinationX = (destination.left - bounds.left).toInt();
      final destinationY = (destination.top - bounds.top).toInt();
      if (destinationX < 0 ||
          destinationY < 0 ||
          destinationX + slice.width > width ||
          destinationY + slice.height > height) {
        return PrefabVisualAlphaMaskResult.rejected(<String>[
          'Visual tile ${tile.sourceId} falls outside the resolved Prefab bounds.',
        ]);
      }

      late final String absolutePath;
      try {
        absolutePath = EditorWorkspace(rootPath: workspaceRootPath)
            .resolve(p.normalize(slice.sourceImagePath));
      } on ArgumentError {
        return PrefabVisualAlphaMaskResult.rejected(<String>[
          'Visual tile ${tile.sourceId} references an image outside the workspace.',
        ]);
      }
      if (!await File(absolutePath).exists()) {
        return PrefabVisualAlphaMaskResult.rejected(<String>[
          'Visual tile ${tile.sourceId} references a missing image: '
              '${slice.sourceImagePath}.',
        ]);
      }
      var raster = recordsByPath[absolutePath];
      raster ??= await imageCache.ensureRasterLoaded(
        absolutePath,
        refresh: refreshSources,
      );
      if (raster == null) {
        return PrefabVisualAlphaMaskResult.rejected(<String>[
          'Could not decode ${slice.sourceImagePath}. Reload after repairing the PNG.',
        ]);
      }
      recordsByPath[absolutePath] = raster;
      if (slice.x < 0 ||
          slice.y < 0 ||
          slice.width <= 0 ||
          slice.height <= 0 ||
          slice.x + slice.width > raster.image.width ||
          slice.y + slice.height > raster.image.height) {
        return PrefabVisualAlphaMaskResult.rejected(<String>[
          'Slice ${slice.id} is outside the decoded bounds of ${slice.sourceImagePath}.',
        ]);
      }

      identityParts.add(<Object?>[
        tileIndex,
        tile.sourceId,
        slice.sourceImagePath,
        raster.digest,
        slice.x,
        slice.y,
        slice.width,
        slice.height,
        destinationX,
        destinationY,
      ]);
      resolvedTiles.add(
        _ResolvedVisualTile(
          raster: raster,
          slice: slice,
          destinationX: destinationX,
          destinationY: destinationY,
        ),
      );
    }
    if (projection.tiles.isEmpty) {
      return PrefabVisualAlphaMaskResult.rejected(const <String>[
        'The selected Prefab has no resolved visual tiles to fit.',
      ]);
    }

    final sourceIdentity = sha256
        .convert(utf8.encode(jsonEncode(identityParts)))
        .toString();
    final cached = maskCache?.maskFor(sourceIdentity);
    if (cached != null) {
      return PrefabVisualAlphaMaskResult.accepted(
        mask: cached,
        sourceIdentity: sourceIdentity,
      );
    }

    final output = Uint8List(width * height);
    for (final tile in resolvedTiles) {
      final raster = tile.raster;
      final slice = tile.slice;
      for (var y = 0; y < slice.height; y += 1) {
        for (var x = 0; x < slice.width; x += 1) {
          final sourceAlpha = raster.alphaAt(slice.x + x, slice.y + y);
          final outputIndex =
              (tile.destinationY + y) * width + tile.destinationX + x;
          final destinationAlpha = output[outputIndex];
          output[outputIndex] = _sourceOverAlpha(sourceAlpha, destinationAlpha);
        }
      }
    }

    final mask = PrefabAlphaMask(width: width, height: height, alpha: output);
    maskCache?.store(sourceIdentity, mask);

    return PrefabVisualAlphaMaskResult.accepted(
      mask: mask,
      sourceIdentity: sourceIdentity,
    );
  }
}

final class _ResolvedVisualTile {
  const _ResolvedVisualTile({
    required this.raster,
    required this.slice,
    required this.destinationX,
    required this.destinationY,
  });

  final EditorUiImageRaster raster;
  final AtlasSliceDef slice;
  final int destinationX;
  final int destinationY;
}

int _sourceOverAlpha(int source, int destination) =>
    (source + ((destination * (255 - source) + 127) ~/ 255)).clamp(0, 255);

bool _isWhole(double value) => value.isFinite && value == value.roundToDouble();
