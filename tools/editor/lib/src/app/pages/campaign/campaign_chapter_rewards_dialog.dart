import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_presentation/catalog_gift.dart';
import 'package:game_presentation/catalog_gift_picker.dart';
import 'package:game_presentation/catalog_item.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/players/player_character_definition.dart';

/// The dialog owns a cancellable draft; only the plugin commits source changes.
class CampaignChapterRewardsDialog extends StatefulWidget {
  const CampaignChapterRewardsDialog({super.key, required this.chapter});
  final CampaignChapterSource chapter;

  @override
  State<CampaignChapterRewardsDialog> createState() => _ChapterRewardsState();
}

class _ChapterRewardsState extends State<CampaignChapterRewardsDialog> {
  final _form = GlobalKey<FormState>();
  final _assets = _GameAssets();
  late String _character = widget.chapter.rewardCharacterId ?? '';
  late int _xp = widget.chapter.rewardXp, _gold = widget.chapter.rewardGold;
  late final _items = widget.chapter.rewardItems
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
      title: const Text('Chapter rewards'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.chapter.title['en']!),
                const Text(
                  'Granted once after completing every mission in this chapter.',
                ),
                const SizedBox(height: 16),
                _amount('Completion XP', _xp, 100000, (v) => _xp = v),
                _amount('Completion gold', _gold, 1000000, (v) => _gold = v),
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
                for (final item in _items)
                  ListTile(
                    leading: item.item.icon(size: 32),
                    title: Text(item.label(context.gameL10n)),
                    trailing: IconButton(
                      tooltip:
                          'Remove ${item.item.displayName(context.gameL10n)}',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _items.remove(item)),
                    ),
                  ),
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
              'rewardCharacterId': _character.isEmpty ? null : _character,
              'rewardXp': _xp,
              'rewardGold': _gold,
              'rewardItems': _items.map((item) => item.toJson()).toList(),
            });
          },
          child: const Text('Apply'),
        ),
      ],
    ),
  );
}

/// The editor already bundles the game dependency's canonical assets. Redirect
/// the shared icons' keys to that package, without copying atlases or doing I/O.
class _GameAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(
    key.startsWith('assets/') ? 'packages/rpg_runner/$key' : key,
  );
}
