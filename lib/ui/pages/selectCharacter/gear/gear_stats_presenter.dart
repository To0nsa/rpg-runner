import 'package:game_presentation/game_localization.dart';
import 'package:game_presentation/stat_text.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localization.dart';

import 'package:runner_core/accessories/accessory_catalog.dart';
import 'package:runner_core/accessories/accessory_def.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/combat/status/status.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/spellBook/spell_book_catalog.dart';
import 'package:runner_core/spellBook/spell_book_def.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/stats/character_stat_id.dart';
import 'package:runner_core/stats/gear_stat_bonuses.dart';
import 'package:runner_core/weapons/weapon_def.dart';
import 'package:runner_core/weapons/weapon_id.dart';
import 'package:runner_core/weapons/weapon_catalog.dart';
import 'package:runner_core/weapons/weapon_proc.dart';
import 'package:runner_core/weapons/reactive_proc.dart';

import '../../../text/semantic_text.dart';

typedef GearStatLineTone = UiSemanticTone;
typedef GearStatHighlight = UiSemanticHighlight;

/// Display-ready stat row used by the stats panel.
class GearStatLine {
  const GearStatLine(
    this.label,
    this.value, {
    this.tone = GearStatLineTone.neutral,
    this.highlights = const <GearStatHighlight>[],
    this.semanticValue,
    this.forcePositiveHighlightTones = false,
  });

  final String label;
  final String value;
  final GearStatLineTone tone;
  final List<GearStatHighlight> highlights;
  final UiSemanticText? semanticValue;
  final bool forcePositiveHighlightTones;
}

/// Builds locale-bound display values without changing Core stats.
List<GearStatLine> gearStatsFor(
  GearSlot slot,
  Object id, {
  required AppLocalizations l10n,
  required GameLocalizations strings,
  ManaPresentation manaPresentation = ManaPresentation.mana,
}) => _GearStatsPresenter(
  l10n,
  strings,
  manaPresentation,
)._gearStatsFor(slot, id);

List<GearStatLine> gearCompareStats(
  GearSlot slot, {
  required Object equipped,
  required Object candidate,
  required AppLocalizations l10n,
  required GameLocalizations strings,
  ManaPresentation manaPresentation = ManaPresentation.mana,
}) => _GearStatsPresenter(
  l10n,
  strings,
  manaPresentation,
)._gearCompareStats(slot, equipped: equipped, candidate: candidate);

String gearCompareEmptyText({
  required Object? selectedId,
  required Object? equippedForCompare,
  required AppLocalizations l10n,
}) => selectedId != null && selectedId == equippedForCompare
    ? l10n.gearCompareEquipped
    : l10n.gearCompareSame;

class _GearStatsPresenter {
  const _GearStatsPresenter(this.l10n, this.strings, this.manaPresentation);
  final AppLocalizations l10n;
  final GameLocalizations strings;
  final ManaPresentation manaPresentation;

  List<GearStatLine> _gearStatsFor(GearSlot slot, Object id) {
    switch (slot) {
      case GearSlot.mainWeapon:
      case GearSlot.offhandWeapon:
        final def = const WeaponCatalog().get(id as WeaponId);
        return _weaponDefStats(def);
      case GearSlot.spellBook:
        final def = const SpellBookCatalog().get(id as SpellBookId);
        return _spellBookStats(def);
      case GearSlot.accessory:
        final def = const AccessoryCatalog().get(id as AccessoryId);
        return _accessoryStats(def);
    }
  }

  List<GearStatLine> _gearCompareStats(
    GearSlot slot, {
    required Object equipped,
    required Object candidate,
  }) {
    if (equipped == candidate) return const <GearStatLine>[];
    switch (slot) {
      case GearSlot.mainWeapon:
      case GearSlot.offhandWeapon:
        final a = const WeaponCatalog().get(equipped as WeaponId);
        final b = const WeaponCatalog().get(candidate as WeaponId);
        return _diffWeaponStats(a, b);
      case GearSlot.spellBook:
        final a = const SpellBookCatalog().get(equipped as SpellBookId);
        final b = const SpellBookCatalog().get(candidate as SpellBookId);
        return _diffWeaponStatsLike(
          a.stats,
          b.stats,
          equippedProcs: a.procs,
          candidateProcs: b.procs,
        );
      case GearSlot.accessory:
        final a = const AccessoryCatalog().get(equipped as AccessoryId);
        final b = const AccessoryCatalog().get(candidate as AccessoryId);
        return _diffAccessoryStats(a, b);
    }
  }

  List<GearStatLine> _weaponDefStats(WeaponDef def) {
    final stats = def.stats;
    final lines = <GearStatLine>[];
    _addCoreStatLines(lines, stats);
    lines.addAll(_buildProcHookLines(def.procs));
    lines.addAll(_buildReactiveProcHookLines(def.reactiveProcs));
    return _withNegativeLinesFirst(lines);
  }

  List<GearStatLine> _spellBookStats(SpellBookDef def) {
    final stats = def.stats;
    final lines = <GearStatLine>[];
    _addCoreStatLines(lines, stats);
    lines.addAll(_buildProcHookLines(def.procs));
    return _withNegativeLinesFirst(lines);
  }

  List<GearStatLine> _accessoryStats(AccessoryDef def) {
    final stats = def.stats;
    final lines = <GearStatLine>[];
    _addCoreStatLines(lines, stats);
    lines.addAll(_buildReactiveProcHookLines(def.reactiveProcs));
    return _withNegativeLinesFirst(lines);
  }

  List<GearStatLine> _withNegativeLinesFirst(List<GearStatLine> lines) {
    if (lines.length < 2) return lines;
    final negatives = <GearStatLine>[];
    final others = <GearStatLine>[];
    for (final line in lines) {
      if (line.tone == GearStatLineTone.negative) {
        negatives.add(line);
        continue;
      }
      others.add(line);
    }
    if (negatives.isEmpty) return lines;
    return <GearStatLine>[...negatives, ...others];
  }

  void _addBpStat(List<GearStatLine> lines, String label, int value) {
    if (value == 0) return;
    lines.add(GearStatLine(label, _bpPct(value), tone: _toneForDelta(value)));
  }

  List<GearStatLine> _buildProcHookLines(List<WeaponProc> procs) {
    if (procs.isEmpty) return const <GearStatLine>[];
    const profiles = StatusProfileCatalog();
    final hooks = <ProcHook>[];
    final procLines = <GearStatLine>[];
    for (final proc in procs) {
      if (hooks.contains(proc.hook)) continue;
      hooks.add(proc.hook);
    }
    for (final hook in hooks) {
      for (final proc in procs) {
        if (proc.hook != hook || proc.statusProfileId == StatusProfileId.none) {
          continue;
        }
        final profile = profiles.resolve(
          proc.statusProfileId,
          tuning: proc.statusTuning,
        );
        for (final app in profile.applications) {
          final summary = _procEffectSummary(app, proc);
          if (summary == null) continue;
          procLines.add(
            GearStatLine(
              _procHookLabel(hook),
              summary.text,
              highlights: summary.highlights,
              semanticValue: UiSemanticText.single(
                summary.text,
                highlights: summary.highlights,
              ),
              forcePositiveHighlightTones: true,
            ),
          );
        }
      }
    }
    return procLines;
  }

  List<GearStatLine> _buildReactiveProcHookLines(List<ReactiveProc> procs) {
    if (procs.isEmpty) return const <GearStatLine>[];
    const profiles = StatusProfileCatalog();
    final hooks = <ReactiveProcHook>[];
    final procLines = <GearStatLine>[];
    for (final proc in procs) {
      if (hooks.contains(proc.hook)) continue;
      hooks.add(proc.hook);
    }
    for (final hook in hooks) {
      for (final proc in procs) {
        if (proc.hook != hook || proc.statusProfileId == StatusProfileId.none) {
          continue;
        }
        final profile = profiles.resolve(
          proc.statusProfileId,
          tuning: proc.statusTuning,
        );
        for (final app in profile.applications) {
          final summary = _reactiveProcEffectSummary(app, proc);
          if (summary == null) continue;
          procLines.add(
            GearStatLine(
              _reactiveProcHookLabel(hook),
              summary.text,
              highlights: summary.highlights,
              semanticValue: UiSemanticText.single(
                summary.text,
                highlights: summary.highlights,
              ),
              forcePositiveHighlightTones: true,
            ),
          );
        }
      }
    }
    return procLines;
  }

  String _procHookLabel(ProcHook hook) {
    return switch (hook) {
      ProcHook.onHit => l10n.gearOnHit,
      ProcHook.onCrit => l10n.gearOnCrit,
      ProcHook.onKill => l10n.gearOnKill,
      ProcHook.onBlock => l10n.gearOnBlock,
    };
  }

  String _reactiveProcHookLabel(ReactiveProcHook hook) {
    return switch (hook) {
      ReactiveProcHook.onDamaged => l10n.gearOnDamaged,
      ReactiveProcHook.onLowHealth => l10n.gearOnLowHealth,
    };
  }

  _ProcEffectSummary? _procEffectSummary(
    StatusApplication app,
    WeaponProc proc,
  ) {
    return _procEffectSummaryFromProfile(
      app,
      statusProfileId: proc.statusProfileId,
      chanceBp: proc.chanceBp,
    );
  }

  _ProcEffectSummary? _reactiveProcEffectSummary(
    StatusApplication app,
    ReactiveProc proc,
  ) {
    return _procEffectSummaryFromProfile(
      app,
      statusProfileId: proc.statusProfileId,
      chanceBp: proc.chanceBp,
    );
  }

  _ProcEffectSummary? _procEffectSummaryFromProfile(
    StatusApplication app, {
    required StatusProfileId statusProfileId,
    required int chanceBp,
  }) {
    final duration = strings.durationSeconds(
      seconds: (app.durationSeconds * 10).round() / 10,
    );
    final amount = _formatPercentFromBp(app.magnitude);
    final damage = _formatFixed100(app.magnitude);
    final chance = _formatPercentFromBp(chanceBp);
    final chanceKind = chanceBp >= 10000 ? 'guaranteed' : 'chance';
    final resource = switch (app.resourceType) {
      StatusResourceType.health => strings.statHealth,
      StatusResourceType.mana => strings.statMana(
        resource: manaPresentation.name,
      ),
      StatusResourceType.stamina => strings.statStamina,
      null => strings.resourceGeneric,
    };
    final crit = _formatPercentFromBp(app.critBonusBp ?? 0);
    final status = statusProfileId == StatusProfileId.meleeBleed
        ? strings.effectBleed
        : strings.effectBurn;
    final statusLabel = switch (app.type) {
      StatusEffectType.slow => l10n.gearStatusSlow,
      StatusEffectType.stun => l10n.gearStatusStun,
      StatusEffectType.silence => l10n.gearStatusSilence,
      StatusEffectType.vulnerable => l10n.gearStatusVulnerable,
      StatusEffectType.weaken => l10n.gearStatusWeaken,
      StatusEffectType.drench => l10n.gearStatusDrench,
      StatusEffectType.haste => l10n.gearStatusHaste,
      StatusEffectType.damageReduction => l10n.gearStatusDamageReduction,
      StatusEffectType.offenseBuff => l10n.gearStatusOffenseBuff,
      StatusEffectType.dot => status,
      StatusEffectType.resourceOverTime => resource,
    };
    final text = switch (app.type) {
      StatusEffectType.dot => l10n.gearProcDot(
        status: status,
        damage: damage,
        duration: duration,
        chance: chance,
        chanceKind: chanceKind,
      ),
      StatusEffectType.slow => l10n.gearProcSlow(
        amount: amount,
        duration: duration,
        chance: chance,
        chanceKind: chanceKind,
      ),
      StatusEffectType.stun => l10n.gearProcStun(
        duration: duration,
        chance: chance,
        chanceKind: chanceKind,
      ),
      StatusEffectType.silence => l10n.gearProcSilence(
        duration: duration,
        chance: chance,
        chanceKind: chanceKind,
      ),
      StatusEffectType.vulnerable => l10n.gearProcVulnerable(
        amount: amount,
        duration: duration,
        chance: chance,
        chanceKind: chanceKind,
      ),
      StatusEffectType.weaken => l10n.gearProcWeaken(
        amount: amount,
        duration: duration,
        chance: chance,
        chanceKind: chanceKind,
      ),
      StatusEffectType.drench => l10n.gearProcDrench(
        amount: amount,
        duration: duration,
        chance: chance,
        chanceKind: chanceKind,
      ),
      StatusEffectType.haste => l10n.gearProcHaste(
        amount: amount,
        duration: duration,
        chance: chance,
        chanceKind: chanceKind,
      ),
      StatusEffectType.damageReduction => l10n.gearProcDamageReduction(
        amount: amount,
        duration: duration,
        chance: chance,
        chanceKind: chanceKind,
      ),
      StatusEffectType.resourceOverTime =>
        app.applyOnApply
            ? app.durationSeconds > 0
                  ? l10n.gearProcRestoreBoth(
                      resource: resource,
                      amount: amount,
                      duration: duration,
                      chance: chance,
                      chanceKind: chanceKind,
                    )
                  : l10n.gearProcRestoreInstant(
                      resource: resource,
                      amount: amount,
                      chance: chance,
                      chanceKind: chanceKind,
                    )
            : l10n.gearProcRestore(
                resource: resource,
                amount: amount,
                duration: duration,
                chance: chance,
                chanceKind: chanceKind,
              ),
      StatusEffectType.offenseBuff => l10n.gearProcOffense(
        amount: amount,
        crit: crit,
        critKind: app.critBonusBp == null ? 'none' : 'withCrit',
        duration: duration,
        chance: chance,
        chanceKind: chanceKind,
      ),
    };
    final positive = switch (app.type) {
      StatusEffectType.haste ||
      StatusEffectType.damageReduction ||
      StatusEffectType.resourceOverTime ||
      StatusEffectType.offenseBuff => true,
      _ => false,
    };
    return _ProcEffectSummary(
      text: text,
      highlights: _highlightsForTokens(
        tone: positive ? GearStatLineTone.positive : GearStatLineTone.negative,
        tokens: [
          statusLabel,
          duration,
          amount,
          if (app.type == StatusEffectType.dot) ...[status, damage],
          if (app.type == StatusEffectType.resourceOverTime) resource,
          if (app.critBonusBp != null) crit,
          if (chanceBp < 10000) chance,
        ],
      ),
    );
  }

  List<GearStatHighlight> _highlightsForTokens({
    required GearStatLineTone tone,
    required List<String> tokens,
  }) {
    return <GearStatHighlight>[
      for (final token in tokens)
        if (token.isNotEmpty) GearStatHighlight(token, tone: tone),
    ];
  }

  String _formatPercentFromBp(int bp) => (NumberFormat.percentPattern(
    strings.localeName,
  )..maximumFractionDigits = 1).format(bp / 10000.0);
  String _formatFixed100(int value100) =>
      NumberFormat.decimalPattern(strings.localeName).format(value100 / 100.0);

  List<GearStatLine> _diffWeaponStats(WeaponDef equipped, WeaponDef candidate) {
    return _diffWeaponStatsLike(
      equipped.stats,
      candidate.stats,
      equippedProcs: equipped.procs,
      candidateProcs: candidate.procs,
      equippedReactiveProcs: equipped.reactiveProcs,
      candidateReactiveProcs: candidate.reactiveProcs,
    );
  }

  List<GearStatLine> _diffWeaponStatsLike(
    GearStatBonuses a,
    GearStatBonuses b, {
    List<WeaponProc> equippedProcs = const <WeaponProc>[],
    List<WeaponProc> candidateProcs = const <WeaponProc>[],
    List<ReactiveProc> equippedReactiveProcs = const <ReactiveProc>[],
    List<ReactiveProc> candidateReactiveProcs = const <ReactiveProc>[],
  }) {
    final lines = _diffStatBonuses(a, b);
    lines.addAll(
      _diffProcHookLines(
        equippedProcs: equippedProcs,
        candidateProcs: candidateProcs,
      ),
    );
    lines.addAll(
      _diffReactiveProcHookLines(
        equippedProcs: equippedReactiveProcs,
        candidateProcs: candidateReactiveProcs,
      ),
    );
    return lines;
  }

  List<GearStatLine> _diffAccessoryStats(AccessoryDef a, AccessoryDef b) {
    final lines = _diffStatBonuses(a.stats, b.stats);
    lines.addAll(
      _diffReactiveProcHookLines(
        equippedProcs: a.reactiveProcs,
        candidateProcs: b.reactiveProcs,
      ),
    );
    return lines;
  }

  List<GearStatLine> _diffProcHookLines({
    required List<WeaponProc> equippedProcs,
    required List<WeaponProc> candidateProcs,
  }) {
    final equippedByHook = _procSummariesByHook(equippedProcs);
    final candidateByHook = _procSummariesByHook(candidateProcs);
    final lines = <GearStatLine>[];
    for (final hook in ProcHook.values) {
      final removed = _summaryDifferenceWithCounts(
        equippedByHook[hook] ?? const <_ProcEffectSummary>[],
        candidateByHook[hook] ?? const <_ProcEffectSummary>[],
      );
      final added = _summaryDifferenceWithCounts(
        candidateByHook[hook] ?? const <_ProcEffectSummary>[],
        equippedByHook[hook] ?? const <_ProcEffectSummary>[],
      );
      if (removed.isEmpty && added.isEmpty) continue;
      final parts = <String>[];
      final segments = <UiSemanticTextSegment>[];
      final highlights = <GearStatHighlight>[];
      if (removed.isNotEmpty) {
        final section = l10n.gearCompareLose(
          effects: _joinSummaryTexts(removed),
        );
        final sectionHighlights = _retoneSummaryHighlights(
          removed,
          tone: GearStatLineTone.negative,
        );
        parts.add(section);
        highlights.addAll(sectionHighlights);
        segments.add(
          UiSemanticTextSegment(section, highlights: sectionHighlights),
        );
      }
      if (added.isNotEmpty) {
        final section = l10n.gearCompareAdd(effects: _joinSummaryTexts(added));
        final sectionHighlights = _retoneSummaryHighlights(
          added,
          tone: GearStatLineTone.positive,
        );
        parts.add(section);
        highlights.addAll(sectionHighlights);
        segments.add(
          UiSemanticTextSegment(section, highlights: sectionHighlights),
        );
      }
      lines.add(
        GearStatLine(
          _procHookLabel(hook),
          parts.join(' | '),
          highlights: highlights,
          semanticValue: UiSemanticText(
            segments: segments,
            segmentSeparator: ' | ',
          ),
        ),
      );
    }
    return lines;
  }

  List<GearStatLine> _diffReactiveProcHookLines({
    required List<ReactiveProc> equippedProcs,
    required List<ReactiveProc> candidateProcs,
  }) {
    final equippedByHook = _reactiveProcSummariesByHook(equippedProcs);
    final candidateByHook = _reactiveProcSummariesByHook(candidateProcs);
    final lines = <GearStatLine>[];
    for (final hook in ReactiveProcHook.values) {
      final removed = _summaryDifferenceWithCounts(
        equippedByHook[hook] ?? const <_ProcEffectSummary>[],
        candidateByHook[hook] ?? const <_ProcEffectSummary>[],
      );
      final added = _summaryDifferenceWithCounts(
        candidateByHook[hook] ?? const <_ProcEffectSummary>[],
        equippedByHook[hook] ?? const <_ProcEffectSummary>[],
      );
      if (removed.isEmpty && added.isEmpty) continue;
      final parts = <String>[];
      final segments = <UiSemanticTextSegment>[];
      final highlights = <GearStatHighlight>[];
      if (removed.isNotEmpty) {
        final section = l10n.gearCompareLose(
          effects: _joinSummaryTexts(removed),
        );
        final sectionHighlights = _retoneSummaryHighlights(
          removed,
          tone: GearStatLineTone.negative,
        );
        parts.add(section);
        highlights.addAll(sectionHighlights);
        segments.add(
          UiSemanticTextSegment(section, highlights: sectionHighlights),
        );
      }
      if (added.isNotEmpty) {
        final section = l10n.gearCompareAdd(effects: _joinSummaryTexts(added));
        final sectionHighlights = _retoneSummaryHighlights(
          added,
          tone: GearStatLineTone.positive,
        );
        parts.add(section);
        highlights.addAll(sectionHighlights);
        segments.add(
          UiSemanticTextSegment(section, highlights: sectionHighlights),
        );
      }
      lines.add(
        GearStatLine(
          _reactiveProcHookLabel(hook),
          parts.join(' | '),
          highlights: highlights,
          semanticValue: UiSemanticText(
            segments: segments,
            segmentSeparator: ' | ',
          ),
        ),
      );
    }
    return lines;
  }

  Map<ProcHook, List<_ProcEffectSummary>> _procSummariesByHook(
    List<WeaponProc> procs,
  ) {
    if (procs.isEmpty) return const <ProcHook, List<_ProcEffectSummary>>{};
    const profiles = StatusProfileCatalog();
    final byHook = <ProcHook, List<_ProcEffectSummary>>{};
    for (final proc in procs) {
      if (proc.statusProfileId == StatusProfileId.none) continue;
      final profile = profiles.resolve(
        proc.statusProfileId,
        tuning: proc.statusTuning,
      );
      for (final app in profile.applications) {
        final summary = _procEffectSummary(app, proc);
        if (summary == null) continue;
        byHook
            .putIfAbsent(proc.hook, () => <_ProcEffectSummary>[])
            .add(summary);
      }
    }
    return byHook;
  }

  Map<ReactiveProcHook, List<_ProcEffectSummary>> _reactiveProcSummariesByHook(
    List<ReactiveProc> procs,
  ) {
    if (procs.isEmpty) {
      return const <ReactiveProcHook, List<_ProcEffectSummary>>{};
    }
    const profiles = StatusProfileCatalog();
    final byHook = <ReactiveProcHook, List<_ProcEffectSummary>>{};
    for (final proc in procs) {
      if (proc.statusProfileId == StatusProfileId.none) continue;
      final profile = profiles.resolve(
        proc.statusProfileId,
        tuning: proc.statusTuning,
      );
      for (final app in profile.applications) {
        final summary = _reactiveProcEffectSummary(app, proc);
        if (summary == null) continue;
        byHook
            .putIfAbsent(proc.hook, () => <_ProcEffectSummary>[])
            .add(summary);
      }
    }
    return byHook;
  }

  String _joinSummaryTexts(List<_ProcEffectSummary> summaries) {
    return summaries.map((summary) => summary.text).join('; ');
  }

  List<GearStatHighlight> _retoneSummaryHighlights(
    List<_ProcEffectSummary> summaries, {
    required GearStatLineTone tone,
  }) {
    final highlights = <GearStatHighlight>[];
    for (final summary in summaries) {
      for (final highlight in summary.highlights) {
        highlights.add(GearStatHighlight(highlight.token, tone: tone));
      }
    }
    return highlights;
  }

  List<_ProcEffectSummary> _summaryDifferenceWithCounts(
    List<_ProcEffectSummary> source,
    List<_ProcEffectSummary> other,
  ) {
    if (source.isEmpty) return const <_ProcEffectSummary>[];
    if (other.isEmpty) return List<_ProcEffectSummary>.of(source);
    final otherCounts = <String, int>{};
    for (final summary in other) {
      otherCounts[summary.text] = (otherCounts[summary.text] ?? 0) + 1;
    }
    final result = <_ProcEffectSummary>[];
    for (final summary in source) {
      final count = otherCounts[summary.text] ?? 0;
      if (count > 0) {
        otherCounts[summary.text] = count - 1;
        continue;
      }
      result.add(summary);
    }
    return result;
  }

  void _addCoreStatLines(List<GearStatLine> lines, GearStatBonuses stats) {
    _addBpStat(lines, _labelFor(CharacterStatId.health), stats.healthBonusBp);
    _addBpStat(lines, _labelFor(CharacterStatId.mana), stats.manaBonusBp);
    _addBpStat(lines, _labelFor(CharacterStatId.stamina), stats.staminaBonusBp);
    _addBpStat(
      lines,
      _labelFor(CharacterStatId.healthRegen),
      stats.healthRegenBonusBp,
    );
    _addBpStat(
      lines,
      _labelFor(CharacterStatId.manaRegen),
      stats.manaRegenBonusBp,
    );
    _addBpStat(
      lines,
      _labelFor(CharacterStatId.staminaRegen),
      stats.staminaRegenBonusBp,
    );
    _addBpStat(lines, _labelFor(CharacterStatId.defense), stats.defenseBonusBp);
    _addBpStat(
      lines,
      _labelFor(CharacterStatId.power),
      _effectivePowerBp(stats),
    );
    _addBpStat(
      lines,
      _labelFor(CharacterStatId.moveSpeed),
      stats.moveSpeedBonusBp,
    );
    _addBpStat(
      lines,
      _labelFor(CharacterStatId.cooldownReduction),
      stats.cooldownReductionBp,
    );
    _addBpStat(
      lines,
      _labelFor(CharacterStatId.critChance),
      _effectiveCritChanceBp(stats),
    );
    _addBpStat(
      lines,
      _labelFor(CharacterStatId.physicalResistance),
      stats.physicalResistanceBp,
    );
    _addBpStat(
      lines,
      _labelFor(CharacterStatId.fireResistance),
      stats.fireResistanceBp,
    );
    _addBpStat(
      lines,
      _labelFor(CharacterStatId.iceResistance),
      stats.iceResistanceBp,
    );
    _addBpStat(
      lines,
      _labelFor(CharacterStatId.waterResistance),
      stats.waterResistanceBp,
    );
    _addBpStat(
      lines,
      _labelFor(CharacterStatId.thunderResistance),
      stats.thunderResistanceBp,
    );
    _addBpStat(
      lines,
      _labelFor(CharacterStatId.acidResistance),
      stats.acidResistanceBp,
    );
    _addBpStat(
      lines,
      _labelFor(CharacterStatId.darkResistance),
      stats.darkResistanceBp,
    );
    _addBpStat(
      lines,
      _labelFor(CharacterStatId.bleedResistance),
      stats.bleedResistanceBp,
    );
    _addBpStat(
      lines,
      _labelFor(CharacterStatId.earthResistance),
      stats.earthResistanceBp,
    );
    _addBpStat(
      lines,
      _labelFor(CharacterStatId.holyResistance),
      stats.holyResistanceBp,
    );
  }

  List<GearStatLine> _diffStatBonuses(GearStatBonuses a, GearStatBonuses b) {
    final lines = <GearStatLine>[];
    if (b.healthBonusBp != a.healthBonusBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.health),
          a.healthBonusBp,
          b.healthBonusBp,
        ),
      );
    }
    if (b.manaBonusBp != a.manaBonusBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.mana),
          a.manaBonusBp,
          b.manaBonusBp,
        ),
      );
    }
    if (b.staminaBonusBp != a.staminaBonusBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.stamina),
          a.staminaBonusBp,
          b.staminaBonusBp,
        ),
      );
    }
    if (b.healthRegenBonusBp != a.healthRegenBonusBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.healthRegen),
          a.healthRegenBonusBp,
          b.healthRegenBonusBp,
        ),
      );
    }
    if (b.manaRegenBonusBp != a.manaRegenBonusBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.manaRegen),
          a.manaRegenBonusBp,
          b.manaRegenBonusBp,
        ),
      );
    }
    if (b.staminaRegenBonusBp != a.staminaRegenBonusBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.staminaRegen),
          a.staminaRegenBonusBp,
          b.staminaRegenBonusBp,
        ),
      );
    }
    if (b.defenseBonusBp != a.defenseBonusBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.defense),
          a.defenseBonusBp,
          b.defenseBonusBp,
        ),
      );
    }
    if (b.moveSpeedBonusBp != a.moveSpeedBonusBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.moveSpeed),
          a.moveSpeedBonusBp,
          b.moveSpeedBonusBp,
        ),
      );
    }
    final aPowerBp = _effectivePowerBp(a);
    final bPowerBp = _effectivePowerBp(b);
    if (bPowerBp != aPowerBp) {
      lines.add(
        _deltaBpLine(_labelFor(CharacterStatId.power), aPowerBp, bPowerBp),
      );
    }
    if (b.cooldownReductionBp != a.cooldownReductionBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.cooldownReduction),
          a.cooldownReductionBp,
          b.cooldownReductionBp,
        ),
      );
    }
    final aCritChanceBp = _effectiveCritChanceBp(a);
    final bCritChanceBp = _effectiveCritChanceBp(b);
    if (bCritChanceBp != aCritChanceBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.critChance),
          aCritChanceBp,
          bCritChanceBp,
        ),
      );
    }
    if (b.physicalResistanceBp != a.physicalResistanceBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.physicalResistance),
          a.physicalResistanceBp,
          b.physicalResistanceBp,
        ),
      );
    }
    if (b.fireResistanceBp != a.fireResistanceBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.fireResistance),
          a.fireResistanceBp,
          b.fireResistanceBp,
        ),
      );
    }
    if (b.iceResistanceBp != a.iceResistanceBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.iceResistance),
          a.iceResistanceBp,
          b.iceResistanceBp,
        ),
      );
    }
    if (b.waterResistanceBp != a.waterResistanceBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.waterResistance),
          a.waterResistanceBp,
          b.waterResistanceBp,
        ),
      );
    }
    if (b.thunderResistanceBp != a.thunderResistanceBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.thunderResistance),
          a.thunderResistanceBp,
          b.thunderResistanceBp,
        ),
      );
    }
    if (b.acidResistanceBp != a.acidResistanceBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.acidResistance),
          a.acidResistanceBp,
          b.acidResistanceBp,
        ),
      );
    }
    if (b.darkResistanceBp != a.darkResistanceBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.darkResistance),
          a.darkResistanceBp,
          b.darkResistanceBp,
        ),
      );
    }
    if (b.bleedResistanceBp != a.bleedResistanceBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.bleedResistance),
          a.bleedResistanceBp,
          b.bleedResistanceBp,
        ),
      );
    }
    if (b.earthResistanceBp != a.earthResistanceBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.earthResistance),
          a.earthResistanceBp,
          b.earthResistanceBp,
        ),
      );
    }
    if (b.holyResistanceBp != a.holyResistanceBp) {
      lines.add(
        _deltaBpLine(
          _labelFor(CharacterStatId.holyResistance),
          a.holyResistanceBp,
          b.holyResistanceBp,
        ),
      );
    }
    return lines;
  }

  GearStatLine _deltaBpLine(
    String label,
    int equippedValue,
    int candidateValue,
  ) {
    final delta = candidateValue - equippedValue;
    return GearStatLine(
      label,
      _signedPercent(delta / 100),
      tone: _toneForDelta(delta),
    );
  }

  GearStatLineTone _toneForDelta(int delta) {
    if (delta > 0) return GearStatLineTone.positive;
    if (delta < 0) return GearStatLineTone.negative;
    return GearStatLineTone.neutral;
  }

  int _effectivePowerBp(GearStatBonuses stats) {
    return stats.globalPowerBonusBp;
  }

  int _effectiveCritChanceBp(GearStatBonuses stats) {
    return stats.globalCritChanceBonusBp;
  }

  String _bpPct(int bp) => _signedPercent(bp / 100);

  String _signedPercent(double value) {
    final formatted = (NumberFormat.percentPattern(
      strings.localeName,
    )..maximumFractionDigits = 2).format(value / 100);
    return value > 0 ? '+$formatted' : formatted;
  }

  String _labelFor(CharacterStatId id) => characterStatDisplayName(
    id,
    strings: strings,
    manaPresentation: manaPresentation,
  );
}

class _ProcEffectSummary {
  const _ProcEffectSummary({required this.text, required this.highlights});

  final String text;
  final List<GearStatHighlight> highlights;
}
