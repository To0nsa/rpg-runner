import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_domain_plugin.dart';
import '../../../../chunks/chunk_marker_authoring_catalog.dart';
import '../../../../chunks/chunk_v2_composition_commit.dart';
import '../../../../chunks/chunk_v2_composition_operation.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_models.dart';
import '../../../../domain/authoring_types.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../prefabs/store/prefab_determinism.dart';
import '../../../../session/editor_session_controller.dart';
import '../../shared/editor_list_card.dart';
import '../../shared/editor_section_card.dart';
import 'chunk_enemy_catalog_browser.dart';
import 'chunk_prefab_catalog_browser.dart';
import 'chunk_v2_composition_dialog.dart';
import 'chunk_v2_composition_forms.dart';

/// User-facing composition section shown by one Chunk workspace tab.
enum ChunkCompositionSection { prefabs, markers, layers }

/// Sidebar section group for one current Chunk-v2 composition domain.
///
/// Each accepted action replaces the three canonical composition lists through
/// one typed plugin command. Identity, metadata, dimensions, and polygons are
/// never included in the route-owned edit payload.
class ChunkCompositionCard extends StatefulWidget {
  const ChunkCompositionCard({
    super.key,
    required this.section,
    required this.controller,
    required this.document,
    required this.chunk,
    required this.controlsEnabled,
    required this.onOperationChanged,
    required this.selectedPrefabKey,
    required this.selectedMarkerKey,
    required this.selectedCatalogPrefabKey,
    required this.selectedCatalogMarkerId,
    this.onOpenOwningPrefab,
    required this.onPrefabSelectionChanged,
    required this.onMarkerSelected,
    required this.onCatalogPrefabSelected,
    required this.onCatalogMarkerSelected,
  });

  final ChunkCompositionSection section;
  final EditorSessionController controller;
  final ChunkV2Document document;
  final ChunkV2FileData chunk;
  final bool controlsEnabled;
  final ValueChanged<bool> onOperationChanged;
  final String? selectedPrefabKey;
  final String? selectedMarkerKey;
  final String? selectedCatalogPrefabKey;
  final String? selectedCatalogMarkerId;
  final ValueChanged<String>? onOpenOwningPrefab;
  final ValueChanged<ChunkPlacedPrefabSelection?> onPrefabSelectionChanged;
  final ValueChanged<ChunkPlacedMarkerSelection> onMarkerSelected;
  final ValueChanged<PrefabV3Def> onCatalogPrefabSelected;
  final ValueChanged<String> onCatalogMarkerSelected;

  @override
  State<ChunkCompositionCard> createState() => _ChunkCompositionCardState();
}

final class _ChunkCompositionCardState extends State<ChunkCompositionCard> {
  _InlinePlacementEdit? _placementEdit;

  ChunkCompositionSection get section => widget.section;
  EditorSessionController get controller => widget.controller;
  ChunkV2Document get document => widget.document;
  ChunkV2FileData get chunk => widget.chunk;
  bool get controlsEnabled => widget.controlsEnabled;
  ValueChanged<bool> get onOperationChanged => widget.onOperationChanged;
  String? get selectedPrefabKey => widget.selectedPrefabKey;
  String? get selectedMarkerKey => widget.selectedMarkerKey;
  String? get selectedCatalogPrefabKey => widget.selectedCatalogPrefabKey;
  String? get selectedCatalogMarkerId => widget.selectedCatalogMarkerId;
  ValueChanged<String>? get onOpenOwningPrefab => widget.onOpenOwningPrefab;
  ValueChanged<ChunkPlacedPrefabSelection?> get onPrefabSelectionChanged =>
      widget.onPrefabSelectionChanged;
  ValueChanged<ChunkPlacedMarkerSelection> get onMarkerSelected =>
      widget.onMarkerSelected;
  ValueChanged<PrefabV3Def> get onCatalogPrefabSelected =>
      widget.onCatalogPrefabSelected;
  ValueChanged<String> get onCatalogMarkerSelected =>
      widget.onCatalogMarkerSelected;

  @override
  void didUpdateWidget(covariant ChunkCompositionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section ||
        oldWidget.chunk.chunkKey != widget.chunk.chunkKey ||
        oldWidget.chunk.revision != widget.chunk.revision) {
      _placementEdit = null;
      return;
    }
    if (oldWidget.selectedPrefabKey != widget.selectedPrefabKey) {
      _placementEdit = _placementEditForKey(selectedPrefabKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: switch (section) {
        ChunkCompositionSection.prefabs => <Widget>[_buildPlacements(context)],
        ChunkCompositionSection.markers => <Widget>[_buildMarkers(context)],
        ChunkCompositionSection.layers => <Widget>[
          _buildVisualStackPreview(context),
          const SizedBox(height: 12),
          _buildTileLayers(context),
        ],
      },
    );
  }

  Widget _buildVisualStackPreview(BuildContext context) {
    final placements = buildChunkPlacedPrefabSelections(chunk.prefabs);
    final entries = <_ChunkVisualStackEntry>[
      _ChunkVisualStackEntry.ground(
        zIndex: chunk.groundBandZIndex,
        shapeCount: chunk.collisionShapes.length,
      ),
      for (var index = 0; index < placements.length; index += 1)
        _ChunkVisualStackEntry.prefab(
          placementKey: placements[index].selectionKey,
          label: _prefabLabel(placements[index].prefab),
          zIndex: placements[index].prefab.zIndex,
          tieOrder: index,
        ),
    ]..sort(_compareVisualStackEntries);
    return EditorSectionCard(
      key: const ValueKey<String>('chunk_visual_stack_preview'),
      title: 'Visual stack preview · bottom → top',
      description:
          'Preview only: polygon fill and prefab visual order are not '
          'runtime collision authority.',
      collapsible: true,
      initiallyExpanded: false,
      expansionKey: const ValueKey<String>('chunk_visual_stack_preview_toggle'),
      child: SizedBox(
        height: 34,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (var index = 0; index < entries.length; index += 1) ...[
                if (index > 0) const SizedBox(width: 6),
                Semantics(
                  sortKey: OrdinalSortKey(index.toDouble()),
                  label: entries[index].semanticLabel,
                  child: Chip(
                    key: ValueKey<String>(entries[index].widgetKey),
                    avatar: Icon(
                      entries[index].isGround
                          ? Icons.landscape_outlined
                          : Icons.image_outlined,
                      size: 17,
                    ),
                    label: Text(entries[index].displayLabel),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTileLayers(BuildContext context) => _CompositionSection(
    sectionKey: 'chunk_layer_metadata_section',
    expansionKey: 'chunk_layer_metadata_section_toggle',
    title: 'Tile layer metadata',
    addKey: 'chunk_v2_layer_add',
    addLabel: 'Add layer',
    onAdd: controlsEnabled ? () => _addTileLayer(context) : null,
    emptyMessage: 'No tile layer metadata.',
    children: <Widget>[
      for (final layer in chunk.tileLayers)
        EditorListCard(
          key: ValueKey<String>('chunk_v2_layer_${layer.id}'),
          trailing: _EditDeleteActions(
            editKey: 'chunk_v2_layer_edit_${layer.id}',
            deleteKey: 'chunk_v2_layer_delete_${layer.id}',
            onEdit: controlsEnabled
                ? () => _editTileLayer(context, layer)
                : null,
            onDelete: controlsEnabled
                ? () => _deleteTileLayer(context, layer)
                : null,
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(layer.id),
            subtitle: Text(
              '${layer.kind} · ${layer.visible ? 'visible' : 'hidden'}',
            ),
          ),
        ),
    ],
  );

  Widget _buildPlacements(BuildContext context) {
    final placements = buildChunkPlacedPrefabSelections(chunk.prefabs);
    final activePrefabs = PrefabDeterminism.sortPrefabV3ByIdThenKey(
      document.prefabData.prefabs.where(
        (prefab) => prefab.status == PrefabStatus.active,
      ),
    );
    final selectedCatalogPrefab = activePrefabs
        .where((prefab) => prefab.prefabKey == selectedCatalogPrefabKey)
        .firstOrNull;
    final effectiveCatalogPrefab =
        selectedCatalogPrefab ?? activePrefabs.firstOrNull;
    final usedPrefabKeys = <String>{
      for (final placement in chunk.prefabs)
        if (resolveChunkV2PlacementPrefab(
              document.prefabData.prefabs,
              placement,
            )
            case final prefab?)
          prefab.prefabKey,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        EditorSectionCard(
          key: const ValueKey<String>('chunk_prefab_catalog_section'),
          title: 'Prefab library',
          description:
              'Search by name, kind, or tags. The selected prefab is shared '
              'by the scene Place tool and the creation form below.',
          collapsible: true,
          initiallyExpanded: false,
          expansionKey: const ValueKey<String>(
            'chunk_prefab_catalog_section_toggle',
          ),
          child: activePrefabs.isEmpty
              ? const Text('No active prefab owners are available.')
              : ChunkPrefabCatalogBrowser(
                  prefabs: activePrefabs,
                  prefabData: document.prefabData,
                  tileData: document.tileData,
                  visualBoundsByPrefabKey: document.visualBoundsByPrefabKey,
                  workspaceRootPath: controller.workspacePath,
                  selectedPrefabKey: effectiveCatalogPrefab?.prefabKey,
                  usedPrefabKeys: usedPrefabKeys,
                  enabled: controlsEnabled,
                  onSelected: onCatalogPrefabSelected,
                ),
        ),
        const SizedBox(height: 12),
        EditorSectionCard(
          key: const ValueKey<String>('chunk_prefab_creation_panel'),
          title: 'Create prefab placement',
          description:
              'Choose the prefab and placement values, then add it directly '
              'to this chunk.',
          collapsible: true,
          initiallyExpanded: false,
          expansionKey: const ValueKey<String>(
            'chunk_prefab_creation_panel_toggle',
          ),
          child: effectiveCatalogPrefab == null
              ? const Text('No active prefab owners are available.')
              : ChunkV2PlacementForm(
                  key: ValueKey<String>(
                    'chunk_prefab_creation_form_${chunk.chunkKey}',
                  ),
                  prefab: effectiveCatalogPrefab,
                  fieldKeyPrefix: 'chunk_v2_placement_creation',
                  submitKey: 'chunk_v2_placement_add',
                  submitLabel: 'Add placement',
                  enabled: controlsEnabled,
                  onSubmit: (candidate) => _addPlacement(context, candidate),
                ),
        ),
        const SizedBox(height: 12),
        EditorSectionCard(
          key: const ValueKey<String>('chunk_prefab_placements_section'),
          title: 'Existing prefab placements',
          description: placements.isEmpty
              ? 'Saved prefab placements will appear here.'
              : _placementEdit == null
              ? 'Select a placement in the list or scene to manage it.'
              : 'Edit the expanded placement, then apply or cancel the draft.',
          trailing: Text('${placements.length} total'),
          collapsible: _placementEdit == null,
          initiallyExpanded: _placementEdit != null,
          expansionKey: const ValueKey<String>(
            'chunk_prefab_placements_section_toggle',
          ),
          child: placements.isEmpty
              ? const Text(
                  'No existing prefab placements. Use the creation card '
                  'above to add the first one.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final selection in placements) ...<Widget>[
                      EditorListCard(
                        key: ValueKey<String>(
                          'chunk_v2_placement_${selection.selectionKey}',
                        ),
                        isSelected: selection.selectionKey == selectedPrefabKey,
                        onTap:
                            controlsEnabled &&
                                (_placementEdit == null ||
                                    _placementEdit?.selectionKey ==
                                        selection.selectionKey)
                            ? () => _selectOrClosePlacement(selection)
                            : null,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_prefabLabel(selection.prefab)),
                          subtitle: Text(
                            'x=${selection.prefab.x}, '
                            'y=${selection.prefab.y} · '
                            'z=${selection.prefab.zIndex} · '
                            'scale=${selection.prefab.scale.toStringAsFixed(1)} · '
                            '${selection.prefab.snapToGrid ? 'snap' : 'free'} · '
                            '${_flipLabel(selection.prefab)}',
                          ),
                        ),
                      ),
                      if (_placementEdit?.selectionKey ==
                          selection.selectionKey)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                          child: _buildPlacementEditDetails(
                            context,
                            selection,
                            usedPrefabKeys,
                          ),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildMarkers(BuildContext context) {
    final markers = buildChunkPlacedMarkerSelections(chunk.markers);
    final effectiveEnemyId =
        chunkMarkerEnemyCatalogEntryFor(selectedCatalogMarkerId ?? '')
            ?.markerId ??
        chunkMarkerEnemyIds.first;
    final usedEnemyIds = chunk.markers.map((marker) => marker.markerId).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        EditorSectionCard(
          key: const ValueKey<String>('chunk_enemy_catalog_section'),
          title: 'Enemy library',
          description:
              'Search by name, ID, or movement role. The selected enemy is '
              'shared by the scene Place tool and the creation form below.',
          collapsible: true,
          initiallyExpanded: false,
          expansionKey: const ValueKey<String>(
            'chunk_enemy_catalog_section_toggle',
          ),
          child: ChunkEnemyCatalogBrowser(
            workspaceRootPath: controller.workspacePath,
            selectedEnemyId: effectiveEnemyId,
            usedEnemyIds: usedEnemyIds,
            enabled: controlsEnabled,
            onSelected: onCatalogMarkerSelected,
          ),
        ),
        const SizedBox(height: 12),
        EditorSectionCard(
          key: const ValueKey<String>('chunk_marker_creation_panel'),
          title: 'Create enemy marker',
          description:
              'Choose the enemy and spawn values, then add the marker '
              'directly to this chunk.',
          collapsible: true,
          initiallyExpanded: false,
          expansionKey: const ValueKey<String>(
            'chunk_marker_creation_panel_toggle',
          ),
          child: ChunkV2MarkerForm(
            key: ValueKey<String>(
              'chunk_marker_creation_form_${chunk.chunkKey}',
            ),
            chunk: chunk,
            enemyId: effectiveEnemyId,
            fieldKeyPrefix: 'chunk_v2_marker_creation',
            submitKey: 'chunk_v2_marker_add',
            submitLabel: 'Add marker',
            enabled: controlsEnabled,
            onSubmit: (candidate) => _addMarker(context, candidate),
          ),
        ),
        const SizedBox(height: 12),
        EditorSectionCard(
          key: const ValueKey<String>('chunk_enemy_markers_section'),
          title: 'Existing enemy markers',
          description: markers.isEmpty
              ? 'Saved enemy markers will appear here.'
              : 'Select a marker in the list or scene to manage it.',
          trailing: Text('${markers.length} total'),
          collapsible: true,
          initiallyExpanded: false,
          expansionKey: const ValueKey<String>(
            'chunk_enemy_markers_section_toggle',
          ),
          child: markers.isEmpty
              ? const Text(
                  'No existing enemy markers. Use the creation card above '
                  'to add the first one.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final selection in markers)
                      EditorListCard(
                        key: ValueKey<String>(
                          'chunk_v2_marker_${selection.selectionKey}',
                        ),
                        isSelected: selection.selectionKey == selectedMarkerKey,
                        onTap: controlsEnabled
                            ? () => onMarkerSelected(selection)
                            : null,
                        trailing: _EditDeleteActions(
                          editKey:
                              'chunk_v2_marker_edit_${selection.selectionKey}',
                          deleteKey:
                              'chunk_v2_marker_delete_${selection.selectionKey}',
                          onEdit: controlsEnabled
                              ? () => _editMarker(context, selection)
                              : null,
                          onDelete: controlsEnabled
                              ? () => _deleteMarker(context, selection)
                              : null,
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(selection.marker.markerId),
                          subtitle: Text(
                            'x=${selection.marker.x}, '
                            'y=${selection.marker.y} · '
                            '${selection.marker.chancePercent}% · '
                            'salt=${selection.marker.salt} · '
                            '${selection.marker.placement}',
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _addTileLayer(BuildContext context) async {
    final operation = ChunkV2CompositionOperation.add(
      chunk: chunk,
      target: ChunkV2CompositionTarget.tileLayers,
    );
    await _runOperation(() async {
      final layer = await showChunkV2TileLayerDialog(context, chunk: chunk);
      if (layer == null || !context.mounted) return;
      _dispatch(context, operation.buildTileLayer(candidate: layer));
    });
  }

  Future<void> _editTileLayer(
    BuildContext context,
    TileLayerDef current,
  ) async {
    final operation = ChunkV2CompositionOperation.replace(
      chunk: chunk,
      target: ChunkV2CompositionTarget.tileLayers,
      sourceIndex: chunk.tileLayers.indexOf(current),
      presentationKey: current.id,
    );
    await _runOperation(() async {
      final layer = await showChunkV2TileLayerDialog(
        context,
        chunk: chunk,
        layer: current,
      );
      if (layer == null || !context.mounted) return;
      _dispatch(context, operation.buildTileLayer(candidate: layer));
    });
  }

  Future<void> _deleteTileLayer(
    BuildContext context,
    TileLayerDef layer,
  ) async {
    final operation = ChunkV2CompositionOperation.delete(
      chunk: chunk,
      target: ChunkV2CompositionTarget.tileLayers,
      sourceIndex: chunk.tileLayers.indexOf(layer),
      presentationKey: layer.id,
    );
    await _runOperation(() async {
      if (!await _confirmDelete(context, 'tile layer ${layer.id}')) return;
      if (!context.mounted) return;
      _dispatch(context, operation.buildTileLayer());
    });
  }

  void _addPlacement(BuildContext context, PlacedPrefabDef candidate) {
    final operation = ChunkV2CompositionOperation.add(
      chunk: chunk,
      target: ChunkV2CompositionTarget.prefabs,
    );
    _dispatch(context, operation.buildPrefab(candidate: candidate));
  }

  void _selectOrClosePlacement(ChunkPlacedPrefabSelection selection) {
    if (_placementEdit?.selectionKey == selection.selectionKey) {
      _cancelPlacementEdit();
      return;
    }
    _beginPlacementEdit(selection);
  }

  void _beginPlacementEdit(ChunkPlacedPrefabSelection selection) {
    final edit = _createPlacementEdit(selection);
    if (edit == null) return;
    setState(() => _placementEdit = edit);
    onPrefabSelectionChanged(selection);
  }

  _InlinePlacementEdit? _placementEditForKey(String? selectionKey) {
    if (selectionKey == null) return null;
    final selection = buildChunkPlacedPrefabSelections(chunk.prefabs)
        .where((selection) => selection.selectionKey == selectionKey)
        .firstOrNull;
    return selection == null ? null : _createPlacementEdit(selection);
  }

  _InlinePlacementEdit? _createPlacementEdit(
    ChunkPlacedPrefabSelection selection,
  ) {
    final owner = resolveChunkV2PlacementPrefab(
      document.prefabData.prefabs,
      selection.prefab,
    );
    if (owner == null) return null;
    final operation = ChunkV2CompositionOperation.replace(
      chunk: chunk,
      target: ChunkV2CompositionTarget.prefabs,
      sourceIndex: selection.sourceIndex,
      presentationKey: selection.selectionKey,
    );
    return _InlinePlacementEdit(
      selectionKey: selection.selectionKey,
      placement: selection.prefab,
      selectedPrefabKey: owner.prefabKey,
      operation: operation,
    );
  }

  Widget _buildPlacementEditDetails(
    BuildContext context,
    ChunkPlacedPrefabSelection selection,
    Set<String> usedPrefabKeys,
  ) {
    final edit = _placementEdit!;
    final currentOwner = resolveChunkV2PlacementPrefab(
      document.prefabData.prefabs,
      edit.placement,
    )!;
    final selectableOwners = PrefabDeterminism.sortPrefabV3ByIdThenKey(
      document.prefabData.prefabs.where(
        (prefab) =>
            prefab.status == PrefabStatus.active ||
            prefab.prefabKey == currentOwner.prefabKey,
      ),
    );
    final selectedOwner = selectableOwners.singleWhere(
      (prefab) => prefab.prefabKey == edit.selectedPrefabKey,
    );
    final keySuffix = selection.selectionKey;
    return Column(
      key: ValueKey<String>('chunk_v2_placement_inline_editor_$keySuffix'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Edit ${_prefabLabel(selection.prefab)}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            if (onOpenOwningPrefab != null)
              OutlinedButton.icon(
                key: ValueKey<String>(
                  'chunk_v2_placement_open_${selection.selectionKey}',
                ),
                onPressed: controlsEnabled
                    ? () => onOpenOwningPrefab!(
                        selection.prefab.resolvedPrefabRef,
                      )
                    : null,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open prefab'),
              ),
            OutlinedButton.icon(
              key: ValueKey<String>(
                'chunk_v2_placement_delete_${selection.selectionKey}',
              ),
              onPressed: controlsEnabled
                  ? () => _deletePlacement(context, selection)
                  : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a prefab and adjust this saved placement. Changes are '
          'staged only after Apply. Switching context discards this draft.',
        ),
        const SizedBox(height: 12),
        ChunkPrefabCatalogBrowser(
          prefabs: selectableOwners,
          prefabData: document.prefabData,
          tileData: document.tileData,
          visualBoundsByPrefabKey: document.visualBoundsByPrefabKey,
          workspaceRootPath: controller.workspacePath,
          selectedPrefabKey: selectedOwner.prefabKey,
          usedPrefabKeys: usedPrefabKeys,
          autofocusSearch: true,
          gridHeight: 248,
          keyPrefix: 'chunk_v2_placement_inline_catalog_$keySuffix',
          enabled: controlsEnabled,
          onSelected: (prefab) {
            setState(() {
              _placementEdit = edit.copyWith(
                selectedPrefabKey: prefab.prefabKey,
              );
            });
          },
        ),
        const Divider(height: 32),
        ChunkV2PlacementForm(
          key: ValueKey<String>('chunk_v2_placement_inline_form_$keySuffix'),
          prefab: selectedOwner,
          placement: edit.placement,
          fieldKeyPrefix: 'chunk_v2_placement_inline_$keySuffix',
          submitKey: 'chunk_v2_placement_inline_apply_$keySuffix',
          submitLabel: 'Apply changes',
          enabled: controlsEnabled,
          onCancel: _cancelPlacementEdit,
          onSubmit: (candidate) => _applyPlacementEdit(context, candidate),
        ),
      ],
    );
  }

  void _applyPlacementEdit(BuildContext context, PlacedPrefabDef candidate) {
    final edit = _placementEdit;
    if (edit == null) return;
    final commit = edit.operation.buildPrefab(candidate: candidate);
    _finishPlacementEdit();
    _dispatch(context, commit);
  }

  void _cancelPlacementEdit() {
    _finishPlacementEdit();
    onPrefabSelectionChanged(null);
  }

  void _finishPlacementEdit() {
    if (_placementEdit == null) return;
    setState(() => _placementEdit = null);
  }

  void _deletePlacement(
    BuildContext context,
    ChunkPlacedPrefabSelection selection,
  ) {
    final operation = ChunkV2CompositionOperation.delete(
      chunk: chunk,
      target: ChunkV2CompositionTarget.prefabs,
      sourceIndex: selection.sourceIndex,
      presentationKey: selection.selectionKey,
    );
    final commit = operation.buildPrefab();
    if (commit == null) return;
    _finishPlacementEdit();
    onPrefabSelectionChanged(null);
    _dispatch(context, commit);
  }

  void _addMarker(BuildContext context, PlacedMarkerDef candidate) {
    final operation = ChunkV2CompositionOperation.add(
      chunk: chunk,
      target: ChunkV2CompositionTarget.markers,
    );
    _dispatch(context, operation.buildMarker(candidate: candidate));
  }

  Future<void> _editMarker(
    BuildContext context,
    ChunkPlacedMarkerSelection selection,
  ) async {
    final operation = ChunkV2CompositionOperation.replace(
      chunk: chunk,
      target: ChunkV2CompositionTarget.markers,
      sourceIndex: selection.sourceIndex,
      presentationKey: selection.selectionKey,
    );
    await _runOperation(() async {
      final marker = await showChunkV2MarkerEditDialog(
        context,
        chunk: chunk,
        marker: selection.marker,
        workspaceRootPath: controller.workspacePath,
      );
      if (marker == null || !context.mounted) return;
      _dispatch(context, operation.buildMarker(candidate: marker));
    });
  }

  Future<void> _deleteMarker(
    BuildContext context,
    ChunkPlacedMarkerSelection selection,
  ) async {
    final operation = ChunkV2CompositionOperation.delete(
      chunk: chunk,
      target: ChunkV2CompositionTarget.markers,
      sourceIndex: selection.sourceIndex,
      presentationKey: selection.selectionKey,
    );
    await _runOperation(() async {
      if (!await _confirmDelete(context, 'enemy marker')) return;
      if (!context.mounted) return;
      _dispatch(context, operation.buildMarker());
    });
  }

  Future<bool> _confirmDelete(BuildContext context, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $label?'),
        content: Text('This stages one Chunk-v2 composition edit.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey<String>('chunk_v2_composition_delete_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _runOperation(Future<void> Function() operation) async {
    onOperationChanged(true);
    try {
      await operation();
    } finally {
      onOperationChanged(false);
    }
  }

  void _dispatch(BuildContext context, ChunkV2CompositionCommit? commit) {
    if (commit == null) return;
    final beforeDocument = controller.document;
    controller.applyCommand(
      AuthoringCommand(
        kind: ChunkDomainPlugin.commitChunkCompositionCommandKind,
        payload: <String, Object?>{
          'chunkKey': chunk.chunkKey,
          'commit': commit,
        },
      ),
    );
    if (identical(controller.document, beforeDocument) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Composition change was rejected. Review validation diagnostics '
            'and retry from the current chunk state.',
          ),
        ),
      );
    }
  }

  String _prefabLabel(PlacedPrefabDef placement) =>
      resolveChunkV2PlacementPrefab(
        document.prefabData.prefabs,
        placement,
      )?.id ??
      placement.resolvedPrefabRef;
}

final class _CompositionSection extends StatelessWidget {
  const _CompositionSection({
    required this.sectionKey,
    required this.expansionKey,
    required this.title,
    required this.addKey,
    required this.addLabel,
    required this.onAdd,
    required this.emptyMessage,
    required this.children,
  });

  final String sectionKey;
  final String expansionKey;
  final String title;
  final String addKey;
  final String addLabel;
  final VoidCallback? onAdd;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => EditorSectionCard(
    key: ValueKey<String>(sectionKey),
    title: title,
    collapsible: true,
    initiallyExpanded: false,
    expansionKey: ValueKey<String>(expansionKey),
    trailing: FilledButton.icon(
      key: ValueKey<String>(addKey),
      onPressed: onAdd,
      icon: const Icon(Icons.add),
      label: Text(addLabel),
    ),
    child: KeyedSubtree(
      key: ValueKey<String>('${sectionKey}_body'),
      child: children.isEmpty
          ? Text(emptyMessage)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
    ),
  );
}

final class _InlinePlacementEdit {
  const _InlinePlacementEdit({
    required this.selectionKey,
    required this.placement,
    required this.selectedPrefabKey,
    required this.operation,
  });

  final String selectionKey;
  final PlacedPrefabDef placement;
  final String selectedPrefabKey;
  final ChunkV2CompositionOperation operation;

  _InlinePlacementEdit copyWith({required String selectedPrefabKey}) =>
      _InlinePlacementEdit(
        selectionKey: selectionKey,
        placement: placement,
        selectedPrefabKey: selectedPrefabKey,
        operation: operation,
      );
}

final class _EditDeleteActions extends StatelessWidget {
  const _EditDeleteActions({
    required this.editKey,
    required this.deleteKey,
    required this.onEdit,
    required this.onDelete,
  });

  final String editKey;
  final String deleteKey;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    children: <Widget>[
      IconButton(
        key: ValueKey<String>(editKey),
        tooltip: 'Edit',
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined),
      ),
      IconButton(
        key: ValueKey<String>(deleteKey),
        tooltip: 'Delete',
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline),
      ),
    ],
  );
}

String _flipLabel(PlacedPrefabDef placement) {
  if (placement.flipX && placement.flipY) return 'flip X/Y';
  if (placement.flipX) return 'flip X';
  if (placement.flipY) return 'flip Y';
  return 'no flip';
}

final class _ChunkVisualStackEntry {
  const _ChunkVisualStackEntry._({
    required this.widgetKey,
    required this.label,
    required this.zIndex,
    required this.isGround,
    required this.shapeCount,
    required this.tieOrder,
  });

  const _ChunkVisualStackEntry.ground({
    required int zIndex,
    required int shapeCount,
  }) : this._(
         widgetKey: 'chunk_visual_stack_ground',
         label: 'Ground polygons',
         zIndex: zIndex,
         isGround: true,
         shapeCount: shapeCount,
         tieOrder: -1,
       );

  const _ChunkVisualStackEntry.prefab({
    required String placementKey,
    required String label,
    required int zIndex,
    required int tieOrder,
  }) : this._(
         widgetKey: 'chunk_visual_stack_prefab_$placementKey',
         label: label,
         zIndex: zIndex,
         isGround: false,
         shapeCount: 0,
         tieOrder: tieOrder,
       );

  final String widgetKey;
  final String label;
  final int zIndex;
  final bool isGround;
  final int shapeCount;
  final int tieOrder;

  String get displayLabel => isGround
      ? '$label · z=$zIndex · $shapeCount shape(s)'
      : '$label · z=$zIndex';

  String get semanticLabel => isGround
      ? '$label at visual z index $zIndex with $shapeCount direct shapes'
      : '$label prefab at visual z index $zIndex';
}

int _compareVisualStackEntries(
  _ChunkVisualStackEntry left,
  _ChunkVisualStackEntry right,
) {
  final zCompare = left.zIndex.compareTo(right.zIndex);
  if (zCompare != 0) return zCompare;
  if (left.isGround != right.isGround) return left.isGround ? -1 : 1;
  return left.tieOrder.compareTo(right.tieOrder);
}
