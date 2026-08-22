import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../prefabs/store/prefab_determinism.dart';
import '../../prefabCreator/shared/prefab_polygon_visual_source.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_ui_tokens.dart';

/// Searchable visual catalog for choosing a Prefab-v3 owner in Chunk authoring.
///
/// Search and filters are transient presentation state. Selection returns the
/// exact immutable prefab record so callers continue to store and resolve its
/// stable `prefabKey`; this widget never mutates source or placement data.
class ChunkPrefabCatalogBrowser extends StatefulWidget {
  ChunkPrefabCatalogBrowser({
    super.key,
    required Iterable<PrefabV3Def> prefabs,
    required this.prefabData,
    required this.tileData,
    required Map<String, PrefabV3VisualBounds> visualBoundsByPrefabKey,
    required this.workspaceRootPath,
    required this.selectedPrefabKey,
    required Iterable<String> usedPrefabKeys,
    required this.onSelected,
    this.enabled = true,
    this.gridHeight = 272,
    this.autofocusSearch = false,
    this.keyPrefix = 'chunk_prefab_catalog',
  }) : prefabs = List<PrefabV3Def>.unmodifiable(prefabs),
       visualBoundsByPrefabKey = Map<String, PrefabV3VisualBounds>.unmodifiable(
         visualBoundsByPrefabKey,
       ),
       usedPrefabKeys = Set<String>.unmodifiable(usedPrefabKeys);

  final List<PrefabV3Def> prefabs;
  final PrefabV3FileData prefabData;
  final PrefabTileFileData tileData;
  final Map<String, PrefabV3VisualBounds> visualBoundsByPrefabKey;
  final String workspaceRootPath;
  final String? selectedPrefabKey;
  final Set<String> usedPrefabKeys;
  final ValueChanged<PrefabV3Def> onSelected;
  final bool enabled;
  final double gridHeight;
  final bool autofocusSearch;
  final String keyPrefix;

  @override
  State<ChunkPrefabCatalogBrowser> createState() =>
      _ChunkPrefabCatalogBrowserState();
}

class _ChunkPrefabCatalogBrowserState extends State<ChunkPrefabCatalogBrowser> {
  late final TextEditingController _searchController;
  late EditorUiImageCache _imageCache;
  late Map<String, PrefabPolygonVisualProjection> _projectionsByPrefabKey;
  PrefabKind? _kindFilter;
  bool _usedInChunkOnly = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
    _imageCache = EditorUiImageCache();
    _rebuildProjections();
  }

  @override
  void didUpdateWidget(covariant ChunkPrefabCatalogBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceRootPath != widget.workspaceRootPath) {
      _imageCache.dispose();
      _imageCache = EditorUiImageCache();
    }
    if (!identical(oldWidget.prefabData, widget.prefabData) ||
        !identical(oldWidget.tileData, widget.tileData) ||
        !_sameVisualBounds(
          oldWidget.visualBoundsByPrefabKey,
          widget.visualBoundsByPrefabKey,
        ) ||
        !_samePrefabRecords(oldWidget.prefabs, widget.prefabs)) {
      _rebuildProjections();
    }
    if (_usedInChunkOnly && widget.usedPrefabKeys.isEmpty) {
      _usedInChunkOnly = false;
    }
    if (_kindFilter != null &&
        !widget.prefabs.any((prefab) => prefab.kind == _kindFilter)) {
      _kindFilter = null;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _imageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredPrefabs = _filteredPrefabs();
    final availableKinds = widget.prefabs.map((prefab) => prefab.kind).toSet()
      ..remove(PrefabKind.unknown);
    final sortedKinds = availableKinds.toList(growable: false)
      ..sort((left, right) => left.jsonValue.compareTo(right.jsonValue));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          key: ValueKey<String>('${widget.keyPrefix}_search'),
          controller: _searchController,
          autofocus: widget.autofocusSearch,
          enabled: widget.enabled,
          textInputAction: TextInputAction.search,
          onSubmitted: widget.enabled
              ? (_) {
                  final matches = _filteredPrefabs();
                  if (matches.isNotEmpty) widget.onSelected(matches.first);
                }
              : null,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Search prefabs',
            hintText: 'ID, kind, or tags such as rock dark moss',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    key: ValueKey<String>('${widget.keyPrefix}_clear_search'),
                    tooltip: 'Clear prefab search',
                    onPressed: widget.enabled ? _searchController.clear : null,
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        const SizedBox(height: EditorUiTokens.controlGap),
        Wrap(
          spacing: EditorUiTokens.controlGap,
          runSpacing: EditorUiTokens.controlGap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            ChoiceChip(
              key: ValueKey<String>('${widget.keyPrefix}_kind_all'),
              label: const Text('All'),
              selected: _kindFilter == null,
              onSelected: widget.enabled
                  ? (_) => setState(() => _kindFilter = null)
                  : null,
            ),
            for (final kind in sortedKinds)
              ChoiceChip(
                key: ValueKey<String>(
                  '${widget.keyPrefix}_kind_${kind.jsonValue}',
                ),
                label: Text(_kindLabel(kind)),
                selected: _kindFilter == kind,
                onSelected: widget.enabled
                    ? (_) => setState(() => _kindFilter = kind)
                    : null,
              ),
            if (widget.usedPrefabKeys.isNotEmpty)
              FilterChip(
                key: ValueKey<String>('${widget.keyPrefix}_used'),
                avatar: const Icon(Icons.history, size: 18),
                label: const Text('Used in chunk'),
                selected: _usedInChunkOnly,
                onSelected: widget.enabled
                    ? (selected) => setState(() => _usedInChunkOnly = selected)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: EditorUiTokens.controlGap),
        Text(
          '${filteredPrefabs.length} of ${widget.prefabs.length} prefabs',
          key: ValueKey<String>('${widget.keyPrefix}_count'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: EditorUiTokens.controlGap),
        SizedBox(
          height: widget.gridHeight,
          child: filteredPrefabs.isEmpty
              ? Center(
                  key: ValueKey<String>('${widget.keyPrefix}_empty'),
                  child: const Text(
                    'No prefabs match the current search and filters.',
                    textAlign: TextAlign.center,
                  ),
                )
              : GridView.builder(
                  key: ValueKey<String>('${widget.keyPrefix}_grid'),
                  primary: false,
                  itemCount: filteredPrefabs.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisExtent: 174,
                    crossAxisSpacing: EditorUiTokens.controlGap,
                    mainAxisSpacing: EditorUiTokens.controlGap,
                  ),
                  itemBuilder: (context, index) {
                    final prefab = filteredPrefabs[index];
                    return _PrefabCatalogCard(
                      key: ValueKey<String>(
                        '${widget.keyPrefix}_card_${prefab.prefabKey}',
                      ),
                      prefab: prefab,
                      projection: _projectionsByPrefabKey[prefab.prefabKey]!,
                      imageCache: _imageCache,
                      workspaceRootPath: widget.workspaceRootPath,
                      selected: prefab.prefabKey == widget.selectedPrefabKey,
                      enabled: widget.enabled,
                      previewKey: ValueKey<String>(
                        '${widget.keyPrefix}_preview_${prefab.prefabKey}',
                      ),
                      onTap: () => widget.onSelected(prefab),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<PrefabV3Def> _filteredPrefabs() {
    final queryTokens = _searchController.text
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    final filtered =
        widget.prefabs
            .where((prefab) {
              if (_kindFilter != null && prefab.kind != _kindFilter) {
                return false;
              }
              if (_usedInChunkOnly &&
                  !widget.usedPrefabKeys.contains(prefab.prefabKey)) {
                return false;
              }
              final searchText = <String>[
                prefab.id,
                prefab.prefabKey,
                prefab.kind.jsonValue,
                ...prefab.tags,
              ].join(' ').toLowerCase();
              return queryTokens.every(searchText.contains);
            })
            .toList(growable: false)
          ..sort(PrefabDeterminism.comparePrefabV3ByIdThenKey);
    return filtered;
  }

  void _rebuildProjections() {
    _projectionsByPrefabKey = <String, PrefabPolygonVisualProjection>{
      for (final prefab in widget.prefabs)
        prefab.prefabKey: PrefabPolygonVisualProjection.fromData(
          prefabData: widget.prefabData,
          tileData: widget.tileData,
          visualBoundsByPrefabKey: widget.visualBoundsByPrefabKey,
          prefab: prefab,
        ),
    };
  }

  void _handleSearchChanged() => setState(() {});
}

class _PrefabCatalogCard extends StatelessWidget {
  const _PrefabCatalogCard({
    super.key,
    required this.prefab,
    required this.projection,
    required this.imageCache,
    required this.workspaceRootPath,
    required this.selected,
    required this.enabled,
    required this.previewKey,
    required this.onTap,
  });

  final PrefabV3Def prefab;
  final PrefabPolygonVisualProjection projection;
  final EditorUiImageCache imageCache;
  final String workspaceRootPath;
  final bool selected;
  final bool enabled;
  final Key previewKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tagText = prefab.tags.isEmpty ? 'No tags' : prefab.tags.join(', ');
    return Semantics(
      button: true,
      selected: selected,
      label: '${prefab.id}, ${_kindLabel(prefab.kind)}, tags $tagText',
      child: Tooltip(
        message:
            '${prefab.id}\n${_kindLabel(prefab.kind)} · '
            '${prefab.sourceRefId}\n$tagText',
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          color: selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.32)
              : colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(EditorUiTokens.controlGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _PrefabCatalogThumbnail(
                      key: previewKey,
                      projection: projection,
                      imageCache: imageCache,
                      workspaceRootPath: workspaceRootPath,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          prefab.id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_kindLabel(prefab.kind)} · $tagText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrefabCatalogThumbnail extends StatefulWidget {
  const _PrefabCatalogThumbnail({
    super.key,
    required this.projection,
    required this.imageCache,
    required this.workspaceRootPath,
  });

  final PrefabPolygonVisualProjection projection;
  final EditorUiImageCache imageCache;
  final String workspaceRootPath;

  @override
  State<_PrefabCatalogThumbnail> createState() =>
      _PrefabCatalogThumbnailState();
}

class _PrefabCatalogThumbnailState extends State<_PrefabCatalogThumbnail> {
  var _loadEpoch = 0;

  @override
  void initState() {
    super.initState();
    _ensureImagesLoaded();
  }

  @override
  void didUpdateWidget(covariant _PrefabCatalogThumbnail oldWidget) {
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

bool _samePrefabRecords(List<PrefabV3Def> left, List<PrefabV3Def> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (!identical(left[index], right[index]) && left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool _sameVisualBounds(
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

String _kindLabel(PrefabKind kind) => switch (kind) {
  PrefabKind.obstacle => 'Obstacle',
  PrefabKind.platform => 'Platform',
  PrefabKind.decoration => 'Decoration',
  PrefabKind.unknown => 'Unknown',
};
