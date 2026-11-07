import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';

import '../../app/ui_routes.dart';
import '../../components/app_button.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../components/player_idle_preview.dart';
import '../../state/app/app_state.dart';
import '../../theme/ui_tokens.dart';

/// Chooses the character before opening its independently remembered build.
class CharacterSelectionPage extends StatefulWidget {
  const CharacterSelectionPage({super.key});
  @override
  State<CharacterSelectionPage> createState() => _CharacterSelectionPageState();
}

class _CharacterSelectionPageState extends State<CharacterSelectionPage> {
  PlayerCharacterId? _opening;
  String? _error;

  Future<void> _open(PlayerCharacterId id) async {
    if (_opening != null) return;
    setState(() {
      _opening = id;
      _error = null;
    });
    try {
      await context.read<AppState>().setCharacter(id);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(UiRoutes.setupLoadout);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _opening = null;
        _error = 'Could not select this character. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final selected = context.watch<AppState>().selection.selectedCharacterId;
    return MenuScaffold(
      title: 'Choose your character',
      child: MenuLayout(
        maxWidth: 900,
        child: Column(
          children: [
            Text(
              'Choose a fighting style, then shape your build.',
              style: ui.text.body.copyWith(color: ui.colors.textMuted),
            ),
            SizedBox(height: ui.space.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth < 560
                    ? constraints.maxWidth
                    : (constraints.maxWidth - ui.space.md) / 2;
                return Wrap(
                  spacing: ui.space.md,
                  runSpacing: ui.space.md,
                  children: [
                    for (final character in PlayerCharacterRegistry.playable)
                      SizedBox(
                        width: width,
                        child: _CharacterCard(
                          character: character,
                          selected: selected == character.id,
                          busy: _opening == character.id,
                          enabled: _opening == null,
                          onBuild: () => _open(character.id),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (_error != null)
              Padding(
                padding: EdgeInsets.all(ui.space.sm),
                child: Text(
                  _error!,
                  style: ui.text.body.copyWith(color: ui.colors.danger),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.character,
    required this.selected,
    required this.busy,
    required this.enabled,
    required this.onBuild,
  });
  final PlayerCharacterDefinition character;
  final bool selected, busy, enabled;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final hunter = character.id == PlayerCharacterId.bountyHunter;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ui.colors.cardBackground,
        borderRadius: BorderRadius.circular(ui.radii.lg),
        border: Border.all(
          color: selected ? ui.colors.accentStrong : ui.colors.outline,
          width: selected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(ui.space.md),
        child: Column(
          children: [
            SizedBox(
              height: 20,
              child: Text(
                selected ? 'CURRENT CHARACTER' : '',
                style: ui.text.label.copyWith(color: ui.colors.accentStrong),
              ),
            ),
            Transform.translate(
              offset: Offset(0, hunter ? -28 : 0),
              child: Transform.scale(
                scale: hunter ? 1.4 : 1,
                child: PlayerIdlePreview(characterId: character.id, size: 120),
              ),
            ),
            Text(character.displayName, style: ui.text.title),
            SizedBox(height: ui.space.xs),
            Text(
              hunter ? 'Guns · Bombs · Fieldcraft' : 'Sword · Shield · Spells',
              textAlign: TextAlign.center,
              style: ui.text.label.copyWith(color: ui.colors.accentStrong),
            ),
            SizedBox(height: ui.space.sm),
            Text(
              hunter
                  ? 'Pick a gun, control space with bombs, and stay mobile. Bombs recharge without consuming Supplies.'
                  : 'Combine sword attacks, active shield defense and adaptable magic.',
              textAlign: TextAlign.center,
              style: ui.text.body.copyWith(color: ui.colors.textMuted),
            ),
            SizedBox(height: ui.space.md),
            SizedBox(
              width: 220,
              child: AppButton(
                label: busy ? 'Opening…' : 'Build ${character.displayName}',
                onPressed: enabled ? onBuild : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
