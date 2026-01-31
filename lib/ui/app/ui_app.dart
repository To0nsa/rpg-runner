import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'ui_router.dart';
import 'ui_routes.dart';

class UiApp extends StatefulWidget {
  const UiApp({super.key});

  @override
  State<UiApp> createState() => _UiAppState();
}

class _UiAppState extends State<UiApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final _UiRouteObserver _routeObserver =
      _UiRouteObserver(onRouteChanged: _handleRouteChanged);

  String? _currentRouteName;
  bool _hasSeenRoute = false;
  bool _resumeInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _showResumeLoader();
    }
  }

  void _handleRouteChanged(String? routeName) {
    _hasSeenRoute = true;
    _currentRouteName = routeName;
  }

  void _showResumeLoader() {
    if (_resumeInFlight) return;
    if (!_hasSeenRoute || _currentRouteName == UiRoutes.loader) {
      return;
    }
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    _resumeInFlight = true;
    navigator
        .pushNamed(
          UiRoutes.loader,
          arguments: const LoaderArgs(isResume: true),
        )
        .whenComplete(() {
      _resumeInFlight = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'rpg-runner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.white,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        navigatorKey: _navigatorKey,
        initialRoute: UiRoutes.loader,
        onGenerateRoute: UiRouter.onGenerateRoute,
        navigatorObservers: [_routeObserver],
      ),
    );
  }
}

class _UiRouteObserver extends NavigatorObserver {
  _UiRouteObserver({required this.onRouteChanged});

  final ValueChanged<String?> onRouteChanged;

  void _update(Route<dynamic>? route) {
    onRouteChanged(route?.settings.name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _update(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _update(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _update(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _update(previousRoute);
  }
}
