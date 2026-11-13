import 'package:game_presentation/enemy_text.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';

import '../../../game/game_controller.dart';
import '../../codex/codex_catalog.dart';
import '../../controls/movement_control_mode.dart';
import '../../haptics/haptics_service.dart';
import '../../hud/game/game_overlay.dart';
import '../../input/desktop/runner_desktop_aim_geometry.dart';
import '../../input/desktop/runner_desktop_input_adapter.dart';
import '../../input/runner_control_scheme.dart';
import '../../input/runner_gameplay_bindings.dart';
import '../../run/training_field_session.dart';
import '../../runner_game_ui_state.dart';
import '../../scoped/scoped_game_context_menu.dart';
import '../../state/app/app_state.dart';
import '../../state/settings/control_settings.dart';
import '../../theme/ui_tokens.dart';
import '../../runner_gameplay_surface.dart';
import 'training_opponent_dialog.dart';

/// Mounted only while the Training tab is selected. Leaving destroys the world.
class TrainingFieldTab extends StatefulWidget {
  const TrainingFieldTab({super.key, this.characterId, this.buildIndex});
  final PlayerCharacterId? characterId;
  final int? buildIndex;
  @override
  State<TrainingFieldTab> createState() => _TrainingFieldTabState();
}

class _TrainingFieldTabState extends State<TrainingFieldTab>
    with WidgetsBindingObserver {
  TrainingFieldSession? _session;
  late RunnerGameplayBindings _bindings;
  RunnerDesktopInputController? get _desktop => _bindings.desktop;
  final _surfaceKey = GlobalKey<RunnerGameplaySurfaceState>();
  EnemyId? _selectedEnemy;
  bool _started = false;
  bool _modal = false;
  bool _hostFailed = false;
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
    final app = context.read<AppState>();
    final selection = app.selection;
    final characterId = widget.characterId ?? selection.selectedCharacterId;
    if (!app.isCharacterUnlocked(characterId) ||
        !app.isBuildUnlocked(
          widget.buildIndex ?? selection.selectedBuildIndexFor(characterId),
        )) {
      return;
    }
    final character = PlayerCharacterRegistry.resolve(characterId);
    final session = TrainingFieldSession(
      character: character,
      loadout: selection.loadoutFor(
        character.id,
        buildIndex: widget.buildIndex,
      ),
    );
    _session = session;
    _bindings = RunnerGameplayBindings(
      controller: session.controller,
      input: session.input,
      projectilePreview: session.projectilePreview,
      meleePreview: session.meleePreview,
      haptics: const UiHapticsService(),
    );
    if (_usesDesktop) {
      _bindings.attachDesktop(
        resolveAimGeometry: _aimGeometry,
        onFocusLost: _pause,
      );
    }
    session.addListener(_onLoaded);
    session.controller.addListener(_onTick);
  }

  RunnerDesktopAimGeometry? _aimGeometry() {
    return _surfaceKey.currentState?.aimGeometry;
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
          session.controller.terrainReadiness != TerrainReadiness.failed &&
          !_modal &&
          _foreground,
    );
  }

  void _cancelInput() => _bindings.cancelAll();

  void _pause() {
    if (_session == null) return;
    _cancelInput();
    _session!.controller.setPaused(true);
  }

  void _resume() {
    final session = _session;
    if (session == null || !_foreground || _modal || !session.ready) return;
    _started = true;
    session.controller.setPaused(false);
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

  void _retireSession({bool afterUnmount = false}) {
    final bindings = _bindings..stop();
    final session = _session!;
    session.removeListener(_onLoaded);
    session.controller.removeListener(_onTick);
    session.stop();
    void release() {
      bindings.dispose();
      session.dispose();
    }

    if (afterUnmount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => release());
    } else {
      release();
    }
    _session = null;
  }

  void _reset() {
    _retireSession(afterUnmount: true);
    setState(() {
      _selectedEnemy = null;
      _hostFailed = false;
      _started = false;
      _modal = false;
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
      barrierColor: context.ui.colors.scrim,
      builder: (context) {
        final defeats = context.watch<AppState>().progression.enemyDefeats;
        final enemies = CodexCatalog.bestiaryEntries.where(
          (id) => !id.isArenaOnly && CodexCatalog.enemyUnlocked(defeats, id),
        );
        return TrainingOpponentDialog(
          enemies: enemies,
          selectedEnemy: _selectedEnemy,
          onSelected: (id) {
            chosen = true;
            Navigator.pop(context, id);
          },
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
    final session = _session;
    if (session == null) {
      return Center(child: Text(context.l10n.campaignWillowLocked));
    }
    final movement =
        context.watch<ControlSettings?>()?.movementMode ??
        MovementControlMode.arrows;
    return AnimatedBuilder(
      animation: Listenable.merge([session.controller, _bindings]),
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
          child: RunnerGameplaySurface(
            key: _surfaceKey,
            runtime: session.runtime,
            bindings: _bindings,
            onLoadError: (error) {
              if (mounted && identical(_session, session) && !_hostFailed) {
                setState(() => _hostFailed = true);
                _pause();
              }
            },
            overlayBuilder: (context, metrics) => Stack(
              fit: StackFit.expand,
              children: [
                if (session.ready)
                  GameOverlay(
                    viewportMetrics: metrics,
                    controller: session.controller,
                    input: _bindings.actions,
                    projectileAimPreview: session.projectilePreview,
                    meleeAimPreview: session.meleePreview,
                    aimCancelHitboxRect: _bindings.aimCancelHitboxRect,
                    forceAimCancelSignal: _bindings.forceAimCancelSignal,
                    playerImpactFeedbackSignal: _bindings.impactSignal,
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
                    movementInputEpoch: _bindings.movementEpoch,
                    controlScheme: _usesDesktop
                        ? RunnerControlScheme.desktop
                        : RunnerControlScheme.touch,
                    resourcesTrailing: IconButton(
                      key: const ValueKey('training-enemy-settings'),
                      tooltip: _selectedEnemy == null
                          ? context.l10n.uiChooseTrainingOpponent
                          : context.l10n.trainingOpponent(
                              enemy: enemyDisplayName(
                                _selectedEnemy!,
                                strings: context.gameL10n,
                              ),
                            ),
                      onPressed: snapshot.gameOver ? null : _chooseEnemy,
                      icon: const Icon(LucideIcons.skull),
                    ),
                  ),
                if (snapshot.gameOver)
                  Center(
                    child: FilledButton.icon(
                      key: const ValueKey('training-reset'),
                      onPressed: _reset,
                      icon: const Icon(Icons.restart_alt),
                      label: Text(context.l10n.uiReset),
                    ),
                  )
                else if (session.ready && snapshot.paused && !_modal)
                  Center(
                    child: FilledButton(
                      onPressed: _resume,
                      child: Text(context.l10n.uiResume),
                    ),
                  ),
                if (!session.ready && !session.failed && !_hostFailed)
                  const Center(child: CircularProgressIndicator()),
                if (session.failed || _hostFailed)
                  Center(
                    child: FilledButton(
                      onPressed: _reset,
                      child: Text(context.l10n.uiRetryLoadingTrainingField),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_session != null) _retireSession();
    super.dispose();
  }
}
