import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../assets/ui_asset_lifecycle.dart';
import '../levels/level_id_ui.dart';
import '../state/app_state.dart';
import '../theme/ui_button_theme.dart';
import '../theme/ui_hub_theme.dart';
import '../theme/ui_icon_button_theme.dart';
import '../theme/ui_inline_edit_text_theme.dart';
import '../theme/ui_inline_icon_button_theme.dart';
import '../theme/ui_leaderboard_theme.dart';
import '../theme/ui_action_button_theme.dart';
import '../theme/ui_segmented_control_theme.dart';
import '../theme/ui_skill_icon_theme.dart';
import '../theme/ui_tokens.dart';
import 'ui_router.dart';
import 'ui_routes.dart';

class UiApp extends StatefulWidget {
  const UiApp({super.key});

  @override
  State<UiApp> createState() => _UiAppState();
}

class _UiAppState extends State<UiApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final _UiRouteObserver _routeObserver = _UiRouteObserver(
    onRouteChanged: _handleRouteChanged,
  );

  String? _currentRouteName;
  bool _hasSeenRoute = false;
  bool _resumeInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyGlobalSystemUiMode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _applyGlobalSystemUiMode() {
    // Apply immediately, then again after the current frame to win races with
    // route disposal/restore behavior that can re-enable system UI.
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _applyGlobalSystemUiMode();
      _showResumeLoader();
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Keyboard/system-bar transitions can re-enable system UI (especially on
    // Android). Re-apply immersive mode after window metrics change.
    _applyGlobalSystemUiMode();
  }

  void _handleRouteChanged(
    _UiRouteChange change,
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
  ) {
    _hasSeenRoute = true;
    if (change == _UiRouteChange.pop || change == _UiRouteChange.remove) {
      _currentRouteName = previousRoute?.settings.name;
    } else {
      _currentRouteName = route?.settings.name;
    }

    if (change == _UiRouteChange.pop && route?.settings.name == UiRoutes.run) {
      _purgeRunCaches();
    }

    _applyGlobalSystemUiMode();

    if (_currentRouteName == UiRoutes.hub) {
      unawaited(_warmHubSelection());
    }
  }

  Future<void> _warmHubSelection() async {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) return;
    final appState = Provider.of<AppState>(ctx, listen: false);
    final lifecycle = Provider.of<UiAssetLifecycle>(ctx, listen: false);
    final selection = appState.selection;
    await lifecycle.warmHubSelection(
      themeId: selection.selectedLevelId.themeId,
      characterId: selection.selectedCharacterId,
      context: ctx,
    );
  }

  void _purgeRunCaches() {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) return;
    final lifecycle = Provider.of<UiAssetLifecycle>(ctx, listen: false);
    lifecycle.purgeRunCaches();
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
        .pushNamed(UiRoutes.loader, arguments: const LoaderArgs(isResume: true))
        .whenComplete(() {
          _resumeInFlight = false;
        });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        Provider<UiAssetLifecycle>(
          create: (_) => UiAssetLifecycle(),
          dispose: (_, lifecycle) => lifecycle.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'rpg-runner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme:
              ColorScheme.fromSeed(
                seedColor: UiBrandPalette.steelBlueBackground,
                brightness: Brightness.dark,
              ).copyWith(
                surface: UiBrandPalette.cardBackground,
                onSurface: UiBrandPalette.steelBlueForeground,
                outline: UiBrandPalette.wornGoldOutline,
              ),
          scaffoldBackgroundColor: UiBrandPalette.baseBackground,
          canvasColor: UiBrandPalette.cardBackground,
          dividerColor: UiBrandPalette.wornGoldOutline,
          appBarTheme: const AppBarTheme(
            backgroundColor: UiBrandPalette.baseBackground,
            foregroundColor: UiBrandPalette.steelBlueForeground,
            iconTheme: IconThemeData(color: UiBrandPalette.steelBlueForeground),
            titleTextStyle: TextStyle(
              fontFamily: 'CrimsonText',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: UiBrandPalette.steelBlueForeground,
            ),
          ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: UiBrandPalette.wornGoldInsetBorder,
            selectionColor: UiBrandPalette.wornGoldGlow,
            selectionHandleColor: UiBrandPalette.wornGoldInsetBorder,
          ),
          fontFamily: 'CrimsonText',
          useMaterial3: true,
          extensions: [
            UiTokens.standard,
            UiHubTheme.standard,
            UiButtonTheme.standard,
            UiIconButtonTheme.standard,
            UiInlineIconButtonTheme.standard,
            UiInlineEditTextTheme.standard,
            UiSegmentedControlTheme.standard,
            UiActionButtonTheme.standard,
            UiSkillIconTheme.standard,
            UiLeaderboardTheme.standard,
          ],
        ),
        navigatorKey: _navigatorKey,
        initialRoute: UiRoutes.brandSplash,
        onGenerateRoute: UiRouter.onGenerateRoute,
        navigatorObservers: [_routeObserver],
      ),
    );
  }
}

class _UiRouteObserver extends NavigatorObserver {
  _UiRouteObserver({required this.onRouteChanged});

  final void Function(
    _UiRouteChange change,
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
  )
  onRouteChanged;

  void _update(
    _UiRouteChange change,
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
  ) {
    onRouteChanged(change, route, previousRoute);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _update(_UiRouteChange.push, route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _update(_UiRouteChange.pop, route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _update(_UiRouteChange.replace, newRoute, oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _update(_UiRouteChange.remove, route, previousRoute);
  }
}

enum _UiRouteChange { push, pop, replace, remove }
