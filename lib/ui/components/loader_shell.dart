import 'package:flutter/material.dart';

import 'menu_layout.dart';
import 'menu_scaffold.dart';

/// Shared shell for loader/bootstrap screens with centered status content.
class LoaderShell extends StatelessWidget {
  const LoaderShell({super.key, required this.child, this.scrollable = false});

  final Widget child;
  final bool scrollable;

  static const String _backgroundAsset =
      'assets/images/backgrounds/loader_bg.png';

  @override
  Widget build(BuildContext context) {
    return MenuScaffold(
      showAppBar: false,
      background: Image.asset(
        _backgroundAsset,
        fit: BoxFit.fitWidth,
        alignment: Alignment.bottomCenter,
      ),
      child: MenuLayout(
        alignment: Alignment.center,
        scrollable: scrollable,
        maxWidth: double.infinity,
        horizontalPadding: 0,
        child: child,
      ),
    );
  }
}
