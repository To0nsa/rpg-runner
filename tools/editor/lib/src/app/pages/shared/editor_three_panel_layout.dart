import 'package:flutter/material.dart';

/// Requests visibility of a diagnostic or contextual destination at narrow widths.
/// Repeated requests reveal the panel again after the user selects another tab.
class EditorThreePanelController extends ChangeNotifier {
  int? _requestedPanelIndex;
  int? get requestedPanelIndex => _requestedPanelIndex;

  void revealPanel(int index) {
    RangeError.checkValidIndex(index, const [0, 1, 2]);
    _requestedPanelIndex = index;
    notifyListeners();
  }
}

/// Responsive three-panel editor shell.
///
/// Wide windows keep all panels visible. Narrow windows expose the same
/// panels through keyboard- and semantics-aware tabs without making the scene
/// compete with a horizontal page-swipe gesture.
class EditorThreePanelLayout extends StatefulWidget {
  const EditorThreePanelLayout({
    super.key,
    required this.firstLabel,
    required this.secondLabel,
    required this.thirdLabel,
    required this.first,
    required this.second,
    required this.third,
    this.controller,
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

  final EditorThreePanelController? controller;
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
  State<EditorThreePanelLayout> createState() => _EditorThreePanelLayoutState();
}

class _EditorThreePanelLayoutState extends State<EditorThreePanelLayout>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      initialIndex:
          widget.controller?.requestedPanelIndex ?? widget.initialNarrowIndex,
      vsync: this,
    )..addListener(_handleTabChanged);
    widget.controller?.addListener(_revealRequestedPanel);
  }

  @override
  void didUpdateWidget(covariant EditorThreePanelLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_revealRequestedPanel);
      widget.controller?.addListener(_revealRequestedPanel);
      _revealRequestedPanel();
    }
  }

  void _revealRequestedPanel() {
    final index = widget.controller?.requestedPanelIndex;
    if (index != null) _tabs.index = index;
  }

  void _handleTabChanged() => setState(() {});

  @override
  void dispose() {
    widget.controller?.removeListener(_revealRequestedPanel);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= widget.minimumWideWidth;
      final flexes = [widget.firstFlex, widget.secondFlex, widget.thirdFlex];
      final totalFlex = flexes.reduce((a, b) => a + b);
      final contentWidth = (constraints.maxWidth - widget.gap * 2).clamp(
        0.0,
        double.infinity,
      );
      final panels = [widget.first, widget.second, widget.third];
      return Column(
        children: <Widget>[
          SizedBox(
            key: ValueKey<String>(
              wide ? 'editor_three_panel_wide' : 'editor_three_panel_narrow',
            ),
            height: 0,
          ),
          Offstage(
            offstage: wide,
            child: Semantics(
              container: true,
              label: 'Editor panel selector',
              child: TabBar(
                controller: _tabs,
                tabs: <Widget>[
                  Tab(text: widget.firstLabel),
                  Tab(text: widget.secondLabel),
                  Tab(text: widget.thirdLabel),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (var index = 0; index < panels.length; index++)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: wide
                        ? contentWidth *
                                  flexes
                                      .take(index)
                                      .fold<int>(0, (a, b) => a + b) /
                                  totalFlex +
                              widget.gap * index
                        : 0,
                    width: wide
                        ? contentWidth * flexes[index] / totalFlex
                        : constraints.maxWidth,
                    child: Offstage(
                      offstage: !wide && _tabs.index != index,
                      child: TickerMode(
                        enabled: wide || _tabs.index == index,
                        child: ExcludeFocus(
                          excluding: !wide && _tabs.index != index,
                          child: panels[index],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
