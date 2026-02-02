import 'package:flutter/material.dart';

/// Shared loading visual used by bootstrap + run loading.
class LoaderContent extends StatelessWidget {
  const LoaderContent({
    super.key,
    this.title = 'rpg-runner',
    this.subtitle = 'Loading...',
    this.errorMessage,
    this.onContinue,
  });

  final String title;
  final String subtitle;
  final String? errorMessage;
  final VoidCallback? onContinue;

  bool get _hasError => errorMessage != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 24),
        if (!_hasError) ...[
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
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
