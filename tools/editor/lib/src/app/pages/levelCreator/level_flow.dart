import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/authoring_types.dart';

import 'package:runner_core/track/chunk_pattern_source.dart';

import '../../../chunks/chunk_domain_models.dart';
import '../../../chunks/chunk_v2_file_data.dart';
import '../../../levels/level_domain_models.dart';

/// Composes ordered sections with group, difficulty, length, and pool coverage.
/// Sampling and play admission remain owned by Core.
class LevelFlow extends StatefulWidget {
  const LevelFlow({
    super.key,
    required this.level,
    this.connectionIssues,
    this.onInspectConnection,
    this.onCreateConnection,
    required this.chunks,
    required this.segments,
    required this.selectedSegmentId,
    required this.loopSegments,
    required this.onModeChanged,
    required this.onSelected,
    required this.onAdd,
    required this.onReorder,
    required this.onLoopChanged,
    required this.previewForGroup,
  });

  final LevelDef level;
  final List<ValidationIssue>? connectionIssues;
  final ValueChanged<ValidationIssue>? onInspectConnection;
  final ValueChanged<ValidationIssue>? onCreateConnection;
  final List<ChunkV2FileData> chunks;
  final List<LevelAssemblySegmentDef> segments;
  final String? selectedSegmentId;
  final bool loopSegments;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<bool> onLoopChanged;
  final Widget Function(String groupId) previewForGroup;

  @override
  State<LevelFlow> createState() => _LevelFlowState();
}

class _LevelFlowState extends State<LevelFlow> {
  final _scrollController = ScrollController();
  final _sectionKeys = <String, GlobalKey>{};
  int _revealGeneration = 0;

  @override
  void initState() {
    super.initState();
    _syncSectionKeys();
  }

  void _syncSectionKeys() {
    final ids = widget.segments.map((section) => section.segmentId).toSet();
    _sectionKeys.removeWhere((id, _) => !ids.contains(id));
    for (final id in ids) {
      _sectionKeys.putIfAbsent(id, GlobalKey.new);
    }
  }

  @override
  void didUpdateWidget(covariant LevelFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSectionKeys();
    final selectedId = widget.selectedSegmentId;
    if (oldWidget.level.levelId != widget.level.levelId ||
        oldWidget.selectedSegmentId != selectedId) {
      _revealGeneration++;
      return;
    }
    final oldIndex = oldWidget.segments.indexWhere(
      (section) => section.segmentId == selectedId,
    );
    final newIndex = widget.segments.indexWhere(
      (section) => section.segmentId == selectedId,
    );
    if (selectedId == null ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex == newIndex) {
      return;
    }
    final generation = ++_revealGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_revealSection(selectedId, generation));
    });
  }

  Future<void> _revealSection(String id, int generation) async {
    while (mounted &&
        generation == _revealGeneration &&
        _scrollController.hasClients) {
      final target = _sectionKeys[id]?.currentContext?.findRenderObject();
      final position = _scrollController.position;
      if (target != null && target.attached) {
        await position.ensureVisible(
          target,
          alignment: .5,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeInOut,
        );
        return;
      }
      // Lazy rows have no render object until scrolling brings them into range.
      final targetIndex = widget.segments.indexWhere(
        (section) => section.segmentId == id,
      );
      if (targetIndex < 0 || position.viewportDimension <= 0) return;
      final firstMountedIndex = widget.segments.indexWhere(
        (section) => _sectionKeys[section.segmentId]?.currentContext != null,
      );
      final direction = firstMountedIndex < 0
          ? (position.extentAfter == 0 ? -1 : 1)
          : (targetIndex < firstMountedIndex ? -1 : 1);
      final offset = (position.pixels + direction * position.viewportDimension)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if (offset == position.pixels) return;
      await _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeInOut,
      );
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordered = widget.segments.isNotEmpty;
    final header = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Automatic')),
              ButtonSegment(value: true, label: Text('Ordered sections')),
            ],
            selected: {ordered},
            onSelectionChanged: (values) => widget.onModeChanged(values.single),
          ),
          const SizedBox(height: 12),
          Text(
            ordered
                ? 'Compose the level from top to bottom. Add sections, choose their group, difficulty and length, then drag them into order. Select a section to edit or duplicate it.'
                : 'The level selects eligible chunks as difficulty advances. Group filters do not restrict this pool.',
          ),
          const SizedBox(height: 12),
          Text(
            widget.connectionIssues == null
                ? 'Connections: loading terrain'
                : !widget.connectionIssues!.any(
                    (issue) => issue.blocks(AuthoringOperation.play),
                  )
                ? 'Connections: valid continuation through the complete Flow'
                : 'Connections need repair',
          ),
          for (final issue
              in widget.connectionIssues ?? <ValidationIssue>[]) ...[
            Text(
              issue.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: widget.onInspectConnection == null
                  ? null
                  : () => widget.onInspectConnection!(issue),
              child: const Text('Inspect connection'),
            ),
            if (widget.onCreateConnection != null &&
                issue.sourcePath?.contains('/chunks/') == true)
              TextButton.icon(
                onPressed: () => widget.onCreateConnection!(issue),
                icon: const Icon(Icons.add),
                label: const Text('Create connecting chunk'),
              ),
          ],
          const SizedBox(height: 12),
          Text(
            'Difficulty coverage',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          for (final tier in ChunkPatternTier.values) _coverageRow(tier),
          const SizedBox(height: 8),
          Text(
            'No enemies for the first ${widget.level.noEnemyChunks} chunks. Terrain hazards are unchanged.',
          ),
        ],
      ),
    );
    if (!ordered) return ListView(children: [header]);
    return ReorderableListView.builder(
      key: const PageStorageKey<String>('level_flow_scroll'),
      scrollController: _scrollController,
      buildDefaultDragHandles: false,
      header: header,
      itemCount: widget.segments.length,
      onReorderItem: widget.onReorder,
      itemBuilder: (context, index) {
        final segment = widget.segments[index];
        final matchingCount = widget.chunks
            .where(
              (chunk) =>
                  chunk.status == chunkStatusActive &&
                  chunk.assemblyGroupId == segment.groupId &&
                  (segment.difficulty == null ||
                      chunk.difficulty == segment.difficulty!.name),
            )
            .map((chunk) => chunk.chunkKey)
            .toSet()
            .length;
        final requiredCount = segment.requireDistinctChunks
            ? segment.maxChunkCount
            : 1;
        final fixedPosition = widget.segments
            .take(index + 1)
            .every((s) => s.minChunkCount == s.maxChunkCount);
        final start =
            1 +
            widget.segments
                .take(index)
                .fold(0, (sum, s) => sum + s.minChunkCount);
        final length = segment.minChunkCount == segment.maxChunkCount
            ? '${segment.minChunkCount}'
            : '${segment.minChunkCount}–${segment.maxChunkCount}';
        return Card.outlined(
          key: ValueKey<String>('level_section_${segment.segmentId}'),
          color: widget.selectedSegmentId == segment.segmentId
              ? Theme.of(context).colorScheme.primaryContainer
                    .withValues(alpha: .25)
              : null,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: ListTile(
            key: _sectionKeys[segment.segmentId],
            onTap: () => widget.onSelected(index),
            leading: SizedBox(
              width: 80,
              height: 52,
              child: widget.previewForGroup(segment.groupId),
            ),
            title: Text(
              '${index + 1}. ${segment.groupId} · ${segment.difficulty?.name ?? 'Automatic'}',
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.connectionIssues == null
                      ? 'Connections: awaiting terrain'
                      : widget.connectionIssues!.any(
                          (issue) => issue.blocks(AuthoringOperation.play),
                        )
                      ? 'Connections: complete Flow needs repair'
                      : 'Connections: valid through this section and its continuation',
                ),
                Text(
                  '${fixedPosition ? 'Chunks $start–${start + segment.maxChunkCount - 1} · ' : ''}$length chunks · ${segment.requireDistinctChunks ? 'Each chunk once per section' : 'Repeats allowed'}',
                ),
                Text(
                  '$matchingCount matching active chunks${matchingCount < requiredCount ? '; needs $requiredCount' : ''}',
                  style: matchingCount < requiredCount
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
              ],
            ),
            trailing: ReorderableDragStartListener(
              index: index,
              child: const Tooltip(
                message: 'Drag to reorder; Move earlier/later is available in settings',
                child: Icon(Icons.drag_handle),
              ),
            ),
          ),
        );
      },
      footer: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: widget.onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add section'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<bool>(
              key: ValueKey<bool>(widget.loopSegments),
              initialValue: widget.loopSegments,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'After the last section',
              ),
              items: const [
                DropdownMenuItem(
                  value: true,
                  child: Text('Repeat all sections'),
                ),
                DropdownMenuItem(
                  value: false,
                  child: Text('Continue the last section'),
                ),
              ],
              onChanged: (value) {
                if (value != null) widget.onLoopChanged(value);
              },
            ),
            const SizedBox(height: 6),
            const Text(
              'Both choices keep the run going. Each repeated section keeps its chosen difficulty and starts a fresh no-repeat selection. The background stays the same.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverageRow(ChunkPatternTier tier) {
    final active = widget.chunks
        .where((chunk) => chunk.status == chunkStatusActive)
        .toList(growable: false);
    final direct = active
        .where((chunk) => chunk.difficulty == tier.name)
        .length;
    final fallback = fallbackOrderForTier(tier)
        .where(
          (candidate) =>
              active.any((chunk) => chunk.difficulty == candidate.name),
        )
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        direct > 0
            ? '${tier.name}: $direct authored chunk${direct == 1 ? '' : 's'}'
            : fallback == null
            ? '${tier.name}: no usable chunks'
            : '${tier.name}: falls back to ${fallback.name}',
      ),
    );
  }
}
