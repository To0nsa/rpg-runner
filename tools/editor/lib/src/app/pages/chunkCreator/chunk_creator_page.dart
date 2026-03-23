import 'package:flutter/material.dart';

class ChunkCreatorPage extends StatelessWidget {
  const ChunkCreatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chunk Creator',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Coming soon.'),
          ],
        ),
      ),
    );
  }
}
