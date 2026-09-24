import 'package:flutter/material.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/encounters/encounter_limits.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';

import '../../../../chunks/chunk_encounter_edit.dart';
import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_marker_authoring_catalog.dart';
import '../../shared/editor_list_card.dart';
import '../../shared/editor_section_card.dart';
import 'chunk_encounter_gesture.dart';
import 'chunk_enemy_catalog_browser.dart';
import 'chunk_npc_catalog_browser.dart';

/// Bounded encounter presentation; the workspace owns guards and all commands.
class ChunkEncounterPanel extends StatelessWidget {
  const ChunkEncounterPanel({
    super.key,
    required this.groups,
    required this.selected,
    required this.workspaceRootPath,
    required this.nameController,
    required this.enabled,
    required this.gesture,
    required this.onCreate,
    required this.onSelect,
    required this.onTool,
    required this.onNpc,
    required this.onEnemy,
    required this.onFacing,
    required this.onPlacement,
    required this.editor,
    required this.snapControls,
    required this.ambientEnemies,
    required this.onConvert,
    this.error,
  });
  final List<EncounterDefinition> groups;
  final ChunkEncounterSelection? selected;
  final String workspaceRootPath;
  final TextEditingController nameController;
  final bool enabled;
  final ChunkEncounterGesture gesture;
  final VoidCallback onCreate;
  final ValueChanged<ChunkEncounterSelection> onSelect;
  final ValueChanged<ChunkEncounterTool> onTool;
  final ValueChanged<NpcId> onNpc;
  final ValueChanged<EnemyId> onEnemy;
  final ValueChanged<Facing> onFacing;
  final ValueChanged<SpawnPlacementMode> onPlacement;
  final Widget? editor;
  final Widget snapControls;
  final List<ChunkPlacedMarkerSelection> ambientEnemies;
  final ValueChanged<String> onConvert;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final group = selected == null
        ? null
        : findChunkEncounter(groups, selected!.encounterId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorSectionCard(
          title: 'Create encounter',
          collapsible: true,
          description: 'Rescue · one complete group in this chunk',
          child: Column(
            children: [
              TextField(
                key: const ValueKey('chunk_encounter_create_name'),
                controller: nameController,
                enabled: enabled,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const ValueKey('chunk_encounter_create'),
                onPressed:
                    enabled &&
                        groups.length < EncounterLimits.maxEncountersPerChunk
                    ? onCreate
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Create rescue encounter'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        EditorSectionCard(
          title:
              'Encounters (${groups.length}/${EncounterLimits.maxEncountersPerChunk})',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (groups.isEmpty)
                const Text(
                  'Create an encounter, then place its NPCs and enemies.',
                ),
              for (final entry in groups) ...[
                EditorListCard(
                  key: ValueKey('chunk_encounter_group_${entry.id}'),
                  isSelected: selected == ChunkEncounterSelection(entry.id),
                  onTap: enabled
                      ? () => onSelect(ChunkEncounterSelection(entry.id))
                      : null,
                  leading: const Icon(Icons.groups_outlined),
                  child: Text(
                    '${entry.name} · ${entry.npcs.length} NPCs / ${entry.enemies.length} enemies',
                  ),
                ),
                if (selected?.encounterId == entry.id)
                  for (final member in [...entry.npcs, ...entry.enemies])
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: EditorListCard(
                        key: ValueKey(
                          'chunk_encounter_member_${entry.id}_${member.id}',
                        ),
                        isSelected: selected?.memberId == member.id,
                        onTap: enabled
                            ? () => onSelect(
                                ChunkEncounterSelection(
                                  entry.id,
                                  memberId: member.id,
                                ),
                              )
                            : null,
                        leading: Icon(
                          member is EncounterNpcPlacement
                              ? Icons.person_outline
                              : Icons.dangerous_outlined,
                        ),
                        child: Text(
                          '${member.id} · ${switch (member) {
                            EncounterNpcPlacement(:final npcId) => npcDisplayName(npcId),
                            EncounterEnemyPlacement(:final enemyId) => chunkMarkerEnemyCatalogEntryFor(enemyId.name)!.displayName,
                          }}',
                        ),
                      ),
                    ),
              ],
              if (editor != null) ...[const Divider(), editor!],
            ],
          ),
        ),
        if (group != null) ...[
          const SizedBox(height: 12),
          EditorSectionCard(
            title: 'Add participants',
            collapsible: true,
            description: 'Choose a card, then use Place and click the scene. Y follows terrain support.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChunkNpcCatalogBrowser(
                  workspaceRootPath: workspaceRootPath,
                  selected: gesture.npcId,
                  onSelected: onNpc,
                  enabled: enabled,
                ),
                FilledButton(
                  key: const ValueKey('chunk_encounter_place_npc'),
                  onPressed:
                      enabled &&
                          group.npcs.length <
                              EncounterLimits.maxNpcsPerEncounter
                      ? () => onTool(ChunkEncounterTool.placeNpc)
                      : null,
                  child: Text('Place ${npcDisplayName(gesture.npcId)}'),
                ),
                const SizedBox(height: 12),
                ChunkEnemyCatalogBrowser(
                  workspaceRootPath: workspaceRootPath,
                  selectedEnemyId: gesture.enemyId.name,
                  usedEnemyIds: group.enemies.map((e) => e.enemyId.name),
                  onSelected: (id) => onEnemy(EnemyId.values.byName(id)),
                  enabled: enabled,
                  keyPrefix: 'chunk_encounter_enemy_catalog',
                ),
                FilledButton(
                  key: const ValueKey('chunk_encounter_place_enemy'),
                  onPressed:
                      enabled &&
                          group.enemies.length <
                              EncounterLimits.maxEnemiesPerEncounter
                      ? () => onTool(ChunkEncounterTool.placeEnemy)
                      : null,
                  child: const Text('Place enemy'),
                ),
                DropdownButtonFormField<Facing>(
                  key: ValueKey((
                    'chunk_encounter_create_facing',
                    gesture.facing,
                  )),
                  initialValue: gesture.facing,
                  decoration: const InputDecoration(
                    labelText: 'Placement facing',
                  ),
                  items: [
                    for (final v in Facing.values)
                      DropdownMenuItem(value: v, child: Text(v.name)),
                  ],
                  onChanged: enabled
                      ? (v) {
                          if (v != null) onFacing(v);
                        }
                      : null,
                ),
                DropdownButtonFormField<SpawnPlacementMode>(
                  key: ValueKey((
                    'chunk_encounter_create_support',
                    gesture.placement,
                  )),
                  initialValue: gesture.placement,
                  decoration: const InputDecoration(
                    labelText: 'Placement support',
                  ),
                  items: [
                    for (final v in SpawnPlacementMode.values)
                      DropdownMenuItem(value: v, child: Text(v.name)),
                  ],
                  onChanged: enabled
                      ? (v) {
                          if (v != null) onPlacement(v);
                        }
                      : null,
                ),
                snapControls,
                if (ambientEnemies.isNotEmpty) ...[
                  const Divider(),
                  const Text('Convert an existing enemy marker'),
                  const Text(
                    'Removes the ambient spawn and makes this encounter own its activation.',
                  ),
                  for (final marker in ambientEnemies)
                    TextButton(
                      key: ValueKey(
                        'chunk_encounter_convert_${marker.selectionKey}',
                      ),
                      onPressed:
                          enabled &&
                              group.enemies.length <
                                  EncounterLimits.maxEnemiesPerEncounter
                          ? () => onConvert(marker.selectionKey)
                          : null,
                      child: Text(
                        '${marker.marker.markerId} at X ${marker.marker.x}',
                      ),
                    ),
                ],
                if (gesture.tool == ChunkEncounterTool.placeNpc ||
                    gesture.tool == ChunkEncounterTool.placeEnemy)
                  TextButton(
                    onPressed: enabled
                        ? () => onTool(ChunkEncounterTool.select)
                        : null,
                    child: const Text('Cancel placement'),
                  ),
              ],
            ),
          ),
        ],
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
