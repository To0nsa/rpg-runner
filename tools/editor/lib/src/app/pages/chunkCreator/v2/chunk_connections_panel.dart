import 'package:flutter/material.dart';
import 'package:runner_core/collision/terrain/terrain_boundary_signature.dart';

import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_models.dart';
import '../../../../levels/level_domain_models.dart';
import '../../shared/editor_section_card.dart';
import 'chunk_composition_preview.dart';

String chunkBoundaryLabel(TerrainBoundarySignature? boundary, LevelDef level) {
  if (boundary == null) return 'Terrain needs repair';
  if (boundary.isEmpty) return 'Open boundary';
  if (boundary.coverageIntervals.length != 1) {
    return 'Multiple terrain intervals';
  }
  final y = boundary.coverageIntervals.single.minYTicks / 1024;
  final elevation = level.elevationPresets.elevationAt(y);
  final name = elevation == null
      ? 'Custom'
      : elevation.name[0].toUpperCase() + elevation.name.substring(1);
  return '$name · Y ${y.toStringAsFixed(y == y.roundToDouble() ? 0 : 1)}';
}

/// Connection inspection reuses the Chunk inspector and captured scene data.
/// Availability here means at least one valid Flow occurrence, not every slot.
class ChunkConnectionsPanel extends StatefulWidget {
  const ChunkConnectionsPanel({
    super.key,
    required this.chunk,
    required this.scene,
    required this.level,
    required this.workspaceRootPath,
    required this.onOpen,
    this.returnChunkKey,
    this.onReturn,
    required this.onCreate,
    required this.side,
    required this.onSideChanged,
    required this.showGuides,
    required this.onGuidesChanged,
    required this.expanded,
    required this.onExpandedChanged,
  });
  final bool showGuides;
  final ValueChanged<bool> onGuidesChanged;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final ChunkV2FileData chunk;
  final ChunkV2Scene scene;
  final LevelDef level;
  final String workspaceRootPath;
  final ValueChanged<String> onOpen;
  final String? returnChunkKey;
  final VoidCallback? onReturn;
  final VoidCallback? onCreate;
  final TerrainBoundarySide side;
  final ValueChanged<TerrainBoundarySide> onSideChanged;

  @override
  State<ChunkConnectionsPanel> createState() => _ChunkConnectionsPanelState();
}

class _ChunkConnectionsPanelState extends State<ChunkConnectionsPanel> {
  String? _previewKey;

  @override
  void didUpdateWidget(covariant ChunkConnectionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chunk.chunkKey != widget.chunk.chunkKey ||
        oldWidget.side != widget.side) {
      _previewKey = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysis = widget.scene.seamAnalysis;
    final left = analysis.leftSignaturesByChunkKey[widget.chunk.chunkKey];
    final right = analysis.rightSignaturesByChunkKey[widget.chunk.chunkKey];
    final next = widget.side == TerrainBoundarySide.right;
    final current = next ? right : left;
    final matches = widget.scene.chunks.where((candidate) {
      final opposite = (next
          ? analysis.leftSignaturesByChunkKey
          : analysis.rightSignaturesByChunkKey)[candidate.chunkKey];
      return current != null &&
          opposite != null &&
          current.physicalRecord == opposite.physicalRecord &&
          candidate.status == 'active';
    }).toList()..sort((a, b) => a.chunkKey.compareTo(b.chunkKey));
    final preview = matches
        .where((chunk) => chunk.chunkKey == _previewKey)
        .firstOrNull;
    return EditorSectionCard(
      title: 'Connections',
      collapsible: true,
      expanded: widget.expanded,
      onExpansionChanged: widget.onExpandedChanged,
      description:
          '${chunkBoundaryLabel(left, widget.level)} → ${chunkBoundaryLabel(right, widget.level)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.returnChunkKey != null)
            TextButton.icon(
              onPressed: widget.onReturn,
              icon: const Icon(Icons.arrow_back),
              label: Text('Return to ${widget.returnChunkKey}'),
            ),
          Text('Entrance elevation: ${chunkBoundaryLabel(left, widget.level)}'),
          Text('Exit elevation: ${chunkBoundaryLabel(right, widget.level)}'),
          const SizedBox(height: 8),
          FilterChip(
            label: const Text('Ground heights'),
            selected: widget.showGuides,
            onSelected: widget.onGuidesChanged,
          ),
          SegmentedButton<TerrainBoundarySide>(
            segments: const [
              ButtonSegment(
                value: TerrainBoundarySide.left,
                label: Text('Previous'),
              ),
              ButtonSegment(
                value: TerrainBoundarySide.right,
                label: Text('Next'),
              ),
            ],
            selected: {widget.side},
            onSelectionChanged: (values) => widget.onSideChanged(values.single),
          ),
          const SizedBox(height: 8),
          Text('${matches.length} terrain matches'),
          const Text(
            'Flow availability means the connection can appear in at least one valid position.',
          ),
          if (matches.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No matching chunk yet. Create a successor or use the boundary profile to draw one.',
              ),
            ),
          if (matches.isNotEmpty)
            DropdownButtonFormField<String>(
              key: ValueKey(
                '${widget.chunk.chunkKey}:${widget.side}:$_previewKey',
              ),
              initialValue: preview?.chunkKey,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Preview matching chunk',
              ),
              items: [
                for (final candidate in matches)
                  DropdownMenuItem(
                    value: candidate.chunkKey,
                    child: Text(
                      candidate.chunkKey,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _previewKey = value),
            ),
          if (preview != null) ...[
            Text(
              '${preview.assemblyGroupId} · ${preview.difficulty} difficulty',
            ),
            Text(_availability(preview)),
            ChunkConnectionPreview(
              left: next ? widget.chunk : preview,
              right: next ? preview : widget.chunk,
              scene: widget.scene,
              workspaceRootPath: widget.workspaceRootPath,
              fadeRight: next,
            ),
            TextButton.icon(
              onPressed: () => widget.onOpen(preview.chunkKey),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open chunk'),
            ),
          ],
          OutlinedButton.icon(
            key: const ValueKey('create_connecting_chunk'),
            onPressed: widget.onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create connecting chunk'),
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Boundary profile'),
            children: [
              if (current == null)
                const Text('Compile valid terrain to inspect this edge.'),
              if (current != null) ...[
                for (final interval in current.coverageIntervals)
                  Text(
                    '${interval.collisionMode.name}: Y ${interval.minYTicks / 1024} to ${interval.maxYTicks / 1024}',
                  ),
                for (final point in current.continuationVertices)
                  Text(
                    '${point.surfaceKind ?? 'surface'} at Y ${point.yTicks / 1024} (${point.collisionMode.name})',
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _availability(ChunkV2FileData candidate) {
    final next = widget.side == TerrainBoundarySide.right;
    final contexts = widget.scene.seamAnalysis.transitions
        .where(
          (transition) =>
              transition.leftChunkKey ==
                  (next ? widget.chunk.chunkKey : candidate.chunkKey) &&
              transition.rightChunkKey ==
                  (next ? candidate.chunkKey : widget.chunk.chunkKey),
        )
        .map((transition) => transition.description)
        .toSet();
    final reasons = widget.scene.seamAnalysis.schedules[widget.level.levelId]
        ?.transitionExclusions(
          next ? widget.chunk.chunkKey : candidate.chunkKey,
          next ? candidate.chunkKey : widget.chunk.chunkKey,
        );
    return contexts.isEmpty
        ? 'Excluded from current Flow: ${reasons?.join('; ') ?? 'repair the Flow diagnostics to admit a continuing schedule'}.'
        : 'Available in Flow: ${contexts.join('; ')}.';
  }
}

/// Two authored compositions at one scale, sharing their exact vertical seam.
class ChunkConnectionPreview extends StatelessWidget {
  const ChunkConnectionPreview({
    super.key,
    required this.left,
    required this.right,
    required this.scene,
    required this.workspaceRootPath,
    this.fadeRight = true,
  });
  final ChunkV2FileData left;
  final ChunkV2FileData right;
  final ChunkV2Scene scene;
  final String workspaceRootPath;
  final bool fadeRight;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: (left.width + right.width) / left.height,
    child: Stack(
      children: [
        Row(
          children: [
            for (final chunk in [left, right])
              Expanded(
                flex: chunk.width,
                child: Opacity(
                  opacity: identical(chunk, fadeRight ? right : left) ? .65 : 1,
                  child: ChunkCompositionPreview.joined(
                    workspaceRootPath: workspaceRootPath,
                    chunk: chunk,
                    prefabData: scene.prefabData,
                    tileData: scene.tileData,
                    visualBoundsByPrefabKey: scene.visualBoundsByPrefabKey,
                    parallaxTheme: scene.activeParallaxTheme,
                  ),
                ),
              ),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                width: 1,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
