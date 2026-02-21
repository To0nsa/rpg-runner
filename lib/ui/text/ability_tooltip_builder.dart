import '../../core/abilities/ability_def.dart';
import '../../core/combat/status/status.dart';
import '../../core/projectiles/projectile_id.dart';
import 'ability_tag_resolver.dart';
import 'ability_text.dart';

abstract interface class StatusTextResolver {
  StatusText? describe(StatusProfileId id);
}

class StatusText {
  const StatusText({required this.name, this.durationSeconds});

  final String name;
  final double? durationSeconds;
}

class AbilityTooltipContext {
  const AbilityTooltipContext({
    this.selectedProjectileSpellId,
    this.payloadWeaponType,
    this.statusTextResolver,
  });

  final ProjectileId? selectedProjectileSpellId;
  final WeaponType? payloadWeaponType;
  final StatusTextResolver? statusTextResolver;
}

class AbilityTooltip {
  const AbilityTooltip({
    required this.title,
    required this.subtitle,
    this.badges = const <String>[],
    this.tags = const <AbilityUiTag>{},
  });

  final String title;
  final String subtitle;
  final List<String> badges;
  final Set<AbilityUiTag> tags;
}

abstract interface class AbilityTooltipBuilder {
  AbilityTooltip build(
    AbilityDef def, {
    AbilityTooltipContext ctx = const AbilityTooltipContext(),
  });
}

class DefaultAbilityTooltipBuilder implements AbilityTooltipBuilder {
  const DefaultAbilityTooltipBuilder({
    AbilityTagResolver tagResolver = const AbilityTagResolver(),
    StatusProfileCatalog statusProfiles = const StatusProfileCatalog(),
  }) : _tagResolver = tagResolver,
       _statusProfiles = statusProfiles;

  final AbilityTagResolver _tagResolver;
  final StatusProfileCatalog _statusProfiles;

  @override
  AbilityTooltip build(
    AbilityDef def, {
    AbilityTooltipContext ctx = const AbilityTooltipContext(),
  }) {
    final tags = _tagResolver.resolve(
      def,
      ctx: AbilityTagContext(
        payloadWeaponType: ctx.payloadWeaponType,
        resolveResourceForContextOnly: true,
      ),
    );
    final badges = _buildBadges(def, tags);
    return AbilityTooltip(
      title: abilityDisplayName(def.id),
      subtitle: _buildSubtitle(def, tags, ctx),
      badges: List<String>.unmodifiable(badges),
      tags: tags,
    );
  }

  List<String> _buildBadges(AbilityDef def, Set<AbilityUiTag> tags) {
    final badges = <String>[];

    void addBadge(String value) {
      if (!badges.contains(value)) badges.add(value);
    }

    for (final tag in AbilityUiTag.values) {
      if (!tags.contains(tag)) continue;
      final label = _badgeLabel(tag);
      if (label != null) addBadge(label);
    }

    if (def.hitDelivery is ProjectileHitDelivery) {
      final delivery = def.hitDelivery as ProjectileHitDelivery;
      if (delivery.pierce) addBadge('Pierce');
      if (delivery.chain || delivery.chainCount > 0) addBadge('Chain');
    }
    if (def.damageIgnoredBp >= 10000) addBadge('Block');
    if (def.grantsRiposteOnGuardedHit) addBadge('Riposte');

    return badges;
  }

  String _buildSubtitle(
    AbilityDef def,
    Set<AbilityUiTag> tags,
    AbilityTooltipContext ctx,
  ) {
    final inputHint = switch (def.inputLifecycle) {
      AbilityInputLifecycle.tap => 'Tap',
      AbilityInputLifecycle.holdRelease => 'Hold then release',
      AbilityInputLifecycle.holdMaintain => 'Hold',
    };

    if (tags.contains(AbilityUiTag.guard)) {
      final pct = (def.damageIgnoredBp / 100).round();
      if (def.holdMode == AbilityHoldMode.holdToMaintain) {
        return '$inputHint to guard and reduce damage by $pct% while held.';
      }
      return '$inputHint to guard and reduce damage by $pct%.';
    }

    if (def.selfStatusProfileId != StatusProfileId.none) {
      final statusText = ctx.statusTextResolver?.describe(
        def.selfStatusProfileId,
      );
      final fallback = _describeStatusFromProfile(def.selfStatusProfileId);
      final resolved = statusText ?? fallback;
      if (resolved != null) {
        final duration = resolved.durationSeconds;
        if (duration == null) return '$inputHint to gain ${resolved.name}.';
        return '$inputHint to gain ${resolved.name} for ${duration.toStringAsFixed(1)}s.';
      }
      return '$inputHint to apply a self effect.';
    }

    if (def.mobilitySpeedX != null ||
        def.allowedSlots.contains(AbilitySlot.jump)) {
      return '$inputHint to reposition quickly.';
    }

    if (tags.contains(AbilityUiTag.charged)) {
      return '$inputHint to charge for a stronger release.';
    }

    return switch (def.category) {
      AbilityCategory.melee => '$inputHint to strike in front of you.',
      AbilityCategory.ranged =>
        ctx.selectedProjectileSpellId != null
            ? '$inputHint to fire the selected spell projectile.'
            : '$inputHint to fire your equipped projectile.',
      AbilityCategory.defense => '$inputHint to defend.',
      AbilityCategory.utility => '$inputHint to cast a utility effect.',
      AbilityCategory.mobility => '$inputHint to move.',
    };
  }

  StatusText? _describeStatusFromProfile(StatusProfileId id) {
    if (id == StatusProfileId.none) return null;
    final profile = _statusProfiles.get(id);
    if (profile.applications.isEmpty) return null;

    final first = profile.applications.first;
    return StatusText(
      name: _statusName(id),
      durationSeconds: first.durationSeconds,
    );
  }

  String _statusName(StatusProfileId id) {
    switch (id) {
      case StatusProfileId.none:
        return 'Effect';
      case StatusProfileId.slowOnHit:
        return 'Slow';
      case StatusProfileId.burnOnHit:
        return 'Burn';
      case StatusProfileId.acidOnHit:
        return 'Vulnerable';
      case StatusProfileId.weakenOnHit:
        return 'Weaken';
      case StatusProfileId.drenchOnHit:
        return 'Drench';
      case StatusProfileId.silenceOnHit:
        return 'Silence';
      case StatusProfileId.meleeBleed:
        return 'Bleed';
      case StatusProfileId.stunOnHit:
        return 'Stun';
      case StatusProfileId.speedBoost:
        return 'Haste';
      case StatusProfileId.restoreHealth:
        return 'Health Regen';
      case StatusProfileId.restoreMana:
        return 'Mana Regen';
      case StatusProfileId.restoreStamina:
        return 'Stamina Regen';
    }
  }

  String? _badgeLabel(AbilityUiTag tag) {
    switch (tag) {
      case AbilityUiTag.offense:
        return 'Offense';
      case AbilityUiTag.defense:
        return 'Defense';
      case AbilityUiTag.mobility:
        return 'Mobility';
      case AbilityUiTag.sustain:
        return 'Sustain';
      case AbilityUiTag.utility:
        return 'Utility';
      case AbilityUiTag.singleTarget:
        return 'Single-target';
      case AbilityUiTag.multiTarget:
        return 'Multi-target';
      case AbilityUiTag.crowdControl:
        return 'CC';
      case AbilityUiTag.dot:
        return 'DoT';
      case AbilityUiTag.burst:
        return 'Burst';
      case AbilityUiTag.charged:
        return 'Charge';
      case AbilityUiTag.staminaSpend:
        return 'Stamina';
      case AbilityUiTag.manaSpend:
        return 'Mana';
      case AbilityUiTag.healthSpend:
        return 'Health';
      case AbilityUiTag.channel:
        return 'Channel';
      case AbilityUiTag.guard:
        return 'Guard';
      case AbilityUiTag.riposte:
        return 'Riposte';
      case AbilityUiTag.autoTarget:
        return 'Auto-target';
      case AbilityUiTag.aimed:
        return 'Aimed';
    }
  }
}
