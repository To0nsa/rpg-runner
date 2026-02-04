import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../../../core/projectiles/projectile_item_id.dart';
import '../../app/ui_routes.dart';
import '../../components/app_button.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app_state.dart';
import '../../state/selection_state.dart';

class LoadoutSetupPage extends StatelessWidget {
  const LoadoutSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final selection = appState.selection;
    final loadout = selection.equippedLoadout;

    return MenuScaffold(
      title: 'Setup Loadout',
      child: MenuLayout(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Build Name',
              style: TextStyle(color: Colors.white70, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            _BuildNameField(
              buildName: selection.buildName,
              onCommit: appState.setBuildName,
            ),
            const SizedBox(height: 20),
            Text(
              'Current Loadout',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            _LoadoutSummary(loadout: loadout),
            const SizedBox(height: 24),
            const Text(
              'Quick Presets',
              style: TextStyle(color: Colors.white70, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                AppButton(
                  label: 'Default',
                  onPressed: () =>
                      appState.setLoadout(const EquippedLoadoutDef()),
                ),
                AppButton(
                  label: 'Fire Bolt',
                  onPressed: () => appState.setLoadout(
                    _withProjectile(
                      loadout,
                      ProjectileItemId.fireBolt,
                      'eloise.fire_bolt',
                    ),
                  ),
                ),
                AppButton(
                  label: 'Thunder Bolt',
                  onPressed: () => appState.setLoadout(
                    _withProjectile(
                      loadout,
                      ProjectileItemId.thunderBolt,
                      'eloise.thunder_bolt',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                AppButton(
                  label: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 12),
                AppButton(
                  label: 'Level',
                  onPressed: () =>
                      Navigator.of(context).pushNamed(UiRoutes.setupLevel),
                ),
                const SizedBox(width: 12),
                AppButton(
                  label: 'Try Lab',
                  onPressed: () =>
                      Navigator.of(context).pushNamed(UiRoutes.loadoutLab),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

EquippedLoadoutDef _withProjectile(
  EquippedLoadoutDef base,
  ProjectileItemId projectileItemId,
  String abilityProjectileId,
) {
  return EquippedLoadoutDef(
    mask: base.mask,
    mainWeaponId: base.mainWeaponId,
    offhandWeaponId: base.offhandWeaponId,
    projectileItemId: projectileItemId,
    abilityPrimaryId: base.abilityPrimaryId,
    abilitySecondaryId: base.abilitySecondaryId,
    abilityProjectileId: abilityProjectileId,
    abilityBonusId: base.abilityBonusId,
    abilityMobilityId: base.abilityMobilityId,
    abilityJumpId: base.abilityJumpId,
  );
}

class _BuildNameField extends StatefulWidget {
  const _BuildNameField({required this.buildName, required this.onCommit});

  final String buildName;
  final ValueChanged<String> onCommit;

  @override
  State<_BuildNameField> createState() => _BuildNameFieldState();
}

class _BuildNameFieldState extends State<_BuildNameField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.buildName);
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _BuildNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus &&
        oldWidget.buildName != widget.buildName &&
        _controller.text != widget.buildName) {
      _controller.text = widget.buildName;
    }
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    widget.onCommit(_controller.text);
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLength: SelectionState.buildNameMaxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _commit(),
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: SelectionState.defaultBuildName,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF0E131D),
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: Colors.white70),
        ),
        counterStyle: const TextStyle(color: Colors.white38, fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}

class _LoadoutSummary extends StatelessWidget {
  const _LoadoutSummary({required this.loadout});

  final EquippedLoadoutDef loadout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Primary: ${loadout.abilityPrimaryId}',
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            'Secondary: ${loadout.abilitySecondaryId}',
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            'Projectile: ${loadout.abilityProjectileId}',
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            'Mobility: ${loadout.abilityMobilityId}',
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            'Bonus: ${loadout.abilityBonusId}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
