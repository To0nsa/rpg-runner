import 'package:flutter/material.dart';

import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/models/models.dart';
import '../../prefabCreator/shared/prefab_polygon_visual_source.dart';
import '../../prefabCreator/shared/prefab_visual_catalog_support.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_visual_catalog.dart';

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
        !samePrefabCatalogVisualBounds(
          oldWidget.visualBoundsByPrefabKey,
          widget.visualBoundsByPrefabKey,
        ) ||
        !samePrefabCatalogRecords(oldWidget.prefabs, widget.prefabs)) {
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

    return EditorVisualCatalogLayout(
      searchController: _searchController,
      searchKey: ValueKey<String>('${widget.keyPrefix}_search'),
      searchLabel: 'Search prefabs',
      searchHint: 'ID, kind, or tags such as rock dark moss',
      clearSearchKey: ValueKey<String>('${widget.keyPrefix}_clear_search'),
      clearSearchTooltip: 'Clear prefab search',
      filters: <Widget>[
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
            key: ValueKey<String>('${widget.keyPrefix}_kind_${kind.jsonValue}'),
            label: Text(prefabCatalogKindLabel(kind)),
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
      countKey: ValueKey<String>('${widget.keyPrefix}_count'),
      countLabel:
          '${filteredPrefabs.length} of ${widget.prefabs.length} prefabs',
      gridKey: ValueKey<String>('${widget.keyPrefix}_grid'),
      emptyKey: ValueKey<String>('${widget.keyPrefix}_empty'),
      emptyMessage: 'No prefabs match the current search and filters.',
      itemCount: filteredPrefabs.length,
      itemBuilder: (context, index) {
        final prefab = filteredPrefabs[index];
        final selected = prefab.prefabKey == widget.selectedPrefabKey;
        final tagText = prefab.tags.isEmpty
            ? 'No tags'
            : prefab.tags.join(', ');
        return EditorVisualCatalogCard(
          key: ValueKey<String>('${widget.keyPrefix}_card_${prefab.prefabKey}'),
          semanticsLabel:
              '${prefab.id}, ${prefabCatalogKindLabel(prefab.kind)}, tags $tagText',
          tooltipMessage:
              '${prefab.id}\n${prefabCatalogKindLabel(prefab.kind)} · '
              '${prefab.sourceRefId}\n$tagText',
          selected: selected,
          enabled: widget.enabled,
          preview: PrefabCatalogThumbnail(
            key: ValueKey<String>(
              '${widget.keyPrefix}_preview_${prefab.prefabKey}',
            ),
            projection: _projectionsByPrefabKey[prefab.prefabKey]!,
            imageCache: _imageCache,
            workspaceRootPath: widget.workspaceRootPath,
          ),
          title: prefab.id,
          subtitle: '${prefabCatalogKindLabel(prefab.kind)} · $tagText',
          onTap: () => widget.onSelected(prefab),
        );
      },
      onSearchSubmitted: () {
        final matches = _filteredPrefabs();
        if (matches.isNotEmpty) widget.onSelected(matches.first);
      },
      enabled: widget.enabled,
      autofocusSearch: widget.autofocusSearch,
      gridHeight: widget.gridHeight,
    );
  }

  List<PrefabV3Def> _filteredPrefabs() {
    return filterPrefabCatalogRecords(
      prefabs: widget.prefabs,
      query: _searchController.text,
      kind: _kindFilter,
      usedPrefabKeys: widget.usedPrefabKeys,
      usedOnly: _usedInChunkOnly,
    );
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
