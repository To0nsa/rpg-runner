import 'package:flutter/material.dart';
import 'package:runner_core/combat/ai_target_policy.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/encounters/encounter_limits.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';

import '../../../../chunks/chunk_encounter_edit.dart';
import '../../../../domain/authoring_types.dart';
import '../../shared/terrain_polygon_exact_edit_controller.dart';
import 'chunk_npc_catalog_browser.dart';

String encounterPolicyLabel(AiTargetPolicy policy) => switch (policy) {
  AiTargetPolicy.playerOnly => 'Player only',
  AiTargetPolicy.preferEncounterNpcs => 'Prefer encounter NPCs',
  AiTargetPolicy.nearestOpponent => 'Nearest opponent',
};

/// One local form buffer, accepted through the same Save/Discard controller as
/// terrain and trap inspectors. The workspace retains its captured revision.
class ChunkEncounterInspector extends StatefulWidget {
  const ChunkEncounterInspector({
    super.key,
    required this.group,
    required this.member,
    required this.editController,
    required this.enabled,
    required this.onApply,
    required this.onCancel,
    required this.onDuplicate,
    required this.onDelete,
    this.issues = const [],
  });
  final EncounterDefinition group;
  final EncounterParticipant? member;
  final TerrainPolygonExactEditController editController;
  final bool enabled;
  final String? Function(EncounterDefinition) onApply;
  final VoidCallback onCancel, onDuplicate, onDelete;
  final List<ValidationIssue> issues;
  @override
  State<ChunkEncounterInspector> createState() =>
      _ChunkEncounterInspectorState();
}

class _ChunkEncounterInspectorState extends State<ChunkEncounterInspector> {
  final _fields = <String, TextEditingController>{};
  bool _dirty = false;
  String? _error;
  late bool _defaultPoints;
  late AiTargetPolicy _policy;
  late String _memberPolicy;
  late Facing _facing;
  late SpawnPlacementMode _placement;
  NpcId? _npc;
  EnemyId? _enemy;
  Object? _baseline;
  Object get _signature => (
    _fields['name']!.text,
    _fields['trigger_x']!.text,
    _fields['trigger_y']!.text,
    _fields['trigger_width']!.text,
    _fields['trigger_height']!.text,
    _defaultPoints,
    _defaultPoints ? '' : _fields['points']!.text,
    _fields['member_x']!.text,
    _policy,
    _memberPolicy,
    _facing,
    _placement,
    _npc,
    _enemy,
  );

  @override
  void initState() {
    super.initState();
    _reset();
    widget.editController.attach(
      this,
      hasChanges: () => _dirty,
      save: _save,
      discard: _discard,
    );
  }

  void _reset() {
    final g = widget.group;
    final m = widget.member;
    final values = {
      'name': g.name,
      'trigger_x': '${g.trigger.x.toInt()}',
      'trigger_y': '${g.trigger.y.toInt()}',
      'trigger_width': '${g.trigger.width.toInt()}',
      'trigger_height': '${g.trigger.height.toInt()}',
      'points': '${g.pointsPerNpc ?? EncounterLimits.defaultPointsPerNpc}',
      'member_x': '${m?.x.toInt() ?? 0}',
    };
    for (final entry in values.entries) {
      (_fields[entry.key] ??= TextEditingController()).text = entry.value;
    }
    _defaultPoints = g.pointsPerNpc == null;
    _policy = g.targetPolicy;
    _facing = m?.facing ?? Facing.right;
    _placement = m?.placement ?? SpawnPlacementMode.ground;
    _npc = m is EncounterNpcPlacement ? m.npcId : null;
    _enemy = m is EncounterEnemyPlacement ? m.enemyId : null;
    _memberPolicy = m is EncounterEnemyPlacement
        ? m.targetPolicy?.name ?? 'inherit'
        : 'inherit';
    _dirty = false;
    _error = null;
    _baseline = _signature;
  }

  void _discard() {
    setState(_reset);
    widget.editController.markChanged();
  }

  void _changed() {
    setState(() => _dirty = _signature != _baseline);
    widget.editController.markChanged();
  }

  int _int(String key) {
    final result = int.tryParse(_fields[key]!.text.trim());
    if (result == null) {
      throw ArgumentError(
        'Enter a whole number for ${key.replaceAll('_', ' ')}.',
      );
    }
    return result;
  }

  bool _save() {
    if (!widget.enabled) return false;
    if (!_dirty) return true;
    try {
      final m = widget.member;
      final candidate = m == null
          ? editEncounter(
              widget.group,
              name: _fields['name']!.text.trim(),
              targetPolicy: _policy,
              useDefaultPoints: _defaultPoints,
              pointsPerNpc: _defaultPoints ? null : _int('points'),
              trigger: EncounterTrigger(
                x: _int('trigger_x').toDouble(),
                y: _int('trigger_y').toDouble(),
                width: _int('trigger_width').toDouble(),
                height: _int('trigger_height').toDouble(),
              ),
            )
          : replaceEncounterMember(widget.group, switch (m) {
              EncounterNpcPlacement() => editEncounterNpc(
                m,
                npcId: _npc,
                x: _int('member_x').toDouble(),
                facing: _facing,
                placement: _placement,
              ),
              EncounterEnemyPlacement() => editEncounterEnemy(
                m,
                enemyId: _enemy,
                x: _int('member_x').toDouble(),
                facing: _facing,
                placement: _placement,
                useEncounterPolicy: _memberPolicy == 'inherit',
                targetPolicy: _memberPolicy == 'inherit'
                    ? null
                    : AiTargetPolicy.values.byName(_memberPolicy),
              ),
            });
      final error = widget.onApply(candidate);
      if (error != null) {
        setState(() => _error = error);
        return false;
      }
      _dirty = false;
      widget.editController.markChanged();
      return true;
    } on ArgumentError catch (e) {
      setState(() => _error = e.message.toString());
      return false;
    }
  }

  @override
  void dispose() {
    widget.editController.detach(this);
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String key,
    String label, {
    bool numeric = true,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      key: ValueKey('chunk_encounter_$key'),
      controller: _fields[key],
      enabled: widget.enabled && enabled,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(signed: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => _changed(),
    ),
  );
  Widget _choice<T>(
    String key,
    String label,
    T value,
    Iterable<T> values,
    String Function(T) name,
    ValueChanged<T> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<T>(
      key: ValueKey(('chunk_encounter_$key', value)),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in values)
          DropdownMenuItem(value: item, child: Text(name(item))),
      ],
      onChanged: widget.enabled
          ? (v) {
              if (v != null) {
                changed(v);
                _changed();
              }
            }
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final m = widget.member;
    final effectivePoints = _defaultPoints
        ? EncounterLimits.defaultPointsPerNpc
        : int.tryParse(_fields['points']!.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          m == null ? 'Rescue encounter' : 'Participant ${m.id}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        if (m == null) ...[
          _field('name', 'Display name', numeric: false),
          const Text(
            'NPC movement bounds: this entire chunk. Terrain controls vertical movement.',
          ),
          const SizedBox(height: 8),
          const Text('Activation trigger (independent of movement bounds)'),
          Row(
            children: [
              Expanded(child: _field('trigger_x', 'X')),
              const SizedBox(width: 8),
              Expanded(child: _field('trigger_y', 'Y')),
            ],
          ),
          Row(
            children: [
              Expanded(child: _field('trigger_width', 'Width')),
              const SizedBox(width: 8),
              Expanded(child: _field('trigger_height', 'Height')),
            ],
          ),
          _choice(
            'policy',
            'Enemy targeting',
            _policy,
            AiTargetPolicy.values,
            encounterPolicyLabel,
            (v) => _policy = v,
          ),
          SwitchListTile(
            key: const ValueKey('chunk_encounter_default_points'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Use default (${EncounterLimits.defaultPointsPerNpc} per survivor)',
            ),
            value: _defaultPoints,
            onChanged: widget.enabled
                ? (v) {
                    _defaultPoints = v;
                    _changed();
                  }
                : null,
          ),
          _field(
            'points',
            'Points per survivor (0–${EncounterLimits.maxPointsPerNpc})',
            enabled: !_defaultPoints,
          ),
          Text(
            'Maximum rescue bonus: ${effectivePoints == null ? '—' : effectivePoints * g.npcs.length} points',
          ),
          const Text(
            'Awarded for survivors after all required enemies are defeated and the player has dealt damage.',
          ),
        ] else ...[
          if (m is EncounterNpcPlacement)
            _choice(
              'npc_type',
              'NPC type',
              _npc!,
              NpcId.values,
              npcDisplayName,
              (v) => _npc = v,
            ),
          if (m is EncounterEnemyPlacement)
            _choice(
              'enemy_type',
              'Enemy type',
              _enemy!,
              EnemyId.values,
              (id) => id.name,
              (v) => _enemy = v,
            ),
          _field('member_x', 'Chunk-local X (px)'),
          _choice(
            'facing',
            'Facing',
            _facing,
            Facing.values,
            (v) => v.name,
            (v) => _facing = v,
          ),
          _choice(
            'support',
            'Placement support',
            _placement,
            SpawnPlacementMode.values,
            (v) => v.name,
            (v) => _placement = v,
          ),
          if (m is EncounterEnemyPlacement) ...[
            _choice(
              'member_policy',
              'Targeting override',
              _memberPolicy,
              ['inherit', ...AiTargetPolicy.values.map((v) => v.name)],
              (v) => v == 'inherit'
                  ? 'Use encounter setting'
                  : encounterPolicyLabel(AiTargetPolicy.values.byName(v)),
              (v) => _memberPolicy = v,
            ),
            Text(
              'Effective: ${encounterPolicyLabel(_memberPolicy == 'inherit' ? g.targetPolicy : AiTargetPolicy.values.byName(_memberPolicy))}',
            ),
          ] else
            const Text(
              'Allied NPCs use faction targeting; ambient hostiles can damage active NPCs.',
            ),
        ],
        for (final issue in widget.issues)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${issue.fieldKey ?? 'Encounter'}: ${issue.message}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              key: const ValueKey('chunk_encounter_apply'),
              onPressed: widget.enabled ? _save : null,
              child: const Text('Save changes'),
            ),
            TextButton(
              onPressed: widget.enabled ? widget.onCancel : null,
              child: const Text('Discard'),
            ),
            OutlinedButton(
              key: const ValueKey('chunk_encounter_duplicate'),
              onPressed: widget.enabled ? widget.onDuplicate : null,
              child: const Text('Duplicate'),
            ),
            OutlinedButton(
              key: const ValueKey('chunk_encounter_delete'),
              onPressed: widget.enabled ? widget.onDelete : null,
              child: Text(
                m == null
                    ? 'Delete group (${g.npcs.length + g.enemies.length})'
                    : 'Delete participant',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
