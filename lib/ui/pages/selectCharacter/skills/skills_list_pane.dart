import 'package:flutter/material.dart';

import '../../../../core/abilities/ability_def.dart';
import '../../../../core/projectiles/projectile_id.dart';
import '../../../components/ability_placeholder_icon.dart';
import '../../../components/app_button.dart';
import '../../../icons/projectile_icon_frame.dart';
import '../../../text/ability_text.dart';
import '../../../theme/ui_tokens.dart';
import '../ability/ability_picker_presenter.dart';

const Map<AbilityKey, String> _abilityListIconAssets = <AbilityKey, String>{
  'eloise.aegis_riposte': 'assets/images/icons/skills-icons/aegis_riposte.png',
  'eloise.arcane_haste': 'assets/images/icons/skills-icons/arcane_haste.png',
  'eloise.bloodletter_cleave':
      'assets/images/icons/skills-icons/bloodletter_cleave.png',
  'eloise.bloodletter_slash':
      'assets/images/icons/skills-icons/bloodletter_slash.png',
  'eloise.concussive_bash':
      'assets/images/icons/skills-icons/concussive_bash.png',
  'eloise.concussive_breaker':
      'assets/images/icons/skills-icons/concussive_breaker.png',
  'eloise.dash': 'assets/images/icons/skills-icons/dash.png',
  'eloise.double_jump': 'assets/images/icons/skills-icons/double_jump.png',
  'eloise.jump': 'assets/images/icons/skills-icons/jump.png',
  'eloise.mana_infusion': 'assets/images/icons/skills-icons/mana_infusion.png',
  'eloise.overcharge_shot':
      'assets/images/icons/skills-icons/overcharge_shot.png',
  'eloise.quick_shot': 'assets/images/icons/skills-icons/quick_shot.png',
  'eloise.riposte_guard': 'assets/images/icons/skills-icons/riposte_guard.png',
  'eloise.roll': 'assets/images/icons/skills-icons/roll.png',
  'eloise.second_wind': 'assets/images/icons/skills-icons/second_wind.png',
  'eloise.seeker_bash': 'assets/images/icons/skills-icons/seeker_bash.png',
  'eloise.seeker_slash': 'assets/images/icons/skills-icons/seeker_slash.png',
  'eloise.shield_block': 'assets/images/icons/skills-icons/shield_block.png',
  'eloise.skewer_shot': 'assets/images/icons/skills-icons/skewer_shot.png',
  'eloise.snap_shot': 'assets/images/icons/skills-icons/snap_shot.png',
  'eloise.vital_surge': 'assets/images/icons/skills-icons/vital_surge.png',
};
const double _abilityListIconSize = 32;

class SkillsListPane extends StatelessWidget {
  const SkillsListPane({
    super.key,
    required this.selectedSlot,
    required this.candidates,
    required this.selectedAbilityId,
    required this.onSelectAbility,
    required this.onSelectProjectileSource,
  });

  final AbilitySlot selectedSlot;
  final List<AbilityPickerCandidate> candidates;
  final AbilityKey? selectedAbilityId;
  final ValueChanged<AbilityPickerCandidate> onSelectAbility;
  final VoidCallback? onSelectProjectileSource;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      decoration: BoxDecoration(
        color: ui.colors.cardBackground,
        borderRadius: BorderRadius.circular(ui.radii.md),
        border: Border.all(color: ui.colors.outline.withValues(alpha: 0.25)),
      ),
      padding: EdgeInsets.all(ui.space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.center,
            child: Text(
              '${_slotTitle(selectedSlot).toUpperCase()} SKILLS',
              style: ui.text.headline.copyWith(
                color: ui.colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: ui.space.xxs),
          Container(
            height: 1,
            color: ui.colors.outline.withValues(alpha: 0.35),
          ),
          SizedBox(height: ui.space.xxs),
          if (onSelectProjectileSource != null) ...[
            Align(
              alignment: Alignment.center,
              child: AppButton(
                label: 'Select Projectile',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                onPressed: onSelectProjectileSource,
              ),
            ),
          ],
          SizedBox(height: ui.space.xxs),
          Expanded(
            child: ListView.separated(
              itemCount: candidates.length,
              separatorBuilder: (_, _) => SizedBox(height: ui.space.xxs),
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                final selected = candidate.id == selectedAbilityId;
                return _AbilityListTile(
                  abilityId: candidate.id,
                  title: abilityDisplayName(candidate.id),
                  selected: selected,
                  enabled: candidate.isEnabled,
                  onTap: () => onSelectAbility(candidate),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SkillsProjectileSourceTile extends StatelessWidget {
  const SkillsProjectileSourceTile({
    super.key,
    required this.projectileId,
    required this.title,
    required this.selected,
    required this.onTap,
    this.expanded = false,
    this.description,
    this.damageTypeName,
    this.statusLines = const <String>[],
  });

  /// The [ProjectileId] used to extract the first idle frame as an icon.
  final ProjectileId projectileId;

  final String title;

  /// Whether this tile is the currently chosen projectile source (border
  /// highlight).
  final bool selected;

  final VoidCallback onTap;

  /// Whether the details panel is currently visible. Toggled independently
  /// of [selected] so the user can collapse an already-selected card.
  final bool expanded;

  /// Short description shown when expanded (selected).
  final String? description;

  /// Damage type label shown when expanded (selected).
  final String? damageTypeName;

  /// Detailed status effect summaries shown when expanded.
  final List<String> statusLines;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final borderColor = selected
        ? ui.colors.accentStrong
        : ui.colors.outline.withValues(alpha: 0.45);
    final fillColor = selected
        ? UiBrandPalette.steelBlueInsetBottom
        : ui.colors.cardBackground;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui.radii.sm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            horizontal: ui.space.sm,
            vertical: ui.space.xs,
          ),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(ui.radii.sm),
            border: Border.all(color: borderColor),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      ProjectileIconFrame(projectileId: projectileId, size: 32),
                      SizedBox(width: ui.space.xs),
                      Expanded(
                        child: Text(
                          title,
                          style: ui.text.body.copyWith(
                            color: ui.colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        // Reserves top-right corner space for selected badge.
                        padding: EdgeInsets.only(right: ui.space.md),
                        child: AnimatedRotation(
                          turns: expanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.expand_more,
                            size: 18,
                            color: ui.colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: _ExpandedDetails(
                      description: description,
                      damageTypeName: damageTypeName,
                      statusLines: statusLines,
                    ),
                    crossFadeState: expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                    sizeCurve: Curves.easeInOut,
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _SelectedCheckBadge(color: ui.colors.success),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedDetails extends StatelessWidget {
  const _ExpandedDetails({
    this.description,
    this.damageTypeName,
    this.statusLines = const <String>[],
  });

  final String? description;
  final String? damageTypeName;
  final List<String> statusLines;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final hasDescription = description != null && description!.isNotEmpty;
    final hasDamageType = damageTypeName != null && damageTypeName!.isNotEmpty;
    final hasStatus = statusLines.isNotEmpty;
    if (!hasDescription && !hasDamageType && !hasStatus) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(top: ui.space.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasDamageType)
            Row(
              children: [
                Text(
                  'Damage: ',
                  style: ui.text.body.copyWith(
                    color: ui.colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  damageTypeName!,
                  style: ui.text.body.copyWith(
                    color: ui.colors.valueHighlight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          if (hasDamageType && (hasDescription || hasStatus))
            SizedBox(height: ui.space.xxs),
          if (hasDescription)
            Text(
              description!,
              style: ui.text.body.copyWith(color: ui.colors.textMuted),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          if (hasDescription && hasStatus) SizedBox(height: ui.space.xxs),
          for (final line in statusLines)
            Padding(
              padding: EdgeInsets.only(top: statusLines.first == line ? 0 : 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: ui.text.body.copyWith(color: ui.colors.textMuted),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: _highlightValues(
                          line,
                          normal: ui.text.body.copyWith(
                            color: ui.colors.textPrimary,
                          ),
                          highlight: ui.text.body.copyWith(
                            color: ui.colors.valueHighlight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Builds [TextSpan]s from [text], highlighting numeric tokens
/// (e.g. "25", "-25%", "3 seconds", "50% chance") in [highlight] style.
List<TextSpan> _highlightValues(
  String text, {
  required TextStyle normal,
  required TextStyle highlight,
}) {
  // Matches numbers with optional leading sign and optional trailing %.
  final regex = RegExp(r'[+-]?\d+(?:\.\d+)?%?');
  final spans = <TextSpan>[];
  var index = 0;
  for (final match in regex.allMatches(text)) {
    if (match.start > index) {
      spans.add(
        TextSpan(text: text.substring(index, match.start), style: normal),
      );
    }
    spans.add(TextSpan(text: match.group(0), style: highlight));
    index = match.end;
  }
  if (index < text.length) {
    spans.add(TextSpan(text: text.substring(index), style: normal));
  }
  return spans;
}

class _AbilityListTile extends StatelessWidget {
  const _AbilityListTile({
    required this.abilityId,
    required this.title,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final AbilityKey abilityId;
  final String title;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final borderColor = selected
        ? ui.colors.accentStrong
        : ui.colors.outline.withValues(alpha: 0.45);
    final fillColor = selected
        ? UiBrandPalette.steelBlueInsetBottom
        : ui.colors.cardBackground;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ui.radii.sm),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ui.space.xs,
              vertical: ui.space.xxs,
            ),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(ui.radii.sm),
              border: Border.all(color: borderColor),
            ),
            child: Stack(
              children: [
                Row(
                  children: [
                    _AbilityListIcon(
                      abilityId: abilityId,
                      selected: selected,
                      enabled: enabled,
                    ),
                    SizedBox(width: ui.space.md),
                    Expanded(
                      child: Text(
                        title,
                        style: ui.text.body.copyWith(
                          color: ui.colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (selected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _SelectedCheckBadge(color: ui.colors.success),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AbilityListIcon extends StatelessWidget {
  const _AbilityListIcon({
    required this.abilityId,
    required this.selected,
    required this.enabled,
  });

  final AbilityKey abilityId;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final iconAsset = _abilityListIconAssets[abilityId];
    if (iconAsset == null) {
      return AbilityPlaceholderIcon(
        label: '',
        size: _abilityListIconSize,
        emphasis: selected,
        enabled: enabled,
      );
    }
    return SizedBox(
      width: _abilityListIconSize,
      height: _abilityListIconSize,
      child: Image.asset(
        iconAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => AbilityPlaceholderIcon(
          label: '',
          size: _abilityListIconSize,
          emphasis: selected,
          enabled: enabled,
        ),
      ),
    );
  }
}

/// Selected-state badge used across skills selection tiles.
class _SelectedCheckBadge extends StatelessWidget {
  const _SelectedCheckBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ui.colors.cardBackground,
        shape: BoxShape.circle,
        border: Border.all(color: color),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(Icons.check, size: 11, color: color),
      ),
    );
  }
}

String _slotTitle(AbilitySlot slot) {
  switch (slot) {
    case AbilitySlot.primary:
      return 'Primary';
    case AbilitySlot.secondary:
      return 'Secondary';
    case AbilitySlot.projectile:
      return 'Projectile';
    case AbilitySlot.mobility:
      return 'Mobility';
    case AbilitySlot.spell:
      return 'Spell';
    case AbilitySlot.jump:
      return 'Jump';
  }
}
