import 'package:flutter/material.dart';

import '../../app/ui_routes.dart';
import '../../components/menu_scaffold.dart';
import '../../theme/ui_tokens.dart';
import 'town_map.dart';

/// Town services share the city map; each service has its own back stack.
class TownPage extends StatelessWidget {
  const TownPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return MenuScaffold(
      title: 'Théodonis',
      background: ColoredBox(color: ui.colors.background),
      child: SafeArea(
        top: false,
        child: TownMap(
          onStorePressed: () =>
              Navigator.of(context).pushNamed(UiRoutes.townStore),
          onLibraryPressed: () =>
              Navigator.of(context).pushNamed(UiRoutes.library),
        ),
      ),
    );
  }
}
