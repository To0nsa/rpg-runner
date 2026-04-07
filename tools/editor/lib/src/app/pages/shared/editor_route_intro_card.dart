import 'package:flutter/material.dart';

/// Lightweight intro card used by editor routes that expose explanatory copy.
///
/// This keeps title/description presentation consistent without introducing a
/// route-specific scaffold dependency.
class EditorRouteIntroCard extends StatelessWidget {
  const EditorRouteIntroCard({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(description),
          ],
        ),
      ),
    );
  }
}
