import 'package:flutter/material.dart';

/// Tiny status marker used for selected/equipped indicators.
class StateDot extends StatelessWidget {
  const StateDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Layout parameters for the fixed-size candidate grid.
class CandidateGridSpec {
  const CandidateGridSpec({
    required this.crossAxisCount,
    required this.mainAxisExtent,
    required this.spacing,
  });

  final int crossAxisCount;
  final double mainAxisExtent;
  final double spacing;
}

/// Computes a dense, non-scrollable grid spec for the right panel.
///
/// Tiles use a fixed extent; only column count adapts to available width.
CandidateGridSpec candidateGridSpecForAvailableSpace({
  required int itemCount,
  required double availableWidth,
  required double availableHeight,
  required double spacing,
}) {
  const tileExtent = 64.0;
  if (itemCount <= 0 || availableWidth <= 0 || availableHeight <= 0) {
    return CandidateGridSpec(
      crossAxisCount: 1,
      mainAxisExtent: tileExtent,
      spacing: spacing,
    );
  }

  const minTileWidth = tileExtent;
  final maxColumnsByWidth =
      ((availableWidth + spacing) / (minTileWidth + spacing)).floor().clamp(
        1,
        999,
      );

  return CandidateGridSpec(
    crossAxisCount: maxColumnsByWidth,
    mainAxisExtent: tileExtent,
    spacing: spacing,
  );
}
