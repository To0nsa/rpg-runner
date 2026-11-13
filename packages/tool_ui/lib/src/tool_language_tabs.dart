import 'package:flutter/material.dart';

/// English/French authoring tabs that retain both field subtrees.
///
/// The caller owns the two-tab [controller], draft values and validation.
/// Hidden fields remain mounted but cannot receive focus or run animations.
class ToolLanguageTabs extends StatelessWidget {
  const ToolLanguageTabs({
    super.key,
    required this.controller,
    required this.english,
    required this.french,
  });

  final TabController controller;
  final Widget english;
  final Widget french;

  @override
  Widget build(BuildContext context) {
    assert(controller.length == 2);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final children = [english, french];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              controller: controller,
              tabs: const [
                Tab(text: 'English'),
                Tab(text: 'Français'),
              ],
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < children.length; index++)
              Offstage(
                offstage: index != controller.index,
                child: TickerMode(
                  enabled: index == controller.index,
                  child: ExcludeFocus(
                    excluding: index != controller.index,
                    child: children[index],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
