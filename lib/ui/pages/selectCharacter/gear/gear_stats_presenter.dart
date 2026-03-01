import '../../../../core/accessories/accessory_catalog.dart';
import '../../../../core/accessories/accessory_def.dart';
import '../../../../core/accessories/accessory_id.dart';
import '../../../../core/combat/status/status.dart';
import '../../../../core/meta/gear_slot.dart';
import '../../../../core/projectiles/projectile_catalog.dart';
import '../../../../core/projectiles/projectile_item_def.dart';
import '../../../../core/projectiles/projectile_id.dart';
import '../../../../core/spellBook/spell_book_catalog.dart';
import '../../../../core/spellBook/spell_book_def.dart';
import '../../../../core/spellBook/spell_book_id.dart';
import '../../../../core/stats/character_stat_id.dart';
import '../../../../core/stats/gear_stat_bonuses.dart';
import '../../../../core/weapons/weapon_def.dart';
import '../../../../core/weapons/weapon_id.dart';
import '../../../../core/weapons/weapon_catalog.dart';
import '../../../../core/weapons/weapon_proc.dart';
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

/// Builds base stat lines for a selected gear item.
///
/// This is pure computation (no widget or state dependencies).
List<GearStatLine> gearStatsFor(GearSlot slot, Object id) {
  switch (slot) {
    case GearSlot.mainWeapon:
    case GearSlot.offhandWeapon:
      final def = const WeaponCatalog().get(id as WeaponId);
      return _weaponDefStats(def);
    case GearSlot.throwingWeapon:
      final def = const ProjectileCatalog().get(id as ProjectileId);
      return _projectileStats(def);
    case GearSlot.spellBook:
      final def = const SpellBookCatalog().get(id as SpellBookId);
      return _spellBookStats(def);
    case GearSlot.accessory:
      final def = const AccessoryCatalog().get(id as AccessoryId);
      return _accessoryStats(def);
  }
}

/// Builds compare stat lines between currently equipped and selected gear.
///
/// Returns an empty list when both ids are the same item.
List<GearStatLine> gearCompareStats(
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
    case GearSlot.throwingWeapon:
      final a = const ProjectileCatalog().get(equipped as ProjectileId);
      final b = const ProjectileCatalog().get(candidate as ProjectileId);
      return _diffWeaponStatsLike(
        a.stats,
        b.stats,
        equippedProcs: a.procs,
        candidateProcs: b.procs,
      );
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
      return _diffAccessoryStats(a.stats, b.stats);
  }
}

/// Empty state text for the compare section.
String gearCompareEmptyText({
  required Object? selectedId,
  required Object? equippedForCompare,
}) {
  if (selectedId != null &&
      equippedForCompare != null &&
      selectedId == equippedForCompare) {
    return 'This gear is currently equipped.';
  }
  return 'No stat differences.';
}

List<GearStatLine> _weaponDefStats(WeaponDef def) {
  final stats = def.stats;
  final lines = <GearStatLine>[];
  _addCoreStatLines(lines, stats);
  lines.addAll(_buildProcHookLines(def.procs));
  return lines;
}

List<GearStatLine> _projectileStats(ProjectileItemDef def) {
  final stats = def.stats;
  final lines = <GearStatLine>[
    GearStatLine('Damage Type', _enumLabel(def.damageType.name)),
  ];
  _addCoreStatLines(lines, stats);
  lines.addAll(_buildProcHookLines(def.procs));
  return lines;
}

List<GearStatLine> _spellBookStats(SpellBookDef def) {
  final stats = def.stats;
  final lines = <GearStatLine>[
    GearStatLine(
      'Damage Type',
      def.damageType == null ? 'Ability' : _enumLabel(def.damageType!.name),
    ),
  ];
  _addCoreStatLines(lines, stats);
  lines.addAll(_buildProcHookLines(def.procs));
  return lines;
}

List<GearStatLine> _accessoryStats(AccessoryDef def) {
  final stats = def.stats;
  final lines = <GearStatLine>[];
  _addCoreStatLines(lines, stats);
  return lines;
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
      final profile = profiles.get(proc.statusProfileId);
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

String _procHookLabel(ProcHook hook) {
  return switch (hook) {
    ProcHook.onHit => 'On Hit',
    ProcHook.onCrit => 'On Crit',
    ProcHook.onKill => 'On Kill',
    ProcHook.onBlock => 'On Block',
  };
}

const Map<StatusEffectType, String> _procStatusLabels =
    <StatusEffectType, String>{
      StatusEffectType.slow: 'Slow',
      StatusEffectType.stun: 'Stun',
      StatusEffectType.silence: 'Silence',
      StatusEffectType.vulnerable: 'Vulnerable',
      StatusEffectType.weaken: 'Weaken',
      StatusEffectType.drench: 'Drench',
      StatusEffectType.haste: 'Haste',
      StatusEffectType.damageReduction: 'Damage Reduction',
      StatusEffectType.offenseBuff: 'Offense Buff',
    };

const Map<StatusEffectType, _ProcEffectTemplate>
_procEffectTemplates = <StatusEffectType, _ProcEffectTemplate>{
  StatusEffectType.dot: _ProcEffectTemplate(
    tone: GearStatLineTone.negative,
    sentenceTemplate:
        'Applies {status}, dealing {dps} damage per second for {duration}{chanceSuffix}',
    highlightKeys: <String>['status', 'dps', 'duration'],
  ),
  StatusEffectType.slow: _ProcEffectTemplate(
    tone: GearStatLineTone.negative,
    sentenceTemplate:
        'Applies {status}, reducing move speed by {amount} for {duration}{chanceSuffix}',
    highlightKeys: <String>['status', 'amount', 'duration'],
  ),
  StatusEffectType.stun: _ProcEffectTemplate(
    tone: GearStatLineTone.negative,
    sentenceTemplate: 'Applies {status} for {duration}{chanceSuffix}',
    highlightKeys: <String>['status', 'duration'],
  ),
  StatusEffectType.silence: _ProcEffectTemplate(
    tone: GearStatLineTone.negative,
    sentenceTemplate: 'Applies {status} for {duration}{chanceSuffix}',
    highlightKeys: <String>['status', 'duration'],
  ),
  StatusEffectType.vulnerable: _ProcEffectTemplate(
    tone: GearStatLineTone.negative,
    sentenceTemplate:
        'Applies {status}, increasing damage taken by {amount} for {duration}{chanceSuffix}',
    highlightKeys: <String>['status', 'amount', 'duration'],
  ),
  StatusEffectType.weaken: _ProcEffectTemplate(
    tone: GearStatLineTone.negative,
    sentenceTemplate:
        'Applies {status}, reducing outgoing damage by {amount} for {duration}{chanceSuffix}',
    highlightKeys: <String>['status', 'amount', 'duration'],
  ),
  StatusEffectType.drench: _ProcEffectTemplate(
    tone: GearStatLineTone.negative,
    sentenceTemplate:
        'Applies {status}, reducing attack and cast speed by {amount} for {duration}{chanceSuffix}',
    highlightKeys: <String>['status', 'amount', 'duration'],
  ),
  StatusEffectType.haste: _ProcEffectTemplate(
    tone: GearStatLineTone.positive,
    sentenceTemplate:
        'Applies {status}, increasing move speed by {amount} for {duration}{chanceSuffix}',
    highlightKeys: <String>['status', 'amount', 'duration'],
  ),
  StatusEffectType.damageReduction: _ProcEffectTemplate(
    tone: GearStatLineTone.positive,
    sentenceTemplate:
        'Applies {status}, reducing incoming direct-hit damage by {amount} for {duration}{chanceSuffix}',
    highlightKeys: <String>['status', 'amount', 'duration'],
  ),
  StatusEffectType.resourceOverTime: _ProcEffectTemplate(
    tone: GearStatLineTone.positive,
    sentenceTemplate:
        'Restores {resource} by {amount} every {pulse} for {duration}{chanceSuffix}',
    highlightKeys: <String>['resource', 'amount', 'pulse', 'duration'],
  ),
  StatusEffectType.offenseBuff: _ProcEffectTemplate(
    tone: GearStatLineTone.positive,
    sentenceTemplate:
        'Applies an {status}, increasing power by {power}{critClause} for {duration}{chanceSuffix}',
    highlightKeys: <String>['status', 'power', 'duration'],
    optionalHighlightKeys: <String>['critAmount'],
  ),
};

_ProcEffectSummary? _procEffectSummary(StatusApplication app, WeaponProc proc) {
  final template = _procEffectTemplates[app.type];
  if (template == null) return null;

  final chance = _procChanceSummary(proc.chanceBp);
  final values = _procTemplateValues(app, proc, chanceSuffix: chance.suffix);
  final text = _resolveTemplate(template.sentenceTemplate, values);
  final highlightTokens = <String>[
    for (final key in template.highlightKeys) values[key] ?? '',
    for (final key in template.optionalHighlightKeys) values[key] ?? '',
    if (chance.percentToken != null) chance.percentToken!,
  ];

  return _ProcEffectSummary(
    text: text,
    highlights: _highlightsForTokens(
      tone: template.tone,
      tokens: highlightTokens,
    ),
  );
}

Map<String, String> _procTemplateValues(
  StatusApplication app,
  WeaponProc proc, {
  required String chanceSuffix,
}) {
  final duration = _formatDuration(app.durationSeconds);
  switch (app.type) {
    case StatusEffectType.dot:
      return <String, String>{
        'status': _dotStatusLabel(proc.statusProfileId),
        'dps': _formatFixed100(app.magnitude),
        'duration': duration,
        'chanceSuffix': chanceSuffix,
      };
    case StatusEffectType.slow:
    case StatusEffectType.vulnerable:
    case StatusEffectType.weaken:
    case StatusEffectType.drench:
    case StatusEffectType.haste:
    case StatusEffectType.damageReduction:
      return <String, String>{
        'status': _procStatusLabels[app.type]!,
        'amount': _formatPercentFromBp(app.magnitude),
        'duration': duration,
        'chanceSuffix': chanceSuffix,
      };
    case StatusEffectType.stun:
    case StatusEffectType.silence:
      return <String, String>{
        'status': _procStatusLabels[app.type]!,
        'duration': duration,
        'chanceSuffix': chanceSuffix,
      };
    case StatusEffectType.resourceOverTime:
      final resource = switch (app.resourceType) {
        StatusResourceType.health => 'Health',
        StatusResourceType.mana => 'Mana',
        StatusResourceType.stamina => 'Stamina',
        null => 'Resource',
      };
      return <String, String>{
        'resource': resource,
        'amount': _formatPercentFromBp(app.magnitude),
        'pulse': _formatDuration(app.periodSeconds),
        'duration': duration,
        'chanceSuffix': chanceSuffix,
      };
    case StatusEffectType.offenseBuff:
      final critAmount = app.critBonusBp == null
          ? ''
          : _formatPercentFromBp(app.critBonusBp!);
      final critClause = critAmount.isEmpty
          ? ''
          : ' and critical chance by $critAmount';
      return <String, String>{
        'status': _procStatusLabels[app.type]!,
        'power': _formatPercentFromBp(app.magnitude),
        'critClause': critClause,
        'critAmount': critAmount,
        'duration': duration,
        'chanceSuffix': chanceSuffix,
      };
  }
}

String _dotStatusLabel(StatusProfileId profileId) {
  return switch (profileId) {
    StatusProfileId.meleeBleed => 'Bleed',
    StatusProfileId.burnOnHit => 'Burn',
    _ => throw StateError(
      'Unsupported DoT status profile for gear stats: $profileId',
    ),
  };
}

String _resolveTemplate(String template, Map<String, String> values) {
  var resolved = template;
  for (final entry in values.entries) {
    resolved = resolved.replaceAll('{${entry.key}}', entry.value);
  }
  return resolved;
}

_ProcChanceSummary _procChanceSummary(int chanceBp) {
  if (chanceBp >= 10000) return const _ProcChanceSummary(suffix: '.');
  final percent = _formatPercentFromBp(chanceBp);
  return _ProcChanceSummary(
    suffix: ' ($percent chance).',
    percentToken: percent,
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

String _formatDuration(double seconds) {
  final text = seconds.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  return text == '1' ? '$text second' : '$text seconds';
}

String _formatPercentFromBp(int bp) {
  final percent = bp / 100.0;
  final text = percent.toStringAsFixed(1);
  return '${text.replaceFirst(RegExp(r'\.0$'), '')}%';
}

String _formatFixed100(int value100) {
  return (value100 / 100.0)
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'\.?0+$'), '');
}

List<GearStatLine> _diffWeaponStats(WeaponDef equipped, WeaponDef candidate) {
  return _diffWeaponStatsLike(
    equipped.stats,
    candidate.stats,
    equippedProcs: equipped.procs,
    candidateProcs: candidate.procs,
  );
}

List<GearStatLine> _diffWeaponStatsLike(
  GearStatBonuses a,
  GearStatBonuses b, {
  List<WeaponProc> equippedProcs = const <WeaponProc>[],
  List<WeaponProc> candidateProcs = const <WeaponProc>[],
}) {
  final lines = _diffStatBonuses(a, b);
  lines.addAll(
    _diffProcHookLines(
      equippedProcs: equippedProcs,
      candidateProcs: candidateProcs,
    ),
  );
  return lines;
}

List<GearStatLine> _diffAccessoryStats(GearStatBonuses a, GearStatBonuses b) {
  return _diffStatBonuses(a, b);
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
      final section = 'Lose: ${_joinSummaryTexts(removed)}';
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
      final section = 'Add: ${_joinSummaryTexts(added)}';
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

Map<ProcHook, List<_ProcEffectSummary>> _procSummariesByHook(
  List<WeaponProc> procs,
) {
  if (procs.isEmpty) return const <ProcHook, List<_ProcEffectSummary>>{};
  const profiles = StatusProfileCatalog();
  final byHook = <ProcHook, List<_ProcEffectSummary>>{};
  for (final proc in procs) {
    if (proc.statusProfileId == StatusProfileId.none) continue;
    final profile = profiles.get(proc.statusProfileId);
    for (final app in profile.applications) {
      final summary = _procEffectSummary(app, proc);
      if (summary == null) continue;
      byHook.putIfAbsent(proc.hook, () => <_ProcEffectSummary>[]).add(summary);
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
  _addBpStat(lines, _labelFor(CharacterStatId.defense), stats.defenseBonusBp);
  _addBpStat(lines, _labelFor(CharacterStatId.power), _effectivePowerBp(stats));
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
    _labelFor(CharacterStatId.thunderResistance),
    stats.thunderResistanceBp,
  );
  _addBpStat(
    lines,
    _labelFor(CharacterStatId.bleedResistance),
    stats.bleedResistanceBp,
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
  if (b.thunderResistanceBp != a.thunderResistanceBp) {
    lines.add(
      _deltaBpLine(
        _labelFor(CharacterStatId.thunderResistance),
        a.thunderResistanceBp,
        b.thunderResistanceBp,
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
  return lines;
}

GearStatLine _deltaBpLine(String label, int equippedValue, int candidateValue) {
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
  return stats.powerBonusBp + stats.globalPowerBonusBp;
}

int _effectiveCritChanceBp(GearStatBonuses stats) {
  return stats.critChanceBonusBp + stats.globalCritChanceBonusBp;
}

String _bpPct(int bp) => _signedPercent(bp / 100);

String _signedPercent(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${_formatNumber(value)}%';
}

String _formatNumber(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _enumLabel(String source) {
  final normalized = source
      .replaceAll('_', ' ')
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      );
  final words = normalized.split(RegExp(r'\s+'));
  return words
      .where((word) => word.isNotEmpty)
      .map((word) {
        if (word == word.toUpperCase()) return word;
        return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
      })
      .join(' ');
}

String _labelFor(CharacterStatId id) => characterStatDescriptor(id).displayName;

class _ProcEffectSummary {
  const _ProcEffectSummary({required this.text, required this.highlights});

  final String text;
  final List<GearStatHighlight> highlights;
}

class _ProcChanceSummary {
  const _ProcChanceSummary({required this.suffix, this.percentToken});

  final String suffix;
  final String? percentToken;
}

class _ProcEffectTemplate {
  const _ProcEffectTemplate({
    required this.tone,
    required this.sentenceTemplate,
    required this.highlightKeys,
    this.optionalHighlightKeys = const <String>[],
  });

  final GearStatLineTone tone;
  final String sentenceTemplate;
  final List<String> highlightKeys;
  final List<String> optionalHighlightKeys;
}
