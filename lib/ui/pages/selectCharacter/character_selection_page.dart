import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_presentation/character_text.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';

import '../../app/ui_routes.dart';
import '../../components/menu_scaffold.dart';
import '../../components/player_idle_preview.dart';
import '../../l10n/app_localization.dart';
import '../../state/app/app_state.dart';
import '../../state/ownership/selection_state.dart';
import '../../text/build_name_text.dart';
import '../../theme/ui_tokens.dart';
import 'loadout_setup_page.dart';

/// Selection stays on this page; editing addresses a saved build independently.
class CharacterSelectionPage extends StatefulWidget {
  const CharacterSelectionPage({super.key});

  @override
  State<CharacterSelectionPage> createState() => _CharacterSelectionPageState();
}

class _CharacterSelectionPageState extends State<CharacterSelectionPage> {
  bool _saving = false;
  bool _failed = false;

  Future<void> _select(PlayerCharacterId id, int index) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await context.read<AppState>().selectBuild(id, index);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _edit(PlayerCharacterId id, int index) {
    Navigator.of(context).pushNamed(
      UiRoutes.setupLoadout,
      arguments: LoadoutSetupArgs(characterId: id, buildIndex: index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final app = context.watch<AppState>();
    final selection = app.selection;
    return MenuScaffold(
      title: context.l10n.uiChooseYourCharacter,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 540;
          final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final minCardHeight = 216.0 * math.max(1.0, textScale);
          final cardHeight = math.max(
            minCardHeight,
            math.min(360.0, constraints.maxHeight - 76),
          );
          final cards = [
            for (final character in PlayerCharacterRegistry.playable)
              SizedBox(
                height: cardHeight,
                child: _CharacterCard(
                  key: ValueKey('character-card-${character.id.name}'),
                  character: character,
                  selected: selection.selectedCharacterId == character.id,
                  enabled: !_saving && app.isCharacterUnlocked(character.id),
                  locked: !app.isCharacterUnlocked(character.id),
                  builds: selection.buildsFor(character.id),
                  isUnlocked: app.isBuildUnlocked,
                  onSelect: () => _select(
                    character.id,
                    selection.selectedBuildIndexFor(character.id),
                  ),
                  onBuild: (index) => _select(character.id, index),
                  onEdit: (index) => _edit(character.id, index),
                ),
              ),
          ];
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: ui.space.md,
              vertical: ui.space.xs,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (stacked)
                      Column(spacing: ui.space.sm, children: cards)
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: ui.space.sm,
                        children: [
                          for (final card in cards) Expanded(child: card),
                        ],
                      ),
                    if (_failed)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          context
                              .l10n
                              .uiCouldNotSaveThisSelectionPleaseTryAgain,
                          style: ui.text.body.copyWith(color: ui.colors.danger),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
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
    required this.builds,
    required this.isUnlocked,
    required this.onSelect,
    required this.onBuild,
    required this.onEdit,
  });

  final PlayerCharacterDefinition character;
  final bool selected, enabled, locked;
  final CharacterBuilds builds;
  final bool Function(int) isUnlocked;
  final VoidCallback onSelect;
  final ValueChanged<int> onBuild, onEdit;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final name = characterDisplayName(character.id, strings: context.gameL10n);
    return Material(
      color: ui.colors.cardBackground,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ui.radii.lg),
        side: BorderSide(
          color: selected
              ? ui.colors.accentStrong
              : ui.colors.textMuted.withValues(alpha: .35),
          width: selected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(ui.space.xs),
        child: Row(
          spacing: ui.space.xs,
          children: [
            Expanded(
              flex: 4,
              child: Semantics(
                selected: selected,
                button: true,
                enabled: enabled,
                label: context.l10n.characterSelect(name: name),
                onTap: enabled ? onSelect : null,
                child: InkWell(
                  key: ValueKey('select-character-${character.id.name}'),
                  onTap: enabled ? onSelect : null,
                  borderRadius: BorderRadius.circular(ui.radii.md),
                  excludeFromSemantics: true,
                  child: ExcludeSemantics(
                    child: Column(
                      children: [
                        Text(
                          name,
                          style: ui.text.title,
                          textAlign: TextAlign.center,
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final preview = PlayerIdlePreview(
                                characterId: character.id,
                                size: math.max(
                                  0,
                                  math.min(
                                    180,
                                    math.min(
                                      constraints.maxWidth,
                                      constraints.maxHeight,
                                    ),
                                  ),
                                ),
                              );
                              return Center(
                                child: locked
                                    ? Opacity(opacity: .45, child: preview)
                                    : preview,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: locked
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline),
                        SizedBox(height: ui.space.xs),
                        Text(
                          context.l10n.campaignWillowLocked,
                          textAlign: TextAlign.center,
                          style: ui.text.body,
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: ui.space.xxs,
                      children: [
                        for (
                          var index = 0;
                          index < SelectionState.buildCount;
                          index++
                        )
                          _BuildRow(
                            key: ValueKey('build-${character.id.name}-$index'),
                            name: buildDisplayName(
                              builds.builds[index].name,
                              index,
                              context.l10n,
                            ),
                            characterName: name,
                            selected: selected && builds.selectedIndex == index,
                            unlocked: isUnlocked(index),
                            requiredLevel:
                                SelectionState.buildUnlockLevels[index],
                            onSelect: enabled ? () => onBuild(index) : null,
                            onEdit: enabled ? () => onEdit(index) : null,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildRow extends StatelessWidget {
  const _BuildRow({
    super.key,
    required this.name,
    required this.characterName,
    required this.selected,
    required this.unlocked,
    required this.requiredLevel,
    required this.onSelect,
    required this.onEdit,
  });
  final String name, characterName;
  final bool selected, unlocked;
  final int requiredLevel;
  final VoidCallback? onSelect, onEdit;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final border = selected
        ? ui.colors.accentStrong
        : ui.colors.textMuted.withValues(alpha: .3);
    return Material(
      color: selected
          ? Color.alphaBlend(
              ui.colors.accent.withValues(alpha: .16),
              ui.colors.background,
            )
          : ui.colors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ui.radii.sm),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: ui.sizes.tapTarget),
        child: !unlocked
            ? Semantics(
                enabled: false,
                label: context.l10n.characterLockedSemantics(
                  name: name,
                  level: requiredLevel,
                ),
                child: ExcludeSemantics(
                  child: Padding(
                    padding: EdgeInsets.all(ui.space.xxs),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: ui.sizes.iconSize.sm,
                          color: ui.colors.textMuted,
                        ),
                        SizedBox(width: ui.space.xxs),
                        Expanded(
                          child: Text(
                            context.l10n.characterBuildUnlockLevel(
                              level: requiredLevel,
                            ),
                            style: ui.text.body.copyWith(
                              color: ui.colors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: Semantics(
                      selected: selected,
                      button: true,
                      enabled: onSelect != null,
                      onTap: onSelect,
                      excludeSemantics: true,
                      label: context.l10n.characterSelectBuildSemantics(
                        build: name,
                        character: characterName,
                      ),
                      child: InkWell(
                        onTap: onSelect,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: ui.sizes.tapTarget,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: ui.space.xxs,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: selected
                                      ? ui.colors.accentStrong
                                      : ui.colors.textMuted,
                                  size: ui.sizes.iconSize.sm,
                                ),
                                SizedBox(width: ui.space.xxs),
                                Expanded(
                                  child: Tooltip(
                                    message: name,
                                    child: ExcludeSemantics(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: ui.text.body,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (selected)
                                            Text(
                                              context.l10n.characterActiveBuild,
                                              style: ui.text.body.copyWith(
                                                fontSize: 11,
                                                color: ui.colors.accentStrong,
                                              ),
                                              maxLines: 2,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 1,
                    height: ui.sizes.tapTarget - ui.space.sm,
                    child: ColoredBox(color: border),
                  ),
                  Tooltip(
                    message: context.l10n.characterEditBuildSemantics(
                      build: name,
                      character: characterName,
                    ),
                    child: Semantics(
                      button: true,
                      enabled: onEdit != null,
                      onTap: onEdit,
                      excludeSemantics: true,
                      label: context.l10n.characterEditBuildSemantics(
                        build: name,
                        character: characterName,
                      ),
                      child: InkWell(
                        onTap: onEdit,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: ui.sizes.tapTarget,
                            maxWidth: ui.sizes.tapTarget,
                            minHeight: ui.sizes.tapTarget,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: ui.space.xxs,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: ui.sizes.iconSize.sm,
                                  color: ui.colors.textPrimary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
