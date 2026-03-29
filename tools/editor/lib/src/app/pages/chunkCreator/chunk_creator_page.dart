import 'package:flutter/material.dart';

import '../shared/editor_route_intro_card.dart';

class ChunkCreatorPage extends StatelessWidget {
  const ChunkCreatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const EditorRouteIntroCard(
      title: 'Chunk Creator',
      description:
          'Final chunk composition workspace for terrain, prefabs, markers, '
          'metadata, and validation.',
    );
  }
}
