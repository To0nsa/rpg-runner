import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';

import '../../../campaign/campaign_domain_plugin.dart';

class CampaignMissionSettingsDialog extends StatefulWidget {
  const CampaignMissionSettingsDialog({super.key, required this.document});
  final CampaignDocument document;
  @override
  State<CampaignMissionSettingsDialog> createState() =>
      _CampaignMissionSettingsDialogState();
}

class _CampaignMissionSettingsDialogState
    extends State<CampaignMissionSettingsDialog> {
  final form = GlobalKey<FormState>();
  late final data = widget.document.selected.toJson();
  late final title = Map<String, String>.of(widget.document.selected.title);
  late final description = Map<String, String>.of(
    widget.document.selected.description,
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mission settings'),
    content: SizedBox(
      width: 580,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final lang in ['en', 'fr']) ...[
                TextFormField(
                  initialValue: title[lang],
                  decoration: InputDecoration(labelText: 'Title ($lang)'),
                  maxLength: 120,
                  validator: _required,
                  onSaved: (v) => title[lang] = v!.trim(),
                ),
                TextFormField(
                  initialValue: description[lang],
                  decoration: InputDecoration(labelText: 'Assignment ($lang)'),
                  maxLines: 3,
                  maxLength: 2000,
                  validator: _required,
                  onSaved: (v) => description[lang] = v!.trim(),
                ),
              ],
              DropdownButtonFormField<String>(
                initialValue: data['levelId'] as String,
                decoration: const InputDecoration(labelText: 'Region level'),
                items: [
                  for (final l in widget.document.chunks.levels)
                    DropdownMenuItem(
                      value: l.levelId,
                      child: Text(l.displayName),
                    ),
                ],
                onChanged: (v) => data['levelId'] = v,
              ),
              DropdownButtonFormField<String>(
                initialValue: data['visualThemeId'] as String,
                decoration: const InputDecoration(
                  labelText: 'Background theme',
                ),
                items: [
                  for (final t in widget.document.chunks.parallaxThemes)
                    DropdownMenuItem(
                      value: t.parallaxThemeId,
                      child: Text(t.parallaxThemeId),
                    ),
                ],
                onChanged: (v) => data['visualThemeId'] = v,
              ),
              TextFormField(
                initialValue: '${data['firstClearXp']}',
                decoration: const InputDecoration(labelText: 'First-clear XP'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 0 || n > 100000
                      ? 'Enter 0–100000.'
                      : null;
                },
                onSaved: (v) => data['firstClearXp'] = int.parse(v!),
              ),
              DropdownButtonFormField<String>(
                initialValue: data['rewardAbilityId'] as String? ?? '',
                decoration: const InputDecoration(
                  labelText: 'First-clear ability',
                  helperText: 'Unlocks once on successful completion.',
                ),
                items: const [
                  DropdownMenuItem(value: '', child: Text('None')),
                  DropdownMenuItem(
                    value: 'eloise.double_jump',
                    child: Text('Éloïse — Double Jump'),
                  ),
                ],
                onChanged: (v) =>
                    data['rewardAbilityId'] = v == null || v.isEmpty ? null : v,
              ),
              SwitchListTile(
                title: const Text('Allow combat content'),
                value: data['combatAllowed'] as bool,
                onChanged: (v) => setState(() => data['combatAllowed'] = v),
              ),
              SwitchListTile(
                title: const Text('Include in game Build'),
                subtitle: const Text(
                  'Incomplete drafts can be saved. Included missions must pass Build validation.',
                ),
                value: data['includeInBuild'] as bool,
                onChanged: (v) => setState(() => data['includeInBuild'] = v),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          form.currentState!.save();
          data['title'] = title;
          data['description'] = description;
          Navigator.pop(context, CampaignMissionSource.decode(data));
        },
        child: const Text('Apply'),
      ),
    ],
  );
}

String? _required(String? v) =>
    v == null || v.trim().isEmpty ? 'Required.' : null;

/// Returns a record even when clearing the reward, so Cancel remains distinct
/// from applying None. The page commits through the campaign plugin.
class CampaignChapterRewardsDialog extends StatefulWidget {
  const CampaignChapterRewardsDialog({super.key, required this.chapter});
  final CampaignChapterSource chapter;

  @override
  State<CampaignChapterRewardsDialog> createState() =>
      _CampaignChapterRewardsDialogState();
}

class _CampaignChapterRewardsDialogState
    extends State<CampaignChapterRewardsDialog> {
  late String reward = widget.chapter.rewardCharacterId ?? '';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Chapter rewards'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chapter.title['en']!),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: reward,
              decoration: const InputDecoration(
                labelText: 'Completion character',
                helperText:
                    'Unlocks after completing every mission in this chapter. '
                    'None grants no character unlock.',
                helperMaxLines: 3,
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('None')),
                DropdownMenuItem(value: 'bountyHunter', child: Text('Willow')),
              ],
              onChanged: (v) => reward = v ?? '',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (
          characterId: reward.isEmpty ? null : reward,
        )),
        child: const Text('Apply'),
      ),
    ],
  );
}

/// Point/region and target editing uses typed fields, never raw JSON. Target
/// choices come from the compiled source marker identities used by simulation.
class CampaignMarkerDialog extends StatefulWidget {
  const CampaignMarkerDialog({
    super.key,
    required this.mission,
    required this.chunks,
  });
  final CampaignMissionSource mission;
  final Map<String, PolygonTerrainRuntimeChunk> chunks;
  @override
  State<CampaignMarkerDialog> createState() => _CampaignMarkerDialogState();
}

class _CampaignMarkerDialogState extends State<CampaignMarkerDialog> {
  final form = GlobalKey<FormState>();
  late String occurrence = widget.mission.route.first.id;
  String kind = 'start';
  double x = 60, y = 224, width = 100, height = 270;
  int? salt;
  String? encounter;
  @override
  Widget build(BuildContext context) {
    final source = widget.mission.route.firstWhere((o) => o.id == occurrence);
    final chunk = widget.chunks[source.chunkKey];
    final enemies =
        chunk?.pattern.spawnMarkers
            .where((m) => m.chancePercent == 100)
            .toList() ??
        [];
    final rescues = chunk?.pattern.encounters ?? [];
    final target = kind == 'requiredEnemies' || kind == 'requiredRescues';
    final region = kind == 'exit' || kind == 'requiredRegions';
    return AlertDialog(
      title: const Text('Mission marker'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Purpose'),
                  items: const [
                    DropdownMenuItem(
                      value: 'start',
                      child: Text('Player start (support point)'),
                    ),
                    DropdownMenuItem(
                      value: 'exit',
                      child: Text('Mission exit region'),
                    ),
                    DropdownMenuItem(
                      value: 'collectibles',
                      child: Text('Gold pickup'),
                    ),
                    DropdownMenuItem(
                      value: 'requiredRegions',
                      child: Text('Required visit region'),
                    ),
                    DropdownMenuItem(
                      value: 'requiredEnemies',
                      child: Text('Required enemy defeat'),
                    ),
                    DropdownMenuItem(
                      value: 'requiredRescues',
                      child: Text('Required rescue'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        kind = v;
                        y = region ? 0 : 224;
                        salt = null;
                        encounter = null;
                      });
                    }
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: occurrence,
                  decoration: const InputDecoration(
                    labelText: 'Route occurrence',
                  ),
                  items: [
                    for (final o in widget.mission.route)
                      DropdownMenuItem(
                        value: o.id,
                        child: Text('${o.id} · ${o.chunkKey}'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        occurrence = v;
                        salt = null;
                        encounter = null;
                      });
                    }
                  },
                ),
                if (kind == 'requiredEnemies')
                  DropdownButtonFormField<int>(
                    key: ValueKey('enemy_$occurrence'),
                    decoration: const InputDecoration(
                      labelText: 'Guaranteed enemy',
                    ),
                    items: [
                      for (final e in enemies)
                        DropdownMenuItem(
                          value: e.salt,
                          child: Text(
                            '${e.enemyId.name} · x ${e.x} · ${e.salt}',
                          ),
                        ),
                    ],
                    validator: (v) => v == null
                        ? 'Select a guaranteed marker; edit the chunk if none exist.'
                        : null,
                    onChanged: (v) => salt = v,
                  ),
                if (kind == 'requiredRescues')
                  DropdownButtonFormField<String>(
                    key: ValueKey('rescue_$occurrence'),
                    decoration: const InputDecoration(
                      labelText: 'Rescue encounter',
                    ),
                    items: [
                      for (final e in rescues)
                        DropdownMenuItem(value: e.id, child: Text(e.id)),
                    ],
                    validator: (v) =>
                        v == null ? 'Select a rescue encounter.' : null,
                    onChanged: (v) => encounter = v,
                  ),
                if (!target) ...[
                  _number('X', x, 0, 599.5, (v) => x = v),
                  _number('Y', region ? 0 : y, 0, 270, (v) => y = v),
                  if (region) ...[
                    _number('Width', width, 0.5, 600, (v) => width = v),
                    _number('Height', height, 0.5, 270, (v) => height = v),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!form.currentState!.validate()) return;
            form.currentState!.save();
            final point = {'occurrenceId': occurrence, 'x': x, 'y': y};
            final Object value = kind == 'requiredEnemies'
                ? {'occurrenceId': occurrence, 'markerSalt': salt}
                : kind == 'requiredRescues'
                ? {'occurrenceId': occurrence, 'encounterId': encounter}
                : region
                ? {'origin': point, 'width': width, 'height': height}
                : point;
            try {
              if (!target) {
                if (region) {
                  campaignRegionFromJson(value);
                } else {
                  campaignPointFromJson(value);
                }
              }
            } on FormatException catch (e) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(e.message)));
              return;
            }
            Navigator.pop(context, (kind: kind, value: value));
          },
          child: const Text('Place marker'),
        ),
      ],
    );
  }

  Widget _number(
    String name,
    double initial,
    double min,
    double max,
    void Function(double) save,
  ) => TextFormField(
    key: ValueKey('$kind$name'),
    initialValue: '$initial',
    decoration: InputDecoration(labelText: name),
    validator: (v) {
      final n = double.tryParse(v ?? '');
      return n == null || !n.isFinite || n < min || n > max
          ? 'Enter $min–$max.'
          : null;
    },
    onSaved: (v) => save(double.parse(v!)),
  );
}
