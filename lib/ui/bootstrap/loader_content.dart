import 'package:flutter/material.dart';

import '../theme/ui_tokens.dart';

/// Shared loading visual used by bootstrap + run loading.
class LoaderContent extends StatelessWidget {
  const LoaderContent({
    super.key,
    this.title = 'The Long Run',
    this.subtitle = 'Lothringen',
    this.loadingMessage = 'Loading...',
    this.errorMessage,
    this.onContinue,
  });

  final String title;
  final String subtitle;
  final String loadingMessage;
  final String? errorMessage;
  final VoidCallback? onContinue;

  bool get _hasError => errorMessage != null;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final titleColor = ui.colors.textPrimary;
    final mutedTextColor = ui.colors.textMuted;
    return Column(
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
          // Game title style only used here.
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
          SizedBox(height: ui.space.md),
          Text(
            loadingMessage,
            style: ui.text.body.copyWith(color: mutedTextColor),
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
            style: ui.text.body.copyWith(color: mutedTextColor),
          ),
          if (onContinue != null) ...[
            SizedBox(height: ui.space.md),
            FilledButton(
              onPressed: onContinue,
              child: const Text('Continue with defaults'),
            ),
          ],
        ],
      ],
    );
  }
}
