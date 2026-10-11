import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../assets/ui_asset_lifecycle.dart';
import '../levels/level_id_ui.dart';
import '../state/app/app_state.dart';
import '../state/run/run_submission_status.dart';
import '../state/ownership/ownership_sync_policy.dart';
import '../theme/ui_theme.dart';
import 'app_services.dart';
import 'ui_route_observer.dart';
import 'ui_router.dart';
import 'ui_routes.dart';

/// Standalone navigation and lifecycle shell. Takes ownership of [services].
class UiApp extends StatefulWidget {
  const UiApp({super.key, required this.services});

  final AppServices services;

  @override
  State<UiApp> createState() => _UiAppState();
}

class _UiAppState extends State<UiApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  AppState? _rewardAppState;
  RunSubmissionStatus? _lastReward;
  late final _theme = createUiTheme();
  late final _routeObserver = UiRouteObserver(
    onPageChanged: _handlePageChanged,
    onPageRemoved: _handlePageRemoved,
  );
  String? _currentRouteName;
  bool _resumeInFlight = false;
  bool _systemUiScheduled = false;

  bool get _isStartupRoute =>
      _currentRouteName == null ||
      _currentRouteName == UiRoutes.brandSplash ||
      _currentRouteName == UiRoutes.loader;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.services.addListener(_bindRewardNotifications);
    _bindRewardNotifications();
    unawaited(_configureDisplay());
  }

  @override
  void dispose() {
    widget.services.removeListener(_bindRewardNotifications);
    _rewardAppState?.removeListener(_onRewardCompleted);
    WidgetsBinding.instance.removeObserver(this);
    widget.services.dispose();
    super.dispose();
  }

  void _bindRewardNotifications() {
    final app = widget.services.readyAppState;
    if (identical(app, _rewardAppState)) return;
    _rewardAppState?.removeListener(_onRewardCompleted);
    _rewardAppState = app;
    _lastReward = app?.latestVerifiedReward;
    app?.addListener(_onRewardCompleted);
  }

  void _onRewardCompleted() {
    final app = _rewardAppState;
    final reward = app?.latestVerifiedReward;
    if (reward == null || identical(reward, _lastReward)) return;
    _lastReward = reward;
    if (reward.spendableGoldDelta <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(app, _rewardAppState) ||
          !identical(app?.latestVerifiedReward, reward)) {
        return;
      }
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('${reward.spendableGoldDelta} gold verified'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  Future<void> _configureDisplay() async {
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (error, stackTrace) {
      debugPrint('Display orientation failed: $error\n$stackTrace');
    }
    if (mounted) _applyGlobalSystemUiMode();
  }

  Future<void> _setImmersiveMode() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (error, stackTrace) {
      debugPrint('Immersive mode failed: $error\n$stackTrace');
    }
  }

  void _applyGlobalSystemUiMode() {
    if (!mounted || _systemUiScheduled) return;
    _systemUiScheduled = true;
    unawaited(_setImmersiveMode());
    // Route disposal can restore system bars; reapply once after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _systemUiScheduled = false;
      if (mounted) unawaited(_setImmersiveMode());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final appState = widget.services.readyAppState;
    if (widget.services.isSwitchingProfile) return;
    appState?.setRunSubmissionForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      _applyGlobalSystemUiMode();
      if (_isStartupRoute || appState == null) return;
      if (_currentRouteName == UiRoutes.runBootstrap ||
          _currentRouteName == UiRoutes.run) {
        unawaited(
          appState.flushOwnershipEdits(
            trigger: OwnershipFlushTrigger.connectivityRestored,
          ),
        );
      } else {
        // Forced bootstrap owns flush-before-refresh ordering.
        _showResumeLoader();
      }
      return;
    }
    if (_isStartupRoute || appState == null) return;
    final trigger = switch (state) {
      AppLifecycleState.inactive => OwnershipFlushTrigger.lifecycleInactive,
      AppLifecycleState.paused => OwnershipFlushTrigger.lifecyclePaused,
      AppLifecycleState.detached => OwnershipFlushTrigger.lifecycleDetached,
      _ => null,
    };
    if (trigger != null) {
      unawaited(appState.flushOwnershipEdits(trigger: trigger));
    }
  }

  @override
  void didChangeMetrics() => _applyGlobalSystemUiMode();

  void _handlePageChanged(String? name) {
    _currentRouteName = name;
    widget.services.readyAppState?.setRunSubmissionForeground(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
    _applyGlobalSystemUiMode();
    if (name == UiRoutes.hub) {
      widget.services.readyAppState?.startWarmup();
      unawaited(_warmHubSelection());
    }
  }

  void _handlePageRemoved(String? name) {
    final appState = widget.services.readyAppState;
    if (appState == null) return;
    if (name == UiRoutes.setupLevel) {
      unawaited(appState.ensureSelectionSyncedBeforeLeavingLevelSetup());
    } else if (name == UiRoutes.setupLoadout) {
      unawaited(
        appState.flushOwnershipEdits(
          trigger: OwnershipFlushTrigger.leaveLoadoutSetup,
        ),
      );
    }
  }

  Future<void> _warmHubSelection() async {
    final ctx = _navigatorKey.currentContext;
    final appState = widget.services.readyAppState;
    if (ctx == null || appState == null) return;
    final selection = appState.selection;
    await ctx.read<UiAssetLifecycle>().warmHubSelection(
      visualThemeId: selection.selectedLevelId.visualThemeId,
      characterId: selection.selectedCharacterId,
      context: ctx,
    );
  }

  void _showResumeLoader() {
    if (_resumeInFlight) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    _resumeInFlight = true;
    unawaited(
      navigator
          .pushNamed(
            UiRoutes.loader,
            arguments: const LoaderArgs(isResume: true),
          )
          .whenComplete(() {
            _resumeInFlight = false;
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppServices>.value(value: widget.services),
        // AppServices owns disposal; subscription starts only on ready routes.
        ListenableProxyProvider<AppServices, AppState>(
          update: (_, services, _) => services.appState,
        ),
        Provider<UiAssetLifecycle>(
          create: (_) => UiAssetLifecycle(),
          dispose: (_, lifecycle) => lifecycle.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'rpg-runner',
        debugShowCheckedModeBanner: false,
        theme: _theme,
        builder: (context, child) => child == null
            ? const SizedBox.shrink()
            : _StableHorizontalSafePadding(child: child),
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _messengerKey,
        initialRoute: UiRoutes.brandSplash,
        onGenerateInitialRoutes: UiRouter.onGenerateInitialRoutes,
        onGenerateRoute: UiRouter.onGenerateRoute,
        navigatorObservers: [_routeObserver],
      ),
    );
  }
}

/// Preserves horizontal safe insets while Android system bars appear or hide.
class _StableHorizontalSafePadding extends StatelessWidget {
  const _StableHorizontalSafePadding({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.padding.copyWith(
      left: mediaQuery.viewPadding.left,
      right: mediaQuery.viewPadding.right,
    );
    return padding == mediaQuery.padding
        ? child
        : MediaQuery(
            data: mediaQuery.copyWith(padding: padding),
            child: child,
          );
  }
}
