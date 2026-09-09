import 'package:flutter/material.dart';

import '../../../chunks/chunk_v2_file_data.dart';
import '../../../levels/level_domain_models.dart';
import '../shared/editor_panel_card.dart';

/// Contextual settings use coordinator-owned buffers so switching the visible
/// panel never creates another editable document or drops unfinished input.
class LevelInspector extends StatelessWidget {
  const LevelInspector({
    super.key,
    required this.level,
    required this.inputs,
    required this.focusNodes,
    required this.errors,
    required this.groups,
    required this.onCompleted,
    required this.onShowLevel,
    required this.onGroupChanged,
    required this.onDistinctChanged,
    required this.onRemoveSection,
    required this.onIncludeInBuildChanged,
    this.chunk,
    this.segment,
    this.onEarlier,
    this.onLater,
    this.onEditChunk,
    this.onAssignChunk,
    this.revealedFieldKey,
  });

  final LevelDef level;
  final ChunkV2FileData? chunk;
  final LevelAssemblySegmentDef? segment;
  final Map<String, TextEditingController> inputs;
  final Map<String, FocusNode> focusNodes;
  final Map<String, String> errors;
  final List<String> groups;
  final VoidCallback onCompleted;
  final VoidCallback onShowLevel;
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<bool> onDistinctChanged;
  final VoidCallback onRemoveSection;
  final ValueChanged<bool> onIncludeInBuildChanged;
  final VoidCallback? onEarlier;
  final VoidCallback? onLater;
  final VoidCallback? onEditChunk;
  final VoidCallback? onAssignChunk;
  final String? revealedFieldKey;

  @override
  Widget build(BuildContext context) => EditorPanelCard(
    title: segment != null
        ? 'Section settings'
        : chunk != null
        ? 'Chunk settings'
        : 'Level settings',
    bodyMode: EditorPanelBodyMode.expanded,
    trailing: segment != null || chunk != null
        ? IconButton(
            tooltip: 'Show level settings',
            onPressed: onShowLevel,
            icon: const Icon(Icons.tune),
          )
        : null,
    child: ListView(
      key: const PageStorageKey<String>('level_settings_scroll'),
      children: segment != null
          ? _sectionFields()
          : chunk != null
          ? _chunkFields(context)
          : _levelFields(context),
    ),
  );

  List<Widget> _levelFields(BuildContext context) => [
    _field('displayName', 'Display name'),
    SwitchListTile(
      key: const ValueKey<String>('level_include_in_build'),
      contentPadding: EdgeInsets.zero,
      value: level.includeInBuild,
      title: const Text('Include in Build'),
      subtitle: const Text('Include this level in generated game content.'),
      onChanged: onIncludeInBuildChanged,
    ),
    const SizedBox(height: 16),
    Text(
      'Difficulty over the run',
      style: Theme.of(context).textTheme.titleSmall,
    ),
    const SizedBox(height: 6),
    const Text(
      'Consecutive stages, measured in chunks. Sections do not reset progression.',
    ),
    _field('earlyPatternChunks', 'Early', numeric: true),
    _field('easyPatternChunks', 'Easy', numeric: true),
    _field('normalPatternChunks', 'Normal', numeric: true),
    const ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('Hard'),
      subtitle: Text('Continues indefinitely'),
    ),
    _field(
      'noEnemyChunks',
      'Enemy-free opening',
      numeric: true,
      helper: 'No enemies for the first N chunks. Other hazards remain.',
    ),
    ExpansionTile(
      key: ValueKey('level_advanced_settings_$revealedFieldKey'),
      initiallyExpanded: const [
        'cameraCenterY',
        'groundTopY',
        'enumOrdinal',
      ].contains(revealedFieldKey),
      tilePadding: EdgeInsets.zero,
      title: const Text('Advanced'),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Level ID'),
          subtitle: SelectableText(level.levelId),
        ),
        _field('cameraCenterY', 'Camera center', readOnly: true),
        _field('groundTopY', 'Ground reference', readOnly: true),
        _field('enumOrdinal', 'Enum ordinal', readOnly: true),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Revision ${level.revision}'),
          subtitle: Text(level.status),
        ),
      ],
    ),
  ];

  List<Widget> _sectionFields() => [
    DropdownButtonFormField<String>(
      focusNode: focusNodes['groupId'],
      key: ValueKey<String>(
        'level_section_group_${segment!.segmentId}_${segment!.groupId}',
      ),
      initialValue: groups.contains(segment!.groupId) ? segment!.groupId : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Chunk group',
        errorText: errors['groupId'],
      ),
      items: [
        for (final group in groups)
          DropdownMenuItem(value: group, child: Text(group)),
      ],
      onChanged: (value) {
        if (value != null) onGroupChanged(value);
      },
    ),
    _field(
      'minChunkCount',
      'At least',
      numeric: true,
      helper: 'Number of chunks in this section.',
    ),
    _field('maxChunkCount', 'At most', numeric: true),
    Focus(
      focusNode: focusNodes['requireDistinctChunks'],
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: segment!.requireDistinctChunks,
        title: const Text('Use each chunk at most once in this section'),
        onChanged: (value) {
          if (value != null) onDistinctChanged(value);
        },
      ),
    ),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: onEarlier,
          icon: const Icon(Icons.arrow_upward),
          label: const Text('Move earlier'),
        ),
        OutlinedButton.icon(
          onPressed: onLater,
          icon: const Icon(Icons.arrow_downward),
          label: const Text('Move later'),
        ),
        TextButton.icon(
          onPressed: onRemoveSection,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Remove section'),
        ),
      ],
    ),
    ExpansionTile(
      key: ValueKey('section_advanced_$revealedFieldKey'),
      initiallyExpanded: revealedFieldKey == 'segmentId',
      title: const Text('Advanced'),
      tilePadding: EdgeInsets.zero,
      children: [_field('segmentId', 'Section ID')],
    ),
  ];

  List<Widget> _chunkFields(BuildContext context) => [
    Text(chunk!.chunkKey, style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    Text('${chunk!.difficulty} · ${chunk!.assemblyGroupId} · ${chunk!.status}'),
    const SizedBox(height: 8),
    Text(
      '${chunk!.collisionShapes.length} terrain shapes · ${chunk!.prefabs.length} objects · ${chunk!.markers.length} enemies',
    ),
    const SizedBox(height: 12),
    const Text(
      'This is a reusable chunk source. Editing it changes every occurrence selected from it.',
    ),
    const SizedBox(height: 12),
    FilledButton.tonalIcon(
      onPressed: onEditChunk,
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Edit chunk'),
    ),
    const SizedBox(height: 8),
    OutlinedButton(onPressed: onAssignChunk, child: const Text('Assign group')),
    const SizedBox(height: 8),
    const Text(
      'A chunk belongs to one group. Reassigning it removes it from its previous group.',
    ),
  ];

  Widget _field(
    String key,
    String label, {
    bool numeric = false,
    bool readOnly = false,
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      key: ValueKey<String>('level_input_$key'),
      controller: inputs[key],
      focusNode: focusNodes[key],
      readOnly: readOnly,
      keyboardType: numeric ? TextInputType.number : null,
      onSubmitted: (_) => onCompleted(),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        errorText: errors[key],
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: readOnly ? const Icon(Icons.lock_outline, size: 18) : null,
      ),
    ),
  );
}
