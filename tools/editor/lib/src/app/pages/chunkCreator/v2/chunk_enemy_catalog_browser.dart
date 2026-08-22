import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:runner_core/enemies/enemy_terrain_profile.dart';

import '../../../../chunks/chunk_marker_authoring_catalog.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_visual_catalog.dart';

/// Searchable visual library for choosing a Core enemy in marker authoring.
///
/// The cards project immutable Core catalog metadata and the first idle frame;
/// selection is transient route state and never mutates enemy or Chunk source.
class ChunkEnemyCatalogBrowser extends StatefulWidget {
  ChunkEnemyCatalogBrowser({
    super.key,
    required this.workspaceRootPath,
    required this.selectedEnemyId,
    required Iterable<String> usedEnemyIds,
    required this.onSelected,
    this.enabled = true,
    this.gridHeight = 272,
    this.autofocusSearch = false,
    this.keyPrefix = 'chunk_enemy_catalog',
  }) : usedEnemyIds = Set<String>.unmodifiable(usedEnemyIds);

  final String workspaceRootPath;
  final String? selectedEnemyId;
  final Set<String> usedEnemyIds;
  final ValueChanged<String> onSelected;
  final bool enabled;
  final double gridHeight;
  final bool autofocusSearch;
  final String keyPrefix;

  @override
  State<ChunkEnemyCatalogBrowser> createState() =>
      _ChunkEnemyCatalogBrowserState();
}

class _ChunkEnemyCatalogBrowserState extends State<ChunkEnemyCatalogBrowser> {
  late final TextEditingController _searchController;
  late EditorUiImageCache _imageCache;
  EnemyTerrainMotionKind? _roleFilter;
  bool _usedInChunkOnly = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
    _imageCache = EditorUiImageCache();
  }

  @override
  void didUpdateWidget(covariant ChunkEnemyCatalogBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceRootPath != widget.workspaceRootPath) {
      _imageCache.dispose();
      _imageCache = EditorUiImageCache();
    }
    if (_usedInChunkOnly && widget.usedEnemyIds.isEmpty) {
      _usedInChunkOnly = false;
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
    final filteredEnemies = _filteredEnemies();
    final roles =
        chunkMarkerEnemyCatalog
            .map((entry) => entry.motionKind)
            .toSet()
            .toList(growable: false)
          ..sort((left, right) => left.index.compareTo(right.index));
    return EditorVisualCatalogLayout(
      searchController: _searchController,
      searchKey: ValueKey<String>('${widget.keyPrefix}_search'),
      searchLabel: 'Search enemies',
      searchHint: 'Name, ID, or role such as ground, flying, perched',
      clearSearchKey: ValueKey<String>('${widget.keyPrefix}_clear_search'),
      clearSearchTooltip: 'Clear enemy search',
      filters: <Widget>[
        ChoiceChip(
          key: ValueKey<String>('${widget.keyPrefix}_role_all'),
          label: const Text('All'),
          selected: _roleFilter == null,
          onSelected: widget.enabled
              ? (_) => setState(() => _roleFilter = null)
              : null,
        ),
        for (final role in roles)
          ChoiceChip(
            key: ValueKey<String>('${widget.keyPrefix}_role_${role.name}'),
            label: Text(chunkMarkerEnemyRoleLabel(role)),
            selected: _roleFilter == role,
            onSelected: widget.enabled
                ? (_) => setState(() => _roleFilter = role)
                : null,
          ),
        if (widget.usedEnemyIds.isNotEmpty)
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
      countKey: ValueKey<String>('${widget.keyPrefix}_count'),
      countLabel:
          '${filteredEnemies.length} of '
          '${chunkMarkerEnemyCatalog.length} enemies',
      gridKey: ValueKey<String>('${widget.keyPrefix}_grid'),
      emptyKey: ValueKey<String>('${widget.keyPrefix}_empty'),
      emptyMessage: 'No enemies match the current search and filters.',
      itemCount: filteredEnemies.length,
      itemBuilder: (context, index) {
        final enemy = filteredEnemies[index];
        final selected = enemy.markerId == widget.selectedEnemyId;
        return EditorVisualCatalogCard(
          key: ValueKey<String>('${widget.keyPrefix}_card_${enemy.markerId}'),
          semanticsLabel:
              '${enemy.displayName}, ${enemy.roleLabel}, ${enemy.markerId}',
          tooltipMessage:
              '${enemy.displayName}\n${enemy.markerId} · ${enemy.roleLabel}',
          selected: selected,
          enabled: widget.enabled,
          preview: _EnemyCatalogThumbnail(
            key: ValueKey<String>(
              '${widget.keyPrefix}_preview_${enemy.markerId}',
            ),
            enemy: enemy,
            imageCache: _imageCache,
            workspaceRootPath: widget.workspaceRootPath,
          ),
          title: enemy.displayName,
          subtitle: '${enemy.roleLabel} · ${enemy.markerId}',
          onTap: () => widget.onSelected(enemy.markerId),
        );
      },
      onSearchSubmitted: () {
        final matches = _filteredEnemies();
        if (matches.isNotEmpty) widget.onSelected(matches.first.markerId);
      },
      enabled: widget.enabled,
      autofocusSearch: widget.autofocusSearch,
      gridHeight: widget.gridHeight,
    );
  }

  List<ChunkMarkerEnemyCatalogEntry> _filteredEnemies() {
    final queryTokens = _searchController.text
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    return chunkMarkerEnemyCatalog
        .where((enemy) {
          if (_roleFilter != null && enemy.motionKind != _roleFilter) {
            return false;
          }
          if (_usedInChunkOnly &&
              !widget.usedEnemyIds.contains(enemy.markerId)) {
            return false;
          }
          final searchText = <String>[
            enemy.markerId,
            enemy.displayName,
            enemy.roleLabel,
          ].join(' ').toLowerCase();
          return queryTokens.every(searchText.contains);
        })
        .toList(growable: false);
  }

  void _handleSearchChanged() => setState(() {});
}

class _EnemyCatalogThumbnail extends StatefulWidget {
  const _EnemyCatalogThumbnail({
    super.key,
    required this.enemy,
    required this.imageCache,
    required this.workspaceRootPath,
  });

  final ChunkMarkerEnemyCatalogEntry enemy;
  final EditorUiImageCache imageCache;
  final String workspaceRootPath;

  @override
  State<_EnemyCatalogThumbnail> createState() => _EnemyCatalogThumbnailState();
}

class _EnemyCatalogThumbnailState extends State<_EnemyCatalogThumbnail> {
  var _loadEpoch = 0;

  String? get _absolutePath {
    final sourcePath = widget.enemy.previewSourcePath?.trim();
    if (sourcePath == null || sourcePath.isEmpty) return null;
    return p.normalize(
      p.join(widget.workspaceRootPath, 'assets', 'images', sourcePath),
    );
  }

  @override
  void initState() {
    super.initState();
    _ensureImageLoaded();
  }

  @override
  void didUpdateWidget(covariant _EnemyCatalogThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enemy.markerId != widget.enemy.markerId ||
        oldWidget.imageCache != widget.imageCache ||
        oldWidget.workspaceRootPath != widget.workspaceRootPath) {
      _ensureImageLoaded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final absolutePath = _absolutePath;
    final image = absolutePath == null
        ? null
        : widget.imageCache.imageFor(absolutePath);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF101820),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CustomPaint(
          painter: _EnemyCatalogThumbnailPainter(
            enemy: widget.enemy,
            image: image,
          ),
        ),
      ),
    );
  }

  void _ensureImageLoaded() {
    final epoch = ++_loadEpoch;
    final absolutePath = _absolutePath;
    if (absolutePath == null) return;
    unawaited(() async {
      await widget.imageCache.ensureLoaded(absolutePath);
      if (mounted && epoch == _loadEpoch) setState(() {});
    }());
  }
}

final class _EnemyCatalogThumbnailPainter extends CustomPainter {
  const _EnemyCatalogThumbnailPainter({required this.enemy, this.image});

  final ChunkMarkerEnemyCatalogEntry enemy;
  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final image = this.image;
    if (image == null) {
      _paintMissingPreview(canvas, size);
      return;
    }
    final columns = enemy.previewGridColumns;
    final startFrame = enemy.previewStartFrame;
    final column = columns == null ? startFrame : startFrame % columns;
    final rowOffset = columns == null ? 0 : startFrame ~/ columns;
    final source = Rect.fromLTWH(
      (column * enemy.renderAnim.frameWidth).toDouble(),
      ((enemy.previewRow + rowOffset) * enemy.renderAnim.frameHeight)
          .toDouble(),
      enemy.renderAnim.frameWidth.toDouble(),
      enemy.renderAnim.frameHeight.toDouble(),
    );
    if (source.right > image.width || source.bottom > image.height) {
      _paintMissingPreview(canvas, size);
      return;
    }
    const padding = 8.0;
    final available = Size(
      (size.width - padding * 2).clamp(1, double.infinity),
      (size.height - padding * 2).clamp(1, double.infinity),
    );
    final fitted = applyBoxFit(BoxFit.contain, source.size, available);
    final destination = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  void _paintMissingPreview(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF607D8B)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: 28,
      height: 28,
    );
    canvas.drawCircle(rect.center, 9, paint);
    canvas.drawLine(rect.bottomLeft, rect.topRight, paint);
  }

  @override
  bool shouldRepaint(covariant _EnemyCatalogThumbnailPainter oldDelegate) =>
      oldDelegate.enemy.markerId != enemy.markerId ||
      oldDelegate.image != image;
}
