import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_core/ecs/stores/restoration_item_store.dart';
import 'package:runner_core/interactions/world_interaction_catalog.dart';
import 'package:runner_core/interactions/world_interaction_placement.dart';
import 'package:tool_ui/tool_ui.dart';

import '../../../campaign/campaign_marker_edit.dart';
import '../../../chunks/chunk_domain_models.dart';
import '../../../chunks/chunk_encounter_edit.dart';
import '../../../chunks/chunk_marker_authoring_catalog.dart';
import '../chunkCreator/v2/chunk_encounter_inspector.dart';
import '../chunkCreator/v2/chunk_trap_inline_inspector.dart';
import '../chunkCreator/v2/chunk_v2_composition_forms.dart';
import 'campaign_marker_editing.dart';
import 'campaign_marker_painter.dart';

/// Reuses existing typed chunk inspectors for enemies, traps and rescue rosters.
/// Only point pickups and surface-attached fire need new property controls.
class CampaignMarkerInspector extends StatelessWidget {
  const CampaignMarkerInspector({super.key, required this.editing});
  final CampaignMarkerEditing editing;
  @override
  Widget build(BuildContext context) {
    final e = editing, entry = editing.selected;
    return ToolSectionCard(
      title: 'Marker properties',
      child: entry == null
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Choose a marker in the level or list to edit its properties.',
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  campaignMarkerLabel(entry),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('Occurrence: ${entry.position.occurrenceId}'),
                if (entry.placement case final CampaignEnemySource p)
                  DropdownButtonFormField<String>(
                    key: ValueKey((p.id, p.marker.enemyId)),
                    initialValue: p.marker.enemyId.name,
                    decoration: const InputDecoration(labelText: 'Enemy type'),
                    isExpanded: true,
                    items: [
                      for (final enemy in chunkMarkerEnemyCatalog)
                        DropdownMenuItem(
                          value: enemy.enemyId.name,
                          child: Text(enemy.displayName),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) _property('enemyId', v);
                    },
                  ),
                if (entry.placement case CampaignPickupSource(:final resource?))
                  DropdownButtonFormField<RestorationStat>(
                    key: ValueKey((entry.key, resource)),
                    initialValue: resource,
                    decoration: const InputDecoration(
                      labelText: 'Restoration resource',
                    ),
                    items: [
                      for (final stat in RestorationStat.values)
                        DropdownMenuItem(value: stat, child: Text(stat.name)),
                    ],
                    onChanged: (v) {
                      if (v != null) _property('resource', v.name);
                    },
                  ),
                if (entry.placement case final CampaignEnemySource p)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Required for completion'),
                    value: p.required,
                    onChanged: (v) => _required(v),
                  ),
                if (entry.placement case final CampaignRescueSource p) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Required rescue'),
                    value: p.required,
                    onChanged: (v) => _required(v),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => e.addRescueMember(npc: true),
                        child: const Text('Add NPC'),
                      ),
                      OutlinedButton(
                        onPressed: () => e.addRescueMember(npc: false),
                        child: const Text('Add enemy'),
                      ),
                    ],
                  ),
                  ListTile(
                    dense: true,
                    title: const Text('Encounter region'),
                    selected: e.memberId == null,
                    onTap: () => e.select(entry.key),
                  ),
                  for (final member in [
                    ...p.encounter.npcs,
                    ...p.encounter.enemies,
                  ])
                    ListTile(
                      dense: true,
                      title: Text(member.id),
                      selected: e.memberId == member.id,
                      onTap: () => e.select(entry.key, participant: member.id),
                    ),
                ],
                const SizedBox(height: 12),
                _form(entry),
                if (e.error != null)
                  Text(
                    e.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
    );
  }

  void _required(bool value) {
    _property('required', value);
  }

  void _property(String field, Object value) {
    final e = editing;
    if (!e.finishDraft()) return;
    final entry = e.selected!;
    final json = entry.placement!.toJson()..[field] = value;
    final p = decodeCampaignPlacements([json]).single;
    e.commit(entry, CampaignMarkerEntry(entry.key, p.position, placement: p));
  }

  Widget _form(CampaignMarkerEntry entry) {
    final e = editing, p = entry.placement;
    final expected = e.mission;
    final key = ValueKey((entry.key, e.mission.revision, e.memberId));
    String? apply(CampaignPlacementSource p) => e.commit(
      entry,
      CampaignMarkerEntry(entry.key, p.position, placement: p),
      expected: expected,
    );
    if (p is CampaignTrapSource) {
      return ChunkTrapInlineInspector(
        key: key,
        source: p.trap,
        editController: e.exact,
        onApply: (trap) =>
            apply(CampaignTrapSource(p.id, p.occurrenceId, trap)),
        onCancel: e.cancel,
        onDuplicate: e.duplicate,
        onDelete: e.delete,
        onFrame: (v) {
          e.trapFrame = v;
          e.changed();
        },
        frame: e.trapFrame,
        snapControls: const SizedBox.shrink(),
        enabled: !e.gestureActive,
        canDuplicate: true,
      );
    }
    if (p is CampaignEnemySource) {
      final occurrence = e.mission.route.firstWhere(
        (o) => o.id == p.occurrenceId,
      );
      final chunk = e.document.chunks.chunks.firstWhere(
        (c) => c.chunkKey == occurrence.chunkKey,
      );
      return ChunkV2MarkerForm(
        key: key,
        chunk: chunk,
        enemyId: p.marker.enemyId.name,
        marker: PlacedMarkerDef(
          markerId: p.marker.enemyId.name,
          x: p.position.x.round(),
          y: p.position.y.round(),
          chancePercent: p.marker.chancePercent,
          salt: p.marker.salt,
          placement: p.marker.placement.name,
        ),
        editController: e.exact,
        submitKey: 'campaign_enemy_apply',
        submitLabel: 'Update enemy',
        fieldKeyPrefix: 'campaign_enemy',
        enabled: !e.gestureActive,
        onCancel: e.cancel,
        onSubmit: (marker) {
          final json = p.toJson()
            ..['position'] = {
              'occurrenceId': p.occurrenceId,
              'x': marker.x,
              'y': marker.y,
            }
            ..['chancePercent'] = marker.chancePercent
            ..['salt'] = marker.salt
            ..['placement'] = marker.placement;
          final error = apply(decodeCampaignPlacements([json]).single);
          if (error != null) throw StateError(error);
        },
      );
    }
    if (p is CampaignRescueSource) {
      final member = e.memberId == null
          ? null
          : findEncounterMember(p.encounter, e.memberId!);
      return ChunkEncounterInspector(
        key: key,
        group: p.encounter,
        member: member,
        editController: e.exact,
        enabled: !e.gestureActive,
        onApply: (group) => apply(
          CampaignRescueSource(
            p.id,
            p.occurrenceId,
            group,
            required: p.required,
          ),
        ),
        onCancel: e.cancel,
        onDuplicate: member == null
            ? e.duplicate
            : () => e.changeRescueMember(member.id, duplicate: true),
        onDelete: member == null
            ? e.delete
            : () => e.changeRescueMember(member.id, duplicate: false),
      );
    }
    return _PointInspector(key: key, editing: e, entry: entry);
  }
}

class _PointInspector extends StatefulWidget {
  const _PointInspector({
    super.key,
    required this.editing,
    required this.entry,
  });
  final CampaignMarkerEditing editing;
  final CampaignMarkerEntry entry;
  @override
  State<_PointInspector> createState() => _PointInspectorState();
}

class _PointInspectorState extends State<_PointInspector> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  late final CampaignMissionSource _expected;
  late String _occurrence;
  late WorldInteractionAppearanceId _appearance;
  bool _dirty = false;
  bool _resetting = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _expected = widget.editing.mission;
    _reset();
    widget.editing.exact.attach(
      this,
      hasChanges: () => _dirty,
      save: () => !_dirty || _save(),
      discard: () {
        _reset();
        setState(() {});
      },
    );
  }

  void _reset() {
    _resetting = true;
    final entry = widget.entry, shrine = widget.entry.placement;
    _occurrence = entry.position.occurrenceId;
    _appearance = shrine is CampaignShrineSource
        ? shrine.appearance
        : WorldInteractionAppearanceId.emberFlame;
    final values = <String, double>{
      'x': entry.position.x,
      'y': entry.position.y,
      if (entry.region != null) 'width': entry.region!.width,
      if (entry.region != null) 'height': entry.region!.height,
      if (shrine is CampaignShrineSource)
        'activationWidth': shrine.activationWidth,
      if (shrine is CampaignShrineSource) 'scale': shrine.scale,
    };
    for (final v in values.entries) {
      _fields.putIfAbsent(v.key, TextEditingController.new).text = '${v.value}';
    }
    _dirty = false;
    _error = null;
    _resetting = false;
  }

  @override
  void dispose() {
    widget.editing.exact.detach(this);
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() {
    if (_resetting) return;
    _dirty = true;
    widget.editing.exact.markChanged();
  }

  bool _save() {
    if (!(_form.currentState?.validate() ?? false)) return false;
    try {
      double number(String key) => double.parse(_fields[key]!.text);
      final e = widget.editing, before = widget.entry;
      final point = CampaignPoint(
        occurrenceId: _occurrence,
        x: number('x'),
        y: number('y'),
      );
      var after = before.region != null
          ? CampaignMarkerEntry(
              before.key,
              point,
              region: CampaignRegion(
                origin: point,
                width: number('width'),
                height: number('height'),
              ),
            )
          : e.move(before, point);
      if (after.placement case final CampaignShrineSource p) {
        final shrine = CampaignShrineSource(
          p.id,
          p.position,
          prefabKey: p.prefabKey,
          placementKey: p.placementKey,
          shapeId: p.shapeId,
          appearance: _appearance,
          activationWidth: number('activationWidth'),
          scale: number('scale'),
        );
        final occurrence = e.mission.route.firstWhere(
          (o) => o.id == _occurrence,
        );
        resolveWorldInteractionSurface(
          shrine.bindingFor(occurrence.chunkKey),
          e.compiled[occurrence.chunkKey]!.stagedTerrain,
        );
        after = CampaignMarkerEntry(
          before.key,
          shrine.position,
          placement: shrine,
        );
      }
      final error = e.commit(before, after, expected: _expected);
      if (error != null) throw StateError(error);
      _dirty = false;
      return true;
    } on Object catch (error) {
      setState(() => _error = '$error');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    onChanged: _changed,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _occurrence,
          decoration: const InputDecoration(labelText: 'Occurrence'),
          items: [
            for (final o in widget.editing.mission.route)
              DropdownMenuItem(
                value: o.id,
                child: Text(o.id, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v != null) {
              _occurrence = v;
              _changed();
            }
          },
        ),
        for (final field in _fields.entries)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextFormField(
              key: ValueKey('campaign_marker_${field.key}'),
              controller: field.value,
              decoration: InputDecoration(
                labelText: switch (field.key) {
                  'activationWidth' => 'Activation width',
                  'scale' => 'Fire scale',
                  _ => field.key,
                },
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) => double.tryParse(v ?? '')?.isFinite == true
                  ? null
                  : 'Enter a finite number.',
            ),
          ),
        if (widget.entry.placement is CampaignShrineSource) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<WorldInteractionAppearanceId>(
            initialValue: _appearance,
            decoration: const InputDecoration(labelText: 'Fire appearance'),
            items: const [
              DropdownMenuItem(
                value: WorldInteractionAppearanceId.emberFlame,
                child: Text('Ember fire'),
              ),
              DropdownMenuItem(
                value: WorldInteractionAppearanceId.blueFlame,
                child: Text('Blue fire'),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                _appearance = v;
                _changed();
              }
            },
          ),
          const Text(
            'Attaches to the selected flat top. Moving the marker reattaches it; the underlying platform stays unchanged.',
          ),
        ],
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('campaign_marker_apply'),
          onPressed: _save,
          child: const Text('Update marker'),
        ),
        OutlinedButton(
          onPressed: () {
            _reset();
            setState(() {});
          },
          child: const Text('Discard field edits'),
        ),
      ],
    ),
  );
}
