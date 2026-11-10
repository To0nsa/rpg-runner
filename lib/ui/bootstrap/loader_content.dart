import '../l10n/app_localization.dart';

import 'package:flutter/material.dart';

import '../components/app_button.dart';
import '../theme/ui_tokens.dart';

class LoaderContent extends StatelessWidget {
  const LoaderContent({
    super.key,
    this.title,
    this.subtitle,
    this.loadingMessage,
    this.errorTitle,
    this.errorMessage,
    this.continueLabel,
    this.onContinue,
  });

  final String? title;
  final String? subtitle;
  final String? loadingMessage;
  final String? errorTitle;
  final String? errorMessage;
  final String? continueLabel;
  final VoidCallback? onContinue;

  bool get _hasError => errorMessage != null;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final titleColor = Color(0xFF354656);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            subtitle ?? context.l10n.loaderWorldTitle,
            style: TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: titleColor,
              letterSpacing: 2,
            ),
          ),
          Text(
            title ?? context.l10n.loaderGameTitle,
            style: TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: titleColor,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: ui.space.lg),
          if (!_hasError) ...[
            CircularProgressIndicator(color: ui.colors.textPrimary),
            SizedBox(height: ui.space.xs),
            Text(
              loadingMessage ?? context.l10n.uiLoading,
              style: ui.text.body.copyWith(color: ui.colors.textPrimary),
            ),
          ],
          if (_hasError) ...[
            Text(
              errorTitle ?? context.l10n.bootstrapFailed,
              style: ui.text.body.copyWith(
                color: ui.colors.danger,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: ui.space.xs),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: ui.text.body.copyWith(color: ui.colors.textPrimary),
            ),
            if (onContinue != null) ...[
              SizedBox(height: ui.space.md),
              AppButton(
                label: continueLabel ?? context.l10n.uiRetry,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.lg,
                onPressed: onContinue,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
