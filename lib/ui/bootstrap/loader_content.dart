import 'package:flutter/material.dart';

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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          subtitle,
          // Game subtitle style only used here.
          style: const TextStyle(
            fontFamily: 'Cinzel',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        Text(
          title,
          // Game title style only used here.
          style: const TextStyle(
            fontFamily: 'Cinzel',
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 24),
        if (!_hasError) ...[
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(loadingMessage, style: const TextStyle(color: Colors.white70)),
        ],
        if (_hasError) ...[
          const Text(
            'Bootstrap failed',
            style: TextStyle(color: Colors.redAccent, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          if (onContinue != null) ...[
            const SizedBox(height: 16),
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
