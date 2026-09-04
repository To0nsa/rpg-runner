import 'package:flutter/material.dart';

import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/models/models.dart';
import '../../shared/editor_list_card.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_ui_tokens.dart';
import '../../shared/editor_visual_catalog.dart';
import '../shared/prefab_polygon_visual_source.dart';
import '../shared/prefab_visual_catalog_support.dart';

/// Searchable visual owner library for Prefab-v3 authoring.
///
/// Search and filters are transient presentation state. Owner navigation keeps
/// the immutable `prefabKey` identity, and the selected owner's editor is
/// rendered in the card's detail slot rather than detached from the library.
class PrefabOwnerCatalogBrowser extends StatefulWidget {
  PrefabOwnerCatalogBrowser({
    super.key,
    required Iterable<PrefabV3Def> prefabs,
    required this.prefabData,
    required this.tileData,
    required Map<String, PrefabV3VisualBounds> visualBoundsByPrefabKey,
    required this.workspaceRootPath,
    required this.selectedPrefabKey,
    required this.expandedPrefabKey,
    required Iterable<String> changedPrefabKeys,
    required Iterable<PrefabV3DownstreamImpact> downstreamImpacts,
    required this.onSelected,
    this.selectedDetailsBuilder,
    this.enabled = true,
  }) : prefabs = List<PrefabV3Def>.unmodifiable(prefabs),
       visualBoundsByPrefabKey = Map<String, PrefabV3VisualBounds>.unmodifiable(
         visualBoundsByPrefabKey,
       ),
       changedPrefabKeys = Set<String>.unmodifiable(changedPrefabKeys),
       downstreamImpacts = List<PrefabV3DownstreamImpact>.unmodifiable(
         downstreamImpacts,
       );

  final List<PrefabV3Def> prefabs;
  final PrefabV3FileData prefabData;
  final PrefabTileFileData tileData;
  final Map<String, PrefabV3VisualBounds> visualBoundsByPrefabKey;
  final String workspaceRootPath;
  final String? selectedPrefabKey;
  final String? expandedPrefabKey;
  final Set<String> changedPrefabKeys;
  final List<PrefabV3DownstreamImpact> downstreamImpacts;
  final ValueChanged<PrefabV3Def> onSelected;

  /// Optional row-local editor. When omitted, the catalog is selection-only.
  final Widget Function(BuildContext context, PrefabV3Def prefab)?
  selectedDetailsBuilder;
  final bool enabled;

  @override
  State<PrefabOwnerCatalogBrowser> createState() =>
      _PrefabOwnerCatalogBrowserState();
}

class _PrefabOwnerCatalogBrowserState extends State<PrefabOwnerCatalogBrowser> {
  late final TextEditingController _searchController;
  late EditorUiImageCache _imageCache;
  late Map<String, PrefabPolygonVisualProjection> _projectionsByPrefabKey;
  PrefabKind? _kindFilter;
  PrefabStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_handlePresentationChanged);
    _imageCache = EditorUiImageCache();
    _rebuildProjections();
  }

  @override
  void didUpdateWidget(covariant PrefabOwnerCatalogBrowser oldWidget) {
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
    if (_kindFilter != null &&
        !widget.prefabs.any((prefab) => prefab.kind == _kindFilter)) {
      _kindFilter = null;
    }
    if (_statusFilter != null &&
        !widget.prefabs.any((prefab) => prefab.status == _statusFilter)) {
      _statusFilter = null;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handlePresentationChanged);
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
    final availableStatuses = widget.prefabs
        .map((prefab) => prefab.status)
        .toSet();
    final impactsByPrefabKey = <String, PrefabV3DownstreamImpact>{
      for (final impact in widget.downstreamImpacts) impact.prefabKey: impact,
    };

    final controls = EditorVisualCatalogControls(
      searchController: _searchController,
      searchKey: const ValueKey<String>('prefab_owner_catalog_search'),
      searchLabel: 'Search prefabs',
      searchHint: 'ID, key, kind, source, or tags',
      clearSearchKey: const ValueKey<String>(
        'prefab_owner_catalog_clear_search',
      ),
      clearSearchTooltip: 'Clear prefab search',
      filters: <Widget>[
        ChoiceChip(
          key: const ValueKey<String>('prefab_owner_catalog_kind_all'),
          label: const Text('All kinds'),
          selected: _kindFilter == null,
          onSelected: widget.enabled
              ? (_) => setState(() => _kindFilter = null)
              : null,
        ),
        for (final kind in sortedKinds)
          ChoiceChip(
            key: ValueKey<String>(
              'prefab_owner_catalog_kind_${kind.jsonValue}',
            ),
            label: Text(prefabCatalogKindLabel(kind)),
            selected: _kindFilter == kind,
            onSelected: widget.enabled
                ? (_) => setState(() => _kindFilter = kind)
                : null,
          ),
        if (availableStatuses.length > 1) ...<Widget>[
          const SizedBox(height: 28, child: VerticalDivider(width: 1)),
          ChoiceChip(
            key: const ValueKey<String>('prefab_owner_catalog_status_all'),
            label: const Text('All statuses'),
            selected: _statusFilter == null,
            onSelected: widget.enabled
                ? (_) => setState(() => _statusFilter = null)
                : null,
          ),
          for (final status in PrefabStatus.values.where(
            availableStatuses.contains,
          ))
            ChoiceChip(
              key: ValueKey<String>(
                'prefab_owner_catalog_status_${status.jsonValue}',
              ),
              label: Text(_statusLabel(status)),
              selected: _statusFilter == status,
              onSelected: widget.enabled
                  ? (_) => setState(() => _statusFilter = status)
                  : null,
            ),
        ],
      ],
      countKey: const ValueKey<String>('prefab_owner_catalog_count'),
      countLabel:
          '${filteredPrefabs.length} of ${widget.prefabs.length} prefabs',
      onSearchSubmitted: () {
        final matches = _filteredPrefabs();
        if (matches.isNotEmpty) widget.onSelected(matches.first);
      },
      enabled: widget.enabled,
    );
    return Column(
      key: const ValueKey<String>('prefab_owner_catalog_list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        controls,
        const SizedBox(height: EditorUiTokens.sectionGap),
        if (filteredPrefabs.isEmpty)
          const Padding(
            key: ValueKey<String>('prefab_owner_catalog_empty'),
            padding: EdgeInsets.symmetric(
              vertical: EditorUiTokens.panelPadding,
            ),
            child: Text(
              'No prefabs match the current search and filters.',
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final prefab in filteredPrefabs)
            _buildOwnerCard(
              context,
              prefab,
              impactsByPrefabKey[prefab.prefabKey],
            ),
      ],
    );
  }

  Widget _buildOwnerCard(
    BuildContext context,
    PrefabV3Def prefab,
    PrefabV3DownstreamImpact? impact,
  ) {
    final selected = prefab.prefabKey == widget.selectedPrefabKey;
    final expanded = prefab.prefabKey == widget.expandedPrefabKey;
    final tagText = prefab.tags.isEmpty ? 'No tags' : prefab.tags.join(', ');
    final subtitle =
        '${prefabCatalogKindLabel(prefab.kind)} · rev ${prefab.revision} · '
        '${prefab.visualSource.type.jsonValue}:${prefab.sourceRefId}\n'
        '${_statusLabel(prefab.status)} · ${prefab.collisionShapes.length} '
        'collision shape(s) · ${impact?.placementCount ?? 0} placement(s) '
        'in ${impact?.referencingChunkKeys.length ?? 0} chunk(s)\n$tagText';
    return EditorListCard(
      key: ValueKey<String>('prefab_polygon_owner_${prefab.prefabKey}'),
      isSelected: selected,
      onTap: widget.enabled ? () => widget.onSelected(prefab) : null,
      semanticLabel:
          '${prefab.id}, ${prefabCatalogKindLabel(prefab.kind)}, '
          '${_statusLabel(prefab.status)}, $tagText',
      preview: SizedBox(
        key: ValueKey<String>(
          'prefab_owner_catalog_preview_${prefab.prefabKey}',
        ),
        width: 96,
        height: 76,
        child: PrefabCatalogThumbnail(
          projection: _projectionsByPrefabKey[prefab.prefabKey]!,
          imageCache: _imageCache,
          workspaceRootPath: widget.workspaceRootPath,
        ),
      ),
      trailing: widget.changedPrefabKeys.contains(prefab.prefabKey)
          ? const Tooltip(
              message: 'Pending prefab changed',
              child: Icon(Icons.circle, size: 12),
            )
          : null,
      details: expanded && widget.selectedDetailsBuilder != null
          ? KeyedSubtree(
              key: ValueKey<String>(
                'prefab_v3_owner_inline_editor_${prefab.prefabKey}',
              ),
              child: widget.selectedDetailsBuilder!(context, prefab),
            )
          : null,
      child: Tooltip(
        message: '${prefab.id}\n$subtitle',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          selected: selected,
          title: Text(prefab.id),
          subtitle: Text(subtitle),
          isThreeLine: true,
        ),
      ),
    );
  }

  List<PrefabV3Def> _filteredPrefabs() => filterPrefabCatalogRecords(
    prefabs: widget.prefabs,
    query: _searchController.text,
    kind: _kindFilter,
    status: _statusFilter,
  );

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

  void _handlePresentationChanged() => setState(() {});
}

String _statusLabel(PrefabStatus status) => switch (status) {
  PrefabStatus.active => 'Active',
  PrefabStatus.deprecated => 'Deprecated',
  PrefabStatus.unknown => 'Unknown',
};
