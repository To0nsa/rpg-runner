import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../prefabs/store/prefab_determinism.dart';
import '../../shared/editor_scene_view_utils.dart';
import 'prefab_polygon_visual_source.dart';

/// Deterministic token search and domain filtering shared by Prefab catalogs.
List<PrefabV3Def> filterPrefabCatalogRecords({
  required Iterable<PrefabV3Def> prefabs,
  required String query,
  PrefabKind? kind,
  PrefabStatus? status,
  Set<String>? usedPrefabKeys,
  bool usedOnly = false,
}) {
  final queryTokens = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  final filtered =
      prefabs
          .where((prefab) {
            if (kind != null && prefab.kind != kind) return false;
            if (status != null && prefab.status != status) return false;
            if (usedOnly &&
                !(usedPrefabKeys?.contains(prefab.prefabKey) ?? false)) {
              return false;
            }
            final searchText = <String>[
              prefab.id,
              prefab.prefabKey,
              prefab.kind.jsonValue,
              prefab.status.jsonValue,
              prefab.visualSource.type.jsonValue,
              prefab.sourceRefId,
              ...prefab.tags,
            ].join(' ').toLowerCase();
            return queryTokens.every(searchText.contains);
          })
          .toList(growable: false)
        ..sort(PrefabDeterminism.comparePrefabV3ByIdThenKey);
  return filtered;
}

String prefabCatalogKindLabel(PrefabKind kind) => switch (kind) {
  PrefabKind.obstacle => 'Obstacle',
  PrefabKind.platform => 'Platform',
  PrefabKind.decoration => 'Decoration',
  PrefabKind.unknown => 'Unknown',
};

/// Workspace-cached atlas/module thumbnail shared by Prefab selection routes.
class PrefabCatalogThumbnail extends StatefulWidget {
  const PrefabCatalogThumbnail({
    super.key,
    required this.projection,
    required this.imageCache,
    required this.workspaceRootPath,
  });

  final PrefabPolygonVisualProjection projection;
  final EditorUiImageCache imageCache;
  final String workspaceRootPath;

  @override
  State<PrefabCatalogThumbnail> createState() => _PrefabCatalogThumbnailState();
}

class _PrefabCatalogThumbnailState extends State<PrefabCatalogThumbnail> {
  var _loadEpoch = 0;

  @override
  void initState() {
    super.initState();
    _ensureImagesLoaded();
  }

  @override
  void didUpdateWidget(covariant PrefabCatalogThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.projection, widget.projection) ||
        oldWidget.imageCache != widget.imageCache ||
        oldWidget.workspaceRootPath != widget.workspaceRootPath) {
      _ensureImagesLoaded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final imagesByPath = <String, ui.Image>{};
    for (final tile in widget.projection.tiles) {
      final sourcePath = tile.slice?.sourceImagePath.trim();
      if (sourcePath == null || sourcePath.isEmpty) continue;
      final absolutePath = p.normalize(
        p.join(widget.workspaceRootPath, sourcePath),
      );
      final image = widget.imageCache.imageFor(absolutePath);
      if (image != null) imagesByPath[sourcePath] = image;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF101820),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CustomPaint(
          painter: _PrefabCatalogThumbnailPainter(
            projection: widget.projection,
            imagesByPath: imagesByPath,
            loadedImageCount: widget.imageCache.loadedImageCount,
          ),
        ),
      ),
    );
  }

  void _ensureImagesLoaded() {
    final epoch = ++_loadEpoch;
    final sourcePaths = widget.projection.tiles
        .map((tile) => tile.slice?.sourceImagePath.trim())
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toSet();
    unawaited(() async {
      await Future.wait(
        sourcePaths.map(
          (sourcePath) => widget.imageCache.ensureLoaded(
            p.normalize(p.join(widget.workspaceRootPath, sourcePath)),
          ),
        ),
      );
      if (mounted && epoch == _loadEpoch) setState(() {});
    }());
  }
}

final class _PrefabCatalogThumbnailPainter extends CustomPainter {
  const _PrefabCatalogThumbnailPainter({
    required this.projection,
    required this.imagesByPath,
    required this.loadedImageCount,
  });

  final PrefabPolygonVisualProjection projection;
  final Map<String, ui.Image> imagesByPath;
  final int loadedImageCount;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = _contentBounds();
    if (bounds == null || bounds.isEmpty) {
      _paintMissingPreview(canvas, size);
      return;
    }
    const padding = 8.0;
    final availableSize = Size(
      (size.width - padding * 2).clamp(1, double.infinity),
      (size.height - padding * 2).clamp(1, double.infinity),
    );
    final fitted = applyBoxFit(BoxFit.contain, bounds.size, availableSize);
    final destinationBounds = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    final scale = fitted.destination.width / bounds.width;

    for (final tile in projection.tiles) {
      if (tile.destinationRectPx.isEmpty) continue;
      final destination = Rect.fromLTWH(
        destinationBounds.left +
            (tile.destinationRectPx.left - bounds.left) * scale,
        destinationBounds.top +
            (tile.destinationRectPx.top - bounds.top) * scale,
        tile.destinationRectPx.width * scale,
        tile.destinationRectPx.height * scale,
      );
      final slice = tile.slice;
      final image = slice == null ? null : imagesByPath[slice.sourceImagePath];
      if (slice == null || image == null) {
        canvas.drawRect(
          destination,
          Paint()..color = _fallbackColor(tile.sourceId),
        );
        continue;
      }
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(
          slice.x.toDouble(),
          slice.y.toDouble(),
          slice.width.toDouble(),
          slice.height.toDouble(),
        ),
        destination,
        Paint()..filterQuality = FilterQuality.none,
      );
    }
  }

  Rect? _contentBounds() {
    Rect? bounds = projection.visualBoundsPx.isEmpty
        ? null
        : projection.visualBoundsPx;
    for (final tile in projection.tiles) {
      final rect = tile.destinationRectPx;
      if (rect.isEmpty) continue;
      bounds = bounds == null ? rect : bounds.expandToInclude(rect);
    }
    return bounds;
  }

  void _paintMissingPreview(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = const Color(0xFF607D8B)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromCenter(center: center, width: 28, height: 22);
    canvas.drawRect(rect, paint);
    canvas.drawLine(rect.topLeft, rect.bottomRight, paint);
    canvas.drawLine(rect.topRight, rect.bottomLeft, paint);
  }

  Color _fallbackColor(String sourceId) {
    var hash = 0;
    for (final code in sourceId.codeUnits) {
      hash = ((hash * 31) + code) & 0x7fffffff;
    }
    return HSVColor.fromAHSV(
      0.82,
      (hash % 360).toDouble(),
      0.45,
      0.72,
    ).toColor();
  }

  @override
  bool shouldRepaint(covariant _PrefabCatalogThumbnailPainter oldDelegate) =>
      !identical(oldDelegate.projection, projection) ||
      oldDelegate.loadedImageCount != loadedImageCount;
}

bool samePrefabCatalogRecords(List<PrefabV3Def> left, List<PrefabV3Def> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (!identical(left[index], right[index]) && left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool samePrefabCatalogVisualBounds(
  Map<String, PrefabV3VisualBounds> left,
  Map<String, PrefabV3VisualBounds> right,
) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    final other = right[entry.key];
    if (other == null ||
        other.widthPx != entry.value.widthPx ||
        other.heightPx != entry.value.heightPx) {
      return false;
    }
  }
  return true;
}
