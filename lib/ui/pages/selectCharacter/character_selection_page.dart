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
import '../../theme/ui_tokens.dart';

/// Selects a character in place or opens its independently remembered build.
class CharacterSelectionPage extends StatefulWidget {
  const CharacterSelectionPage({super.key});
  @override
  State<CharacterSelectionPage> createState() => _CharacterSelectionPageState();
}

class _CharacterSelectionPageState extends State<CharacterSelectionPage> {
  bool _saving = false;
  String? _error;

  Future<void> _select(PlayerCharacterId id, {bool openBuild = false}) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AppState>().setCharacter(id);
      if (!mounted) return;
      if (openBuild) {
        Navigator.of(context).pushReplacementNamed(UiRoutes.setupLoadout);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not select this character. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
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
                          enabled: !_saving,
                          onSelect: () => _select(character.id),
                          onBuild: () => _select(character.id, openBuild: true),
                        ),
                      ),
                  ],
                ),
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
    required this.onSelect,
    required this.onBuild,
  });
  final PlayerCharacterDefinition character;
  final bool selected, enabled;
  final VoidCallback onSelect, onBuild;

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
                padding: EdgeInsets.all(ui.space.md),
                child: Column(
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
                    Text(character.displayName, style: ui.text.title),
                    SizedBox(height: ui.space.sm),
                    SizedBox(
                      width: 220,
                      child: AppButton(
                        label: 'Change build',
                        onPressed: enabled ? onBuild : null,
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
