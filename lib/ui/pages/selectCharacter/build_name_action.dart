import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/app_button.dart';
import '../../components/app_dialog.dart';
import '../../components/app_inline_icon_button.dart';
import '../../state/app/app_state.dart';
import '../../state/ownership/selection_state.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_inline_edit_text_theme.dart';

class BuildNameAction extends StatelessWidget {
  const BuildNameAction({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selection = state.selection;
    final buildIndex = selection.selectedBuildIndexFor(
      selection.selectedCharacterId,
    );
    void rename() => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BuildNameDialog(state: state),
    );

    if (selection.buildName == SelectionState.defaultBuildName(buildIndex)) {
      return AppInlineIconButton(
        icon: Icons.edit_outlined,
        tooltip: context.l10n.uiRenameBuild,
        onPressed: rename,
      );
    }

    final ui = context.ui;
    return Tooltip(
      message: context.l10n.uiRenameBuild,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width < 700 ? 95 : 150,
        ),
        child: TextButton(
          onPressed: rename,
          style: TextButton.styleFrom(
            foregroundColor: ui.colors.textPrimary,
            textStyle: ui.text.label,
            minimumSize: Size(ui.sizes.tapTarget, ui.sizes.tapTarget),
            padding: EdgeInsets.symmetric(horizontal: ui.space.xs),
          ),
          child: Text(
            selection.buildName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _BuildNameDialog extends StatefulWidget {
  const _BuildNameDialog({required this.state});
  final AppState state;
  @override
  State<_BuildNameDialog> createState() => _BuildNameDialogState();
}

class _BuildNameDialogState extends State<_BuildNameDialog> {
  late final _controller = TextEditingController(
    text:
        widget.state.selection.buildName ==
            SelectionState.defaultBuildName(
              widget.state.selection.selectedBuildIndexFor(
                widget.state.selection.selectedCharacterId,
              ),
            )
        ? ''
        : widget.state.selection.buildName,
  );
  bool _saving = false;
  String Function(AppLocalizations)? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = (l10n) => l10n.uiEnterABuildName);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.state.setBuildName(_controller.text);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = (l10n) => l10n.uiCouldNotSaveTheNamePleaseTryAgain;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final field = context.inlineEditText.resolveSpec(ui: ui);
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    final compact =
        availableHeight < 260 && MediaQuery.sizeOf(context).width >= 480;
    final input = TextField(
      controller: _controller,
      style: field.valueStyle,
      cursorColor: ui.colors.accentStrong,
      autofocus: true,
      enabled: !_saving,
      maxLength: SelectionState.buildNameMaxLength,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _save(),
      decoration: field.fieldDecoration.copyWith(
        labelText: context.l10n.uiBuildName,
        hintText: context.l10n.defaultBuildName(
          number:
              widget.state.selection.selectedBuildIndexFor(
                widget.state.selection.selectedCharacterId,
              ) +
              1,
        ),
        errorText: _error?.call(context.l10n),
        labelStyle: ui.text.body.copyWith(color: ui.colors.textMuted),
        counterStyle: ui.text.body.copyWith(
          color: ui.colors.textMuted,
          fontSize: 12,
        ),
        errorStyle: ui.text.body.copyWith(
          color: ui.colors.danger,
          fontSize: 12,
        ),
      ),
    );
    final actions = [
      AppButton(
        label: context.l10n.uiCancel,
        size: compact ? AppButtonSize.xxs : AppButtonSize.xs,
        variant: AppButtonVariant.secondary,
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
      ),
      AppButton(
        label: _saving ? context.l10n.uiSaving : context.l10n.uiSave,
        size: compact ? AppButtonSize.xxs : AppButtonSize.xs,
        onPressed: _saving ? null : _save,
      ),
    ];
    return PopScope(
      canPop: !_saving,
      child: AppDialog(
        title: compact ? null : context.l10n.uiRenameBuild,
        maxWidth: compact ? 640 : 440,
        scrollable: true,
        content: compact
            ? Row(
                spacing: ui.space.sm,
                children: [
                  Expanded(child: input),
                  ...actions,
                ],
              )
            : input,
        actions: compact ? const [] : actions,
      ),
    );
  }
}
