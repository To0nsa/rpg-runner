import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_domain_plugin.dart';
import '../../../../chunks/chunk_v2_composition_commit.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_models.dart';
import '../../../../domain/authoring_types.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../session/editor_session_controller.dart';
import '../../shared/editor_list_card.dart';
import '../../shared/editor_panel_card.dart';
import '../../shared/editor_section_card.dart';
import 'chunk_v2_composition_dialog.dart';

/// Sidebar card for one current Chunk-v2 owner's retained composition forms.
///
/// Each accepted action replaces the three canonical composition lists through
/// one typed plugin command. Identity, metadata, dimensions, and polygons are
/// never included in the route-owned edit payload.
class ChunkCompositionCard extends StatelessWidget {
  const ChunkCompositionCard({
    super.key,
    required this.controller,
    required this.document,
    required this.chunk,
    required this.controlsEnabled,
  });

  final EditorSessionController controller;
  final ChunkV2Document document;
  final ChunkV2FileData chunk;
  final bool controlsEnabled;

  @override
  Widget build(BuildContext context) => EditorPanelCard(
    key: const ValueKey<String>('chunk_composition_card'),
    title: 'Layers, prefabs & markers',
    description: controlsEnabled
        ? 'Layer metadata and placed chunk content.'
        : 'Finish or cancel the active terrain edit before changing composition.',
    collapsible: true,
    expansionKey: const ValueKey<String>('chunk_composition_card_toggle'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildVisualStackPreview(context),
        const SizedBox(height: 12),
        _buildTileLayers(context),
        const SizedBox(height: 12),
        _buildPlacements(context),
        const SizedBox(height: 12),
        _buildMarkers(context),
      ],
    ),
  );

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
    final canAdd = document.prefabData.prefabs.any(
      (prefab) => prefab.status == PrefabStatus.active,
    );
    return _CompositionSection(
      sectionKey: 'chunk_prefab_placements_section',
      expansionKey: 'chunk_prefab_placements_section_toggle',
      title: 'Prefab placements',
      addKey: 'chunk_v2_placement_add',
      addLabel: 'Add placement',
      onAdd: controlsEnabled && canAdd ? () => _addPlacement(context) : null,
      emptyMessage: 'No prefab placements.',
      children: <Widget>[
        for (final selection in placements)
          EditorListCard(
            key: ValueKey<String>(
              'chunk_v2_placement_${selection.selectionKey}',
            ),
            trailing: _EditDeleteActions(
              editKey: 'chunk_v2_placement_edit_${selection.selectionKey}',
              deleteKey: 'chunk_v2_placement_delete_${selection.selectionKey}',
              onEdit: controlsEnabled
                  ? () => _editPlacement(context, selection)
                  : null,
              onDelete: controlsEnabled
                  ? () => _deletePlacement(context, selection)
                  : null,
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_prefabLabel(selection.prefab)),
              subtitle: Text(
                'x=${selection.prefab.x}, y=${selection.prefab.y} · '
                'z=${selection.prefab.zIndex} · '
                'scale=${selection.prefab.scale.toStringAsFixed(1)} · '
                '${selection.prefab.snapToGrid ? 'snap' : 'free'} · '
                '${_flipLabel(selection.prefab)}',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMarkers(BuildContext context) {
    final markers = buildChunkPlacedMarkerSelections(chunk.markers);
    return _CompositionSection(
      sectionKey: 'chunk_enemy_markers_section',
      expansionKey: 'chunk_enemy_markers_section_toggle',
      title: 'Enemy markers',
      addKey: 'chunk_v2_marker_add',
      addLabel: 'Add marker',
      onAdd: controlsEnabled ? () => _addMarker(context) : null,
      emptyMessage: 'No enemy markers.',
      children: <Widget>[
        for (final selection in markers)
          EditorListCard(
            key: ValueKey<String>('chunk_v2_marker_${selection.selectionKey}'),
            trailing: _EditDeleteActions(
              editKey: 'chunk_v2_marker_edit_${selection.selectionKey}',
              deleteKey: 'chunk_v2_marker_delete_${selection.selectionKey}',
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
                'x=${selection.marker.x}, y=${selection.marker.y} · '
                '${selection.marker.chancePercent}% · '
                'salt=${selection.marker.salt} · '
                '${selection.marker.placement}',
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addTileLayer(BuildContext context) async {
    final layer = await showChunkV2TileLayerDialog(context, chunk: chunk);
    if (layer == null || !context.mounted) return;
    final layers = <TileLayerDef>[...chunk.tileLayers, layer]
      ..sort((left, right) => left.id.compareTo(right.id));
    _dispatch(context, tileLayers: layers);
  }

  Future<void> _editTileLayer(
    BuildContext context,
    TileLayerDef current,
  ) async {
    final layer = await showChunkV2TileLayerDialog(
      context,
      chunk: chunk,
      layer: current,
    );
    if (layer == null || !context.mounted || _layersEqual(layer, current)) {
      return;
    }
    final layers =
        chunk.tileLayers
            .map(
              (candidate) => identical(candidate, current) ? layer : candidate,
            )
            .toList(growable: false)
          ..sort((left, right) => left.id.compareTo(right.id));
    _dispatch(context, tileLayers: layers);
  }

  Future<void> _deleteTileLayer(
    BuildContext context,
    TileLayerDef layer,
  ) async {
    if (!await _confirmDelete(context, 'tile layer ${layer.id}')) return;
    if (!context.mounted) return;
    _dispatch(
      context,
      tileLayers: chunk.tileLayers
          .where((candidate) => !identical(candidate, layer))
          .toList(growable: false),
    );
  }

  Future<void> _addPlacement(BuildContext context) async {
    final placement = await showChunkV2PlacementDialog(
      context,
      prefabs: document.prefabData.prefabs,
    );
    if (placement == null || !context.mounted) return;
    final placements = <PlacedPrefabDef>[...chunk.prefabs, placement]
      ..sort(comparePlacedPrefabsDeterministic);
    _dispatch(context, prefabs: placements);
  }

  Future<void> _editPlacement(
    BuildContext context,
    ChunkPlacedPrefabSelection selection,
  ) async {
    final placement = await showChunkV2PlacementDialog(
      context,
      prefabs: document.prefabData.prefabs,
      placement: selection.prefab,
    );
    if (placement == null ||
        !context.mounted ||
        _placementsEqual(placement, selection.prefab)) {
      return;
    }
    final placements =
        chunk.prefabs
            .map(
              (candidate) => identical(candidate, selection.prefab)
                  ? placement
                  : candidate,
            )
            .toList(growable: false)
          ..sort(comparePlacedPrefabsDeterministic);
    _dispatch(context, prefabs: placements);
  }

  Future<void> _deletePlacement(
    BuildContext context,
    ChunkPlacedPrefabSelection selection,
  ) async {
    if (!await _confirmDelete(context, 'prefab placement')) return;
    if (!context.mounted) return;
    _dispatch(
      context,
      prefabs: chunk.prefabs
          .where((candidate) => !identical(candidate, selection.prefab))
          .toList(growable: false),
    );
  }

  Future<void> _addMarker(BuildContext context) async {
    final marker = await showChunkV2MarkerDialog(context, chunk: chunk);
    if (marker == null || !context.mounted) return;
    final markers = <PlacedMarkerDef>[...chunk.markers, marker]
      ..sort(comparePlacedMarkersDeterministic);
    _dispatch(context, markers: markers);
  }

  Future<void> _editMarker(
    BuildContext context,
    ChunkPlacedMarkerSelection selection,
  ) async {
    final marker = await showChunkV2MarkerDialog(
      context,
      chunk: chunk,
      marker: selection.marker,
    );
    if (marker == null ||
        !context.mounted ||
        _markersEqual(marker, selection.marker)) {
      return;
    }
    final markers =
        chunk.markers
            .map(
              (candidate) =>
                  identical(candidate, selection.marker) ? marker : candidate,
            )
            .toList(growable: false)
          ..sort(comparePlacedMarkersDeterministic);
    _dispatch(context, markers: markers);
  }

  Future<void> _deleteMarker(
    BuildContext context,
    ChunkPlacedMarkerSelection selection,
  ) async {
    if (!await _confirmDelete(context, 'enemy marker')) return;
    if (!context.mounted) return;
    _dispatch(
      context,
      markers: chunk.markers
          .where((candidate) => !identical(candidate, selection.marker))
          .toList(growable: false),
    );
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

  void _dispatch(
    BuildContext context, {
    Iterable<TileLayerDef>? tileLayers,
    Iterable<PlacedPrefabDef>? prefabs,
    Iterable<PlacedMarkerDef>? markers,
  }) {
    final beforeDocument = controller.document;
    final before = ChunkV2CompositionSnapshot.fromChunk(chunk);
    controller.applyCommand(
      AuthoringCommand(
        kind: ChunkDomainPlugin.commitChunkCompositionCommandKind,
        payload: <String, Object?>{
          'chunkKey': chunk.chunkKey,
          'commit': ChunkV2CompositionCommit(
            before: before,
            after: ChunkV2CompositionSnapshot(
              tileLayers: tileLayers ?? before.tileLayers,
              prefabs: prefabs ?? before.prefabs,
              markers: markers ?? before.markers,
            ),
          ),
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
      document.prefabData.prefabs
          .where(
            (prefab) =>
                (placement.prefabKey.isNotEmpty &&
                    prefab.prefabKey == placement.prefabKey) ||
                prefab.id == placement.prefabId,
          )
          .firstOrNull
          ?.id ??
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
    expansionKey: ValueKey<String>(expansionKey),
    trailing: FilledButton.icon(
      key: ValueKey<String>(addKey),
      onPressed: onAdd,
      icon: const Icon(Icons.add),
      label: Text(addLabel),
    ),
    child: children.isEmpty
        ? Text(emptyMessage)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
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

bool _layersEqual(TileLayerDef left, TileLayerDef right) =>
    left.id == right.id &&
    left.kind == right.kind &&
    left.visible == right.visible;

bool _placementsEqual(PlacedPrefabDef left, PlacedPrefabDef right) =>
    left.prefabId == right.prefabId &&
    left.prefabKey == right.prefabKey &&
    left.x == right.x &&
    left.y == right.y &&
    left.zIndex == right.zIndex &&
    left.snapToGrid == right.snapToGrid &&
    left.scale == right.scale &&
    left.flipX == right.flipX &&
    left.flipY == right.flipY;

bool _markersEqual(PlacedMarkerDef left, PlacedMarkerDef right) =>
    left.markerId == right.markerId &&
    left.x == right.x &&
    left.y == right.y &&
    left.chancePercent == right.chancePercent &&
    left.salt == right.salt &&
    left.placement == right.placement;

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
