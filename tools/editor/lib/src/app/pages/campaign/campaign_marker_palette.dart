import 'package:flutter/material.dart';
import 'package:tool_ui/tool_ui.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/interactions/world_interaction_catalog.dart';
import 'package:runner_core/traps/trap_id.dart';

import '../chunkCreator/v2/chunk_enemy_catalog_browser.dart';
import '../chunkCreator/v2/chunk_trap_panel.dart';
import 'campaign_marker_editing.dart';
import 'campaign_marker_painter.dart';
import 'campaign_marker_inspector.dart';

class CampaignMarkerPalette extends StatelessWidget {
  const CampaignMarkerPalette({
    super.key,
    required this.editing,
    required this.onLinkTarget,
    this.onPlace,
  });
  final CampaignMarkerEditing editing;
  final VoidCallback onLinkTarget;
  final VoidCallback? onPlace;

  @override
  Widget build(BuildContext context) {
    final e = editing;
    return SingleChildScrollView(
      key: const PageStorageKey('campaign_markers_scroll'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ToolSectionCard(
            title: 'Marker library',
            collapsible: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final brush in CampaignMarkerBrush.values)
                      ChoiceChip(
                        key: ValueKey('campaign_brush_${brush.name}'),
                        label: Text(_label(brush)),
                        avatar: Icon(_icon(brush), size: 18),
                        selected:
                            e.brush == brush &&
                            e.tool == CampaignMarkerTool.place,
                        onSelected: (_) {
                          if (e.choose(brush)) onPlace?.call();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (e.brush == CampaignMarkerBrush.enemy ||
                    e.brush == CampaignMarkerBrush.rescue)
                  ChunkEnemyCatalogBrowser(
                    workspaceRootPath: e.session.workspacePath,
                    selectedEnemyId: e.enemy.name,
                    usedEnemyIds: e.mission.placements
                        .whereType<CampaignEnemySource>()
                        .map((p) => p.marker.enemyId.name),
                    gridHeight: 272,
                    keyPrefix: 'campaign_enemy_catalog',
                    onSelected: (id) {
                      if (!e.choose(e.brush)) return;
                      e.enemy = EnemyId.values.byName(id);
                      e.changed();
                      onPlace?.call();
                    },
                  ),
                if (e.brush == CampaignMarkerBrush.trap)
                  DropdownButtonFormField<TrapId>(
                    key: ValueKey(e.trap),
                    initialValue: e.trap,
                    decoration: const InputDecoration(labelText: 'Trap type'),
                    items: [
                      for (final id in TrapId.values)
                        DropdownMenuItem(
                          value: id,
                          child: Text(trapDisplayName(id)),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        e.trap = v;
                        e.changed();
                      }
                    },
                  ),
                if (e.brush == CampaignMarkerBrush.shrine)
                  DropdownButtonFormField<WorldInteractionAppearanceId>(
                    key: ValueKey(e.appearance),
                    initialValue: e.appearance,
                    decoration: const InputDecoration(
                      labelText: 'Fire appearance',
                    ),
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
                        e.appearance = v;
                        e.changed();
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CampaignMarkerInspector(editing: e),
          const SizedBox(height: 12),
          ToolSectionCard(
            title: 'Placed markers',
            collapsible: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${e.entries.length} mission markers',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final entry in e.entries)
                  ListTile(
                    dense: true,
                    selected: entry.key == e.selectedKey,
                    title: Text(campaignMarkerLabel(entry)),
                    subtitle: Text(
                      '${entry.position.occurrenceId} · ${entry.position.x}, ${entry.position.y}',
                    ),
                    onTap: () => e.select(entry.key),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ToolSectionCard(
            title: 'Shared chunk objectives',
            collapsible: true,
            initiallyExpanded: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Shared chunk enemies, traps and rescues remain inherited. Edit their shared source from Route.',
                ),
                OutlinedButton.icon(
                  onPressed: e.mission.route.isEmpty ? null : onLinkTarget,
                  icon: const Icon(Icons.link),
                  label: const Text('Link a shared enemy / rescue objective'),
                ),
                for (final (index, target) in e.mission.requiredEnemies.indexed)
                  ListTile(
                    dense: true,
                    title: Text('Defeat enemy ${target.markerSalt}'),
                    subtitle: Text(target.occurrenceId),
                    trailing: IconButton(
                      tooltip: 'Unlink objective',
                      icon: const Icon(Icons.link_off),
                      onPressed: () => _unlink('requiredEnemies', index),
                    ),
                  ),
                for (final (index, target) in e.mission.requiredRescues.indexed)
                  ListTile(
                    dense: true,
                    title: Text('Rescue ${target.encounterId}'),
                    subtitle: Text(target.occurrenceId),
                    trailing: IconButton(
                      tooltip: 'Unlink objective',
                      icon: const Icon(Icons.link_off),
                      onPressed: () => _unlink('requiredRescues', index),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _unlink(String field, int index) {
    if (!editing.finishDraft()) return;
    final json = editing.mission.toJson();
    (json[field] as List).removeAt(index);
    editing.apply(json);
  }
}

String _label(CampaignMarkerBrush brush) => switch (brush) {
  CampaignMarkerBrush.gold => 'Gold coin',
  CampaignMarkerBrush.health => 'Health gem',
  CampaignMarkerBrush.mana => 'Mana gem',
  CampaignMarkerBrush.stamina => 'Stamina gem',
  CampaignMarkerBrush.shrine => 'Blessing fire',
  CampaignMarkerBrush.enemy => 'Enemy',
  CampaignMarkerBrush.trap => 'Trap',
  CampaignMarkerBrush.rescue => 'Rescue',
  CampaignMarkerBrush.start => 'Start',
  CampaignMarkerBrush.exit => 'Exit',
  CampaignMarkerBrush.visit => 'Visit region',
};
IconData _icon(CampaignMarkerBrush brush) => switch (brush) {
  CampaignMarkerBrush.gold => Icons.monetization_on_outlined,
  CampaignMarkerBrush.health ||
  CampaignMarkerBrush.mana ||
  CampaignMarkerBrush.stamina => Icons.diamond_outlined,
  CampaignMarkerBrush.shrine => Icons.local_fire_department_outlined,
  CampaignMarkerBrush.enemy => Icons.person_search_outlined,
  CampaignMarkerBrush.trap => Icons.warning_amber,
  CampaignMarkerBrush.rescue => Icons.groups_outlined,
  CampaignMarkerBrush.start => Icons.play_arrow,
  _ => Icons.flag_outlined,
};
