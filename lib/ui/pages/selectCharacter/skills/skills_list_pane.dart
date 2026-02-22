import 'package:flutter/material.dart';

import '../../../../core/abilities/ability_def.dart';
import '../../../components/ability_placeholder_icon.dart';
import '../../../components/app_button.dart';
import '../../../text/ability_text.dart';
import '../../../theme/ui_tokens.dart';
import '../ability/ability_picker_presenter.dart';

class SkillsListPane extends StatelessWidget {
  const SkillsListPane({
    super.key,
    required this.selectedSlot,
    required this.candidates,
    required this.selectedAbilityId,
    required this.compact,
    required this.onSelectAbility,
    required this.onSelectProjectileSource,
  });

  final AbilitySlot selectedSlot;
  final List<AbilityPickerCandidate> candidates;
  final AbilityKey? selectedAbilityId;
  final bool compact;
  final ValueChanged<AbilityPickerCandidate> onSelectAbility;
  final VoidCallback? onSelectProjectileSource;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final panePadding = compact ? ui.space.xs : ui.space.sm;
    final titleStyle = compact
        ? ui.text.body.copyWith(
            color: ui.colors.textPrimary,
            fontWeight: FontWeight.w700,
          )
        : ui.text.headline.copyWith(color: ui.colors.textPrimary);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(ui.radii.md),
        border: Border.all(color: ui.colors.outline.withValues(alpha: 0.25)),
      ),
      padding: EdgeInsets.all(panePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.center,
            child: Text(
              '${_slotTitle(selectedSlot)} Abilities',
              style: titleStyle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: compact ? ui.space.xxs : ui.space.xs),
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
            SizedBox(height: compact ? ui.space.xxs : ui.space.xs),
          ],
          SizedBox(height: compact ? ui.space.xxs : ui.space.xs),
          Expanded(
            child: ListView.separated(
              itemCount: candidates.length,
              separatorBuilder: (_, _) =>
                  SizedBox(height: compact ? ui.space.xxs : ui.space.xs),
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                final selected = candidate.id == selectedAbilityId;
                return _AbilityListTile(
                  title: abilityDisplayName(candidate.id),
                  selected: selected,
                  enabled: candidate.isEnabled,
                  compact: compact,
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
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final borderColor = selected
        ? ui.colors.accentStrong
        : ui.colors.outline.withValues(alpha: 0.45);
    final fillColor = selected
        ? const Color(0xFF1A1A1A)
        : const Color(0xFF131313);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui.radii.sm),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: ui.space.sm,
            vertical: ui.space.xs,
          ),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(ui.radii.sm),
            border: Border.all(color: borderColor),
          ),
          child: _tileTitleContent(context: context, title: title),
        ),
      ),
    );
  }
}

class _AbilityListTile extends StatelessWidget {
  const _AbilityListTile({
    required this.title,
    required this.selected,
    required this.enabled,
    required this.compact,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final bool enabled;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final borderColor = selected
        ? ui.colors.accentStrong
        : ui.colors.outline.withValues(alpha: 0.45);
    final fillColor = selected
        ? const Color(0xFF1A1A1A)
        : const Color(0xFF131313);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ui.radii.sm),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? ui.space.xs : ui.space.sm,
              vertical: compact ? ui.space.xxs : ui.space.xs,
            ),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(ui.radii.sm),
              border: Border.all(color: borderColor),
            ),
            child: _tileTitleContent(
              context: context,
              title: title,
              uppercase: true,
              leading: AbilityPlaceholderIcon(
                label: '',
                size: 40,
                emphasis: selected,
                enabled: enabled,
              ),
              leadingGap: ui.space.md,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _tileTitleContent({
  required BuildContext context,
  required String title,
  bool uppercase = false,
  Widget? leading,
  double leadingGap = 0,
}) {
  final ui = context.ui;
  final text = Text(
    uppercase ? title.toUpperCase() : title,
    style: ui.text.body.copyWith(color: ui.colors.textPrimary),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
  if (leading == null) return text;
  return Row(
    children: [
      leading,
      SizedBox(width: leadingGap),
      Expanded(child: text),
    ],
  );
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
