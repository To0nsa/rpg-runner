import 'package:flutter/material.dart';

import '../components/app_button.dart';
import '../theme/ui_tokens.dart';

class LoaderContent extends StatelessWidget {
  const LoaderContent({
    super.key,
    this.title = 'The Long Run',
    this.subtitle = 'Lothringen',
    this.loadingMessage = 'Loading...',
    this.errorMessage,
    this.continueLabel = 'Retry',
    this.onContinue,
  });

  final String title;
  final String subtitle;
  final String loadingMessage;
  final String? errorMessage;
  final String continueLabel;
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
            subtitle,
            style: TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: titleColor,
              letterSpacing: 2,
            ),
          ),
          Text(
            title,
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
              loadingMessage,
              style: ui.text.body.copyWith(color: ui.colors.textPrimary),
            ),
          ],
          if (_hasError) ...[
            Text(
              'Bootstrap failed',
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
                label: continueLabel,
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
