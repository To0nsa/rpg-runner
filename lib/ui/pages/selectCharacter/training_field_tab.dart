import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/contracts/render_contract.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/enums.dart';

import '../../../game/input/runner_gameplay_action.dart';
import '../../../game/input/runner_semantic_action_dispatcher.dart';
import '../../../game/runner_flame_game.dart';
import '../../codex/codex_catalog.dart';
import '../../controls/movement_control_mode.dart';
import '../../hud/game/game_overlay.dart';
import '../../input/desktop/runner_desktop_aim_geometry.dart';
import '../../input/desktop/runner_desktop_input_adapter.dart';
import '../../input/runner_control_scheme.dart';
import '../../run/training_field_session.dart';
import '../../runner_game_ui_state.dart';
import '../../scoped/scoped_game_context_menu.dart';
import '../../state/app/app_state.dart';
import '../../state/settings/control_settings.dart';
import '../../viewport/game_viewport.dart';
import '../../viewport/viewport_metrics.dart';

/// Mounted only while the Training tab is selected. Leaving destroys the world.
class TrainingFieldTab extends StatefulWidget {
  const TrainingFieldTab({super.key});
  @override
  State<TrainingFieldTab> createState() => _TrainingFieldTabState();
}

class _TrainingFieldTabState extends State<TrainingFieldTab>
    with WidgetsBindingObserver {
  TrainingFieldSession? _session;
  late RunnerSemanticActionDispatcher _actions;
  RunnerDesktopInputController? _desktop;
  final _surfaceKey = GlobalKey();
  final _cancelRect = ValueNotifier<Rect?>(null);
  final _cancelSignal = ValueNotifier(0);
  final _impactSignal = ValueNotifier(0);
  EnemyId? _selectedEnemy;
  bool _started = false;
  bool _modal = false;
  bool _hostFailed = false;
  int _movementEpoch = 0;
  int _lastDamageTick = -1;
  bool get _usesDesktop =>
      RunnerControlScheme.automatic.resolve(defaultTargetPlatform) ==
      RunnerControlScheme.desktop;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_session == null) _createSession();
  }

  void _createSession() {
    final selection = context.read<AppState>().selection;
    final character = PlayerCharacterRegistry.resolve(
      selection.selectedCharacterId,
    );
    final session = TrainingFieldSession(
      character: character,
      loadout: selection.loadoutFor(character.id),
    );
    _session = session;
    _actions = RunnerSemanticActionDispatcher(
      input: session.input,
      resolveInputMode: (action) {
        final hud = session.controller.snapshot.hud;
        return switch (action) {
          RunnerGameplayAction.primary => hud.meleeInputMode,
          RunnerGameplayAction.secondary => hud.secondaryInputMode,
          RunnerGameplayAction.projectile => hud.projectileInputMode,
          RunnerGameplayAction.mobility => hud.mobilityInputMode,
          _ => AbilityInputMode.tap,
        };
      },
    );
    if (_usesDesktop) {
      _desktop = RunnerDesktopInputController(
        dispatcher: _actions,
        resolveAimGeometry: _aimGeometry,
        onFocusLost: _pause,
        onCancelPresentation: _clearPreviews,
      )..setEnabled(false);
    }
    session.addListener(_onLoaded);
    session.controller.addListener(_onTick);
  }

  RunnerDesktopAimGeometry? _aimGeometry() {
    final box = _surfaceKey.currentContext?.findRenderObject();
    final snapshot = _session!.controller.snapshot;
    final player = snapshot.playerEntity;
    if (box is! RenderBox || !box.hasSize || player == null) return null;
    return RunnerDesktopAimGeometry.fromWorld(
      metrics: computeViewportMetrics(
        BoxConstraints.tight(box.size),
        MediaQuery.devicePixelRatioOf(context),
        virtualWidth,
        virtualHeight,
        ViewportScaleMode.pixelPerfectContain,
      ),
      camera: snapshot.camera,
      playerWorldPosition: Offset(player.pos.x, player.pos.y),
    );
  }

  void _onLoaded() {
    final session = _session!;
    // Loading callbacks may originate inside Flame mounting. Fence this callback
    // against reset/unmount, and start only once the complete world is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(session, _session)) return;
      if (session.ready && !_started && _foreground && !_modal) {
        _started = true;
        session.controller.setPaused(false);
        _desktop?.requestFocus();
      }
      setState(() {});
    });
  }

  void _onTick() {
    final session = _session!;
    final snapshot = session.controller.snapshot;
    _desktop?.setEnabled(
      session.ready &&
          _started &&
          !snapshot.paused &&
          !snapshot.gameOver &&
          !_modal &&
          _foreground,
    );
    _desktop?.refreshPointerAim();
    if (snapshot.hud.lastDamageTick > _lastDamageTick) {
      _lastDamageTick = snapshot.hud.lastDamageTick;
      _impactSignal.value++;
      if (snapshot.hud.chargeActive) {
        _actions.clearAimDir();
        _clearPreviews();
        _cancelSignal.value++;
      }
    }
  }

  void _clearPreviews() {
    _session?.projectilePreview.end();
    _session?.meleePreview.end();
  }

  void _cancelInput() {
    _movementEpoch++;
    _desktop?.cancelAll();
    _actions.cancelAll();
    _clearPreviews();
    _cancelSignal.value++;
  }

  void _pause() {
    if (_session == null) return;
    _cancelInput();
    _session!.controller.setPaused(true);
  }

  void _resume() {
    if (!_foreground || _modal || !_session!.ready) return;
    _started = true;
    _session!.controller.setPaused(false);
    _desktop?.requestFocus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _pause();
    } else if (!_usesDesktop) {
      _resume();
    }
  }

  void _retireSession() {
    _cancelInput();
    _desktop?.dispose();
    _desktop = null;
    final session = _session!;
    session.removeListener(_onLoaded);
    session.controller.removeListener(_onTick);
    session.dispose();
    _session = null;
  }

  void _reset() {
    _retireSession();
    setState(() {
      _selectedEnemy = null;
      _hostFailed = false;
      _started = false;
      _lastDamageTick = -1;
      _createSession();
    });
  }

  Future<void> _chooseEnemy() async {
    final session = _session!;
    final wasRunning = !session.controller.snapshot.paused;
    _modal = true;
    _pause();
    var chosen = false;
    final enemy = await showDialog<EnemyId?>(
      context: context,
      builder: (context) {
        final defeats = context.watch<AppState>().progression.enemyDefeats;
        final enemies = CodexCatalog.bestiaryEntries.where(
          (id) => !id.isArenaOnly && CodexCatalog.enemyUnlocked(defeats, id),
        );
        return SimpleDialog(
          title: const Text('Training opponent'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                chosen = true;
                Navigator.pop(context);
              },
              child: const Text('None'),
            ),
            for (final id in enemies)
              SimpleDialogOption(
                onPressed: () {
                  chosen = true;
                  Navigator.pop(context, id);
                },
                child: Text(id.displayName),
              ),
            if (enemies.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unlock enemy entries in the Library to practise against them.',
                ),
              ),
          ],
        );
      },
    );
    if (!mounted || !identical(session, _session)) return;
    _modal = false;
    if (chosen &&
        (enemy == null ||
            CodexCatalog.enemyUnlocked(
              context.read<AppState>().progression.enemyDefeats,
              enemy,
            ))) {
      setState(() => _selectedEnemy = enemy);
      session.controller.selectTrainingEnemy(enemy);
    }
    if (wasRunning) _resume();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session!;
    final movement =
        context.watch<ControlSettings?>()?.movementMode ??
        MovementControlMode.arrows;
    return AnimatedBuilder(
      animation: session.controller,
      builder: (context, _) {
        final snapshot = session.controller.snapshot;
        final state = RunnerGameUiState(
          started: _started,
          paused: snapshot.paused,
          gameOver: snapshot.gameOver,
          runLoaded: session.ready,
        );
        return ScopedGameContextMenu(
          enabled: _usesDesktop,
          child: Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final view = GameViewport(
                    metrics: computeViewportMetrics(
                      constraints,
                      MediaQuery.devicePixelRatioOf(context),
                      virtualWidth,
                      virtualHeight,
                      ViewportScaleMode.pixelPerfectContain,
                    ),
                    child: GameWidget<RunnerFlameGame>(
                      key: ObjectKey(session),
                      game: session.game,
                      errorBuilder: (context, error) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted &&
                              identical(_session, session) &&
                              !_hostFailed) {
                            setState(() => _hostFailed = true);
                            _pause();
                          }
                        });
                        return const SizedBox.shrink();
                      },
                    ),
                  );
                  return SizedBox(
                    key: _surfaceKey,
                    child: _desktop == null
                        ? view
                        : RunnerDesktopInputAdapter(
                            controller: _desktop!,
                            child: view,
                          ),
                  );
                },
              ),
              if (session.ready)
                GameOverlay(
                  controller: session.controller,
                  input: _actions,
                  projectileAimPreview: session.projectilePreview,
                  meleeAimPreview: session.meleePreview,
                  aimCancelHitboxRect: _cancelRect,
                  forceAimCancelSignal: _cancelSignal,
                  playerImpactFeedbackSignal: _impactSignal,
                  uiState: state,
                  onStart: _resume,
                  onTogglePause: _pause,
                  showExitButton: false,
                  onExit: null,
                  exitConfirmOpen: false,
                  onExitConfirmResume: _resume,
                  onExitConfirmExit: () {},
                  trainingField: true,
                  movementControlMode: movement,
                  movementInputEpoch: _movementEpoch,
                  controlScheme: _usesDesktop
                      ? RunnerControlScheme.desktop
                      : RunnerControlScheme.touch,
                  resourcesTrailing: IconButton(
                    key: const ValueKey('training-enemy-settings'),
                    tooltip: _selectedEnemy == null
                        ? 'Choose training opponent'
                        : 'Opponent: ${_selectedEnemy!.displayName}',
                    onPressed: snapshot.gameOver ? null : _chooseEnemy,
                    icon: const Icon(Icons.settings),
                  ),
                ),
              if (snapshot.gameOver)
                Center(
                  child: FilledButton.icon(
                    key: const ValueKey('training-reset'),
                    onPressed: _reset,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset'),
                  ),
                )
              else if (session.ready && snapshot.paused && !_modal)
                Center(
                  child: FilledButton(
                    onPressed: _resume,
                    child: const Text('Resume'),
                  ),
                ),
              if (!session.ready && !session.failed && !_hostFailed)
                const Center(child: CircularProgressIndicator()),
              if (session.failed || _hostFailed)
                Center(
                  child: FilledButton(
                    onPressed: _reset,
                    child: const Text('Retry loading Training Field'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_session != null) _retireSession();
    _cancelRect.dispose();
    _cancelSignal.dispose();
    _impactSignal.dispose();
    super.dispose();
  }
}
