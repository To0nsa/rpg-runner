import 'package:flutter/material.dart';

import '../theme/ui_tokens.dart';
import 'app_button.dart';

/// Styled dialog shell that matches the shared UI token palette.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const <Widget>[],
    this.maxWidth = 440,
  });

  final String? title;
  final Widget? content;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;

    return Dialog(
      backgroundColor: ui.colors.cardBackground,
      insetPadding: EdgeInsets.all(ui.space.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ui.radii.md),
        side: BorderSide(color: ui.colors.outline),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.all(ui.space.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: ui.text.headline.copyWith(
                    color: ui.colors.textPrimary,
                  ),
                ),
              ],
              if (content != null) ...[
                if (title != null) SizedBox(height: ui.space.xs),
                content!,
              ],
              if (actions.isNotEmpty) ...[
                SizedBox(height: ui.space.sm),
                Wrap(
                  spacing: ui.space.xs,
                  runSpacing: ui.space.xs,
                  alignment: WrapAlignment.end,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Standard yes/no confirmation dialog using [AppDialog] and [AppButton].
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
    this.cancelVariant = AppButtonVariant.secondary,
    this.confirmVariant = AppButtonVariant.primary,
    this.buttonSize = AppButtonSize.xs,
  });

  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;
  final AppButtonVariant cancelVariant;
  final AppButtonVariant confirmVariant;
  final AppButtonSize buttonSize;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;

    return AppDialog(
      title: title,
      content: Text(
        message,
        style: ui.text.body.copyWith(color: ui.colors.textPrimary),
      ),
      actions: [
        AppButton(
          label: cancelLabel,
          variant: cancelVariant,
          size: buttonSize,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: confirmLabel,
          variant: confirmVariant,
          size: buttonSize,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
