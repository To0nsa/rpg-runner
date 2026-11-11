import '../../text/build_name_text.dart';

import 'package:game_presentation/character_text.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';

import 'dart:math' as math;

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
import '../../state/ownership/selection_state.dart';
import '../../theme/ui_tokens.dart';

/// Selects a character in place or opens its independently remembered build.
class CharacterSelectionPage extends StatefulWidget {
  const CharacterSelectionPage({super.key});
  @override
  State<CharacterSelectionPage> createState() => _CharacterSelectionPageState();
}

class _CharacterSelectionPageState extends State<CharacterSelectionPage> {
  bool _saving = false;
  String Function(AppLocalizations)? _error;

  Future<void> _select(PlayerCharacterId id, {int? buildIndex}) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final state = context.read<AppState>();
      if (buildIndex == null) {
        await state.setCharacter(id);
      } else {
        await state.selectBuild(id, buildIndex);
      }
      if (!mounted) return;
      if (buildIndex != null) {
        Navigator.of(context).pushNamed(UiRoutes.setupLoadout);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = (l10n) => l10n.uiCouldNotSaveThisSelectionPleaseTryAgain;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final state = context.watch<AppState>();
    final selected = state.selection.selectedCharacterId;
    return MenuScaffold(
      title: context.l10n.uiChooseYourCharacter,
      child: MenuLayout(
        maxWidth: 900,
        scrollable: false,
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: ui.space.md,
                  children: [
                    for (final character in PlayerCharacterRegistry.playable)
                      Expanded(
                        child: _CharacterCard(
                          key: ValueKey('character-card-${character.id.name}'),
                          character: character,
                          selected: selected == character.id,
                          enabled:
                              !_saving &&
                              state.isCharacterUnlocked(character.id),
                          locked: !state.isCharacterUnlocked(character.id),
                          onSelect: () => _select(character.id),
                          builds: state.selection.buildsFor(character.id),
                          isUnlocked: state.isBuildUnlocked,
                          onBuild: (index) =>
                              _select(character.id, buildIndex: index),
                        ),
                      ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: EdgeInsets.all(ui.space.sm),
                  child: Text(
                    _error!(context.l10n),
                    style: ui.text.body.copyWith(color: ui.colors.danger),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    super.key,
    required this.character,
    required this.selected,
    required this.enabled,
    required this.locked,
    required this.onSelect,
    required this.onBuild,
    required this.builds,
    required this.isUnlocked,
  });
  final PlayerCharacterDefinition character;
  final bool selected, enabled, locked;
  final VoidCallback onSelect;
  final ValueChanged<int> onBuild;
  final CharacterBuilds builds;
  final bool Function(int) isUnlocked;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final radius = BorderRadius.circular(ui.radii.lg);
    return Semantics(
      selected: selected,
      child: Material(
        color: ui.colors.cardBackground,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? ui.colors.accentStrong : ui.colors.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: enabled ? onSelect : null,
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!selected)
                IgnorePointer(
                  child: ColoredBox(
                    key: ValueKey('character-unselected-${character.id.name}'),
                    color: UiBrandPalette.unselectedCardScrim,
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(ui.space.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final preview = PlayerIdlePreview(
                                  characterId: character.id,
                                  size: math.min(
                                    180,
                                    math.min(
                                      constraints.maxWidth,
                                      constraints.maxHeight,
                                    ),
                                  ),
                                );
                                return Center(
                                  child: selected
                                      ? preview
                                      : ColorFiltered(
                                          colorFilter: const ColorFilter.mode(
                                            UiBrandPalette.unselectedCardScrim,
                                            BlendMode.srcATop,
                                          ),
                                          child: preview,
                                        ),
                                );
                              },
                            ),
                          ),
                          Text(
                            characterDisplayName(
                              character.id,
                              strings: context.gameL10n,
                            ),
                            style: ui.text.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: ui.space.sm),
                        ],
                      ),
                    ),
                    SizedBox(width: ui.space.sm),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (locked) ...[
                            const Icon(Icons.lock_outline),
                            Flexible(
                              child: Text(
                                context.l10n.campaignWillowLocked,
                                textAlign: TextAlign.center,
                                style: ui.text.cardSubtitle,
                              ),
                            ),
                          ] else
                            for (
                              var index = 0;
                              index < SelectionState.buildCount;
                              index++
                            ) ...[
                              if (index > 0) SizedBox(height: ui.space.sm),
                              _BuildButton(
                                key: ValueKey(
                                  'build-${character.id.name}-$index',
                                ),
                                name: buildDisplayName(
                                  builds.builds[index].name,
                                  index,
                                  context.l10n,
                                ),
                                selected:
                                    selected && builds.selectedIndex == index,
                                requiredLevel:
                                    SelectionState.buildUnlockLevels[index],
                                unlocked: isUnlocked(index),
                                onPressed: enabled
                                    ? () => onBuild(index)
                                    : null,
                              ),
                            ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keep locked buttons readable and consume taps without selecting the card.
class _BuildButton extends StatelessWidget {
  const _BuildButton({
    super.key,
    required this.name,
    required this.selected,
    required this.requiredLevel,
    required this.unlocked,
    required this.onPressed,
  });
  final String name;
  final bool selected, unlocked;
  final int requiredLevel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      onTap: unlocked ? onPressed : null,
      enabled: unlocked && onPressed != null,
      selected: selected,
      label: unlocked
          ? name
          : context.l10n.characterLockedSemantics(
              name: name,
              level: requiredLevel,
            ),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: unlocked ? null : () {},
          child: SizedBox(
            width: double.infinity,
            child: AppButton(
              label: unlocked
                  ? name
                  : context.l10n.requiredLevel(level: requiredLevel),
              icon: unlocked ? null : Icons.lock_outline,
              size: AppButtonSize.xs,
              variant: selected
                  ? AppButtonVariant.primary
                  : AppButtonVariant.secondary,
              onPressed: unlocked ? onPressed : null,
            ),
          ),
        ),
      ),
    );
  }
}
