import 'package:flutter/material.dart';

import '../../../../core/projectiles/projectile_id.dart';
import '../../../components/app_button.dart';
import '../../../theme/ui_tokens.dart';
import '../ability/ability_picker_presenter.dart';
import 'skills_list_pane.dart';

/// Opens the projectile source picker modal.
Future<void> showProjectileSourceDialog(
  BuildContext context, {
  required List<ProjectileSourceOption> options,
  required ProjectileId? initialSelection,
  required ValueChanged<ProjectileId?> onSelect,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: context.ui.colors.scrim,
    builder: (dialogContext) {
      final ui = dialogContext.ui;
      final media = MediaQuery.of(dialogContext);
      final maxWidth = (media.size.width - (ui.space.sm * 2))
          .clamp(320.0, 460.0)
          .toDouble();
      final maxHeight = (media.size.height - (ui.space.sm * 2))
          .clamp(220.0, 520.0)
          .toDouble();

      return _ProjectileSourceDialog(
        options: options,
        initialSelection: initialSelection,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        onSelect: onSelect,
      );
    },
  );
}

/// Stateful dialog that lets the user browse projectile sources with
/// expandable detail panels before dismissing.
class _ProjectileSourceDialog extends StatefulWidget {
  const _ProjectileSourceDialog({
    required this.options,
    required this.initialSelection,
    required this.maxWidth,
    required this.maxHeight,
    required this.onSelect,
  });

  final List<ProjectileSourceOption> options;
  final ProjectileId? initialSelection;
  final double maxWidth;
  final double maxHeight;
  final ValueChanged<ProjectileId?> onSelect;

  @override
  State<_ProjectileSourceDialog> createState() =>
      _ProjectileSourceDialogState();
}

class _ProjectileSourceDialogState extends State<_ProjectileSourceDialog> {
  late ProjectileId? _selected;

  /// Index of the tile whose detail panel is open, or `null` when all
  /// tiles are collapsed.
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
    // Start with the initially-selected tile expanded so the user
    // immediately sees its details.
    for (var i = 0; i < widget.options.length; i += 1) {
      if (widget.options[i].spellId == _selected) {
        _expandedIndex = i;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Dialog(
      backgroundColor: ui.colors.cardBackground,
      insetPadding: EdgeInsets.all(ui.space.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ui.radii.md),
        side: BorderSide(color: ui.colors.outline.withValues(alpha: 0.35)),
      ),
      child: SizedBox(
        width: widget.maxWidth,
        height: widget.maxHeight,
        child: Padding(
          padding: EdgeInsets.all(ui.space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select Projectile Source',
                style: ui.text.headline.copyWith(color: ui.colors.textPrimary),
              ),
              SizedBox(height: ui.space.sm),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.options.length,
                  separatorBuilder: (_, _) => SizedBox(height: ui.space.xs),
                  itemBuilder: (context, index) {
                    final option = widget.options[index];
                    final isSelected = option.spellId == _selected;
                    final isExpanded = _expandedIndex == index;
                    return SkillsProjectileSourceTile(
                      projectileId: option.projectileId,
                      title: option.displayName,
                      selected: isSelected,
                      expanded: isExpanded,
                      description: option.description,
                      damageTypeName: option.damageTypeName,
                      statusLines: option.statusLines,
                      onTap: () {
                        setState(() {
                          _selected = option.spellId;
                          // Toggle expansion: collapse if already open,
                          // otherwise expand the tapped tile.
                          _expandedIndex = _expandedIndex == index
                              ? null
                              : index;
                        });
                        widget.onSelect(option.spellId);
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: ui.space.sm),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: 'Close',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.xs,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
