import 'package:flutter/material.dart';

import '../shared/game_asset_bundle.dart';

import 'package:game_presentation/catalog_gift.dart';
import 'package:game_presentation/catalog_gift_picker.dart';
import 'package:game_presentation/catalog_item.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/players/player_character_definition.dart';

/// The dialog owns a cancellable draft; only the plugin commits source changes.
class CampaignRewardsDialog extends StatefulWidget {
  const CampaignRewardsDialog.chapter({
    super.key,
    required CampaignChapterSource chapter,
  }) : chapter = chapter,
       mission = null;
  const CampaignRewardsDialog.mission({
    super.key,
    required CampaignMissionSource mission,
  }) : mission = mission,
       chapter = null;
  final CampaignChapterSource? chapter;
  final CampaignMissionSource? mission;

  @override
  State<CampaignRewardsDialog> createState() => _CampaignRewardsState();
}

class _CampaignRewardsState extends State<CampaignRewardsDialog> {
  final _form = GlobalKey<FormState>();
  final _assets = EditorGameAssetBundle();
  late String _character = widget.chapter?.rewardCharacterId ?? '';
  late int _xp = widget.mission?.firstClearXp ?? widget.chapter!.rewardXp;
  late int _gold = widget.mission?.firstClearGold ?? widget.chapter!.rewardGold;
  bool get _firstClear => widget.mission != null;
  String get _prefix => _firstClear ? 'First-clear' : 'Completion';
  late final _items =
      (widget.mission?.firstClearItems ?? widget.chapter!.rewardItems)
          .map((item) => CatalogGift.fromJson(item.toJson()))
          .toList();

  Widget _amount(String label, int value, int max, ValueChanged<int> save) =>
      TextFormField(
        initialValue: '$value',
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        validator: (text) {
          final number = int.tryParse(text ?? '');
          return number == null || number < 0 || number > max
              ? 'Enter a whole number from 0 to $max.'
              : null;
        },
        onSaved: (text) => save(int.parse(text!)),
      );

  @override
  Widget build(BuildContext context) => DefaultAssetBundle(
    bundle: _assets,
    child: AlertDialog(
      title: Text(
        _firstClear ? 'First-clear mission rewards' : 'Chapter rewards',
      ),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text((widget.mission?.title ?? widget.chapter!.title)['en']!),
                Text(
                  _firstClear
                      ? 'Granted once on the first verified completion of this mission.'
                      : 'Granted once after completing every mission in this chapter.',
                ),
                const SizedBox(height: 16),
                _amount('$_prefix XP', _xp, 100000, (v) => _xp = v),
                _amount('$_prefix gold', _gold, 1000000, (v) => _gold = v),
                if (!_firstClear)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _character,
                    decoration: const InputDecoration(
                      labelText: 'Completion character',
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('None')),
                      DropdownMenuItem(
                        value: 'bountyHunter',
                        child: Text('Willow'),
                      ),
                    ],
                    onChanged: (v) => _character = v ?? '',
                  ),
                const SizedBox(height: 16),
                for (final kind in ['Skills', 'Items']) ...[
                  Text(
                    '$_prefix ${kind.toLowerCase()}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (!_items.any(
                    (gift) => (gift.item.kind == 'gear') == (kind == 'Items'),
                  ))
                    const Text('None'),
                  for (final item in _items.where(
                    (gift) => (gift.item.kind == 'gear') == (kind == 'Items'),
                  ))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: item.item.icon(size: 32),
                      title: Text(item.label(context.gameL10n)),
                      trailing: IconButton(
                        tooltip:
                            'Remove ${item.item.displayName(context.gameL10n)}',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _items.remove(item)),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
                CatalogGiftPicker(
                  catalog: GameCatalogItem.values,
                  characters: PlayerCharacterId.values
                      .map((c) => c.name)
                      .toList(),
                  selected: _items,
                  onToggle: (item) => setState(() {
                    final index = _items.indexWhere((v) => v.key == item.key);
                    if (index >= 0) {
                      _items.removeAt(index);
                    } else if (_items.length < 8) {
                      _items.add(item);
                    }
                  }),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Items unlock ownership. Already-owned rewards grant no duplicate or compensation.',
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
            if (!_form.currentState!.validate()) return;
            _form.currentState!.save();
            Navigator.pop(context, <String, Object?>{
              if (!_firstClear)
                'rewardCharacterId': _character.isEmpty ? null : _character,
              _firstClear ? 'firstClearXp' : 'rewardXp': _xp,
              _firstClear ? 'firstClearGold' : 'rewardGold': _gold,
              _firstClear ? 'firstClearItems' : 'rewardItems': _items
                  .map((item) => item.toJson())
                  .toList(),
            });
          },
          child: const Text('Apply'),
        ),
      ],
    ),
  );
}
