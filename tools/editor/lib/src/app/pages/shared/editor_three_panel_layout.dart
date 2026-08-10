import 'package:flutter/material.dart';

/// Responsive three-panel editor shell.
///
/// Wide windows keep all panels visible. Narrow windows expose the same
/// panels through keyboard- and semantics-aware tabs without making the scene
/// compete with a horizontal page-swipe gesture.
class EditorThreePanelLayout extends StatelessWidget {
  const EditorThreePanelLayout({
    super.key,
    required this.firstLabel,
    required this.secondLabel,
    required this.thirdLabel,
    required this.first,
    required this.second,
    required this.third,
    this.firstFlex = 1,
    this.secondFlex = 2,
    this.thirdFlex = 1,
    this.initialNarrowIndex = 1,
    this.minimumWideWidth = 1100,
    this.gap = 12,
  }) : assert(firstFlex > 0),
       assert(secondFlex > 0),
       assert(thirdFlex > 0),
       assert(initialNarrowIndex >= 0 && initialNarrowIndex < 3),
       assert(minimumWideWidth > 0),
       assert(gap >= 0);

  final String firstLabel;
  final String secondLabel;
  final String thirdLabel;
  final Widget first;
  final Widget second;
  final Widget third;
  final int firstFlex;
  final int secondFlex;
  final int thirdFlex;
  final int initialNarrowIndex;
  final double minimumWideWidth;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= minimumWideWidth) {
        return Row(
          key: const ValueKey<String>('editor_three_panel_wide'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(flex: firstFlex, child: first),
            SizedBox(width: gap),
            Expanded(flex: secondFlex, child: second),
            SizedBox(width: gap),
            Expanded(flex: thirdFlex, child: third),
          ],
        );
      }
      return DefaultTabController(
        length: 3,
        initialIndex: initialNarrowIndex,
        child: Column(
          key: const ValueKey<String>('editor_three_panel_narrow'),
          children: <Widget>[
            Semantics(
              container: true,
              label: 'Editor panel selector',
              child: TabBar(
                tabs: <Widget>[
                  Tab(text: firstLabel),
                  Tab(text: secondLabel),
                  Tab(text: thirdLabel),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[first, second, third],
              ),
            ),
          ],
        ),
      );
    },
  );
}
