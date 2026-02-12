import '../../../combat/damage_type.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

class DotDef {
  const DotDef({
    required this.damageType,
    required this.ticksLeft,
    required this.periodTicks,
    required this.dps100,
  }) : periodTicksLeft = periodTicks;

  final DamageType damageType;
  final int ticksLeft;
  final int periodTicks;
  final int periodTicksLeft;

  /// Fixed-point DPS: 100 = 1.0 per second.
  final int dps100;
}

/// Active damage-over-time effects keyed by target entity.
///
/// A target can host multiple DoTs at once as long as they use different
/// [DamageType] channels (for example, physical and fire).
class DotStore extends SparseSet {
  final List<List<DamageType>> damageTypes = <List<DamageType>>[];
  final List<List<int>> ticksLeft = <List<int>>[];
  final List<List<int>> periodTicks = <List<int>>[];
  final List<List<int>> periodTicksLeft = <List<int>>[];
  final List<List<int>> dps100 = <List<int>>[];

  void add(EntityId entity, DotDef def) {
    final entityIndex = addEntity(entity);
    final channelIndex = _channelIndexFor(entityIndex, def.damageType);
    if (channelIndex == null) {
      _addChannel(entityIndex, def);
      return;
    }
    _setChannel(entityIndex, channelIndex, def);
  }

  int? channelIndexFor(EntityId entity, DamageType damageType) {
    final entityIndex = tryIndexOf(entity);
    if (entityIndex == null) return null;
    return _channelIndexFor(entityIndex, damageType);
  }

  int? channelIndexForEntityIndex(int entityIndex, DamageType damageType) {
    return _channelIndexFor(entityIndex, damageType);
  }

  void addChannel(EntityId entity, DotDef def) {
    final entityIndex = addEntity(entity);
    _addChannel(entityIndex, def);
  }

  void setChannel(EntityId entity, int channelIndex, DotDef def) {
    final entityIndex = indexOf(entity);
    _setChannel(entityIndex, channelIndex, def);
  }

  void removeChannelAt(EntityId entity, int channelIndex) {
    final entityIndex = indexOf(entity);
    _removeChannelAt(entityIndex, channelIndex);
  }

  void removeChannelAtEntityIndex(int entityIndex, int channelIndex) {
    _removeChannelAt(entityIndex, channelIndex);
  }

  bool hasNoChannelsEntityIndex(int entityIndex) {
    return damageTypes[entityIndex].isEmpty;
  }

  int? _channelIndexFor(int entityIndex, DamageType damageType) {
    final channels = damageTypes[entityIndex];
    for (var i = 0; i < channels.length; i += 1) {
      if (channels[i] == damageType) return i;
    }
    return null;
  }

  void _addChannel(int entityIndex, DotDef def) {
    damageTypes[entityIndex].add(def.damageType);
    ticksLeft[entityIndex].add(def.ticksLeft);
    periodTicks[entityIndex].add(def.periodTicks);
    periodTicksLeft[entityIndex].add(def.periodTicksLeft);
    dps100[entityIndex].add(def.dps100);
  }

  void _setChannel(int entityIndex, int channelIndex, DotDef def) {
    damageTypes[entityIndex][channelIndex] = def.damageType;
    ticksLeft[entityIndex][channelIndex] = def.ticksLeft;
    periodTicks[entityIndex][channelIndex] = def.periodTicks;
    periodTicksLeft[entityIndex][channelIndex] = def.periodTicksLeft;
    dps100[entityIndex][channelIndex] = def.dps100;
  }

  void _removeChannelAt(int entityIndex, int channelIndex) {
    damageTypes[entityIndex].removeAt(channelIndex);
    ticksLeft[entityIndex].removeAt(channelIndex);
    periodTicks[entityIndex].removeAt(channelIndex);
    periodTicksLeft[entityIndex].removeAt(channelIndex);
    dps100[entityIndex].removeAt(channelIndex);
  }

  @override
  void onDenseAdded(int denseIndex) {
    damageTypes.add(<DamageType>[]);
    ticksLeft.add(<int>[]);
    periodTicks.add(<int>[]);
    periodTicksLeft.add(<int>[]);
    dps100.add(<int>[]);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    damageTypes[removeIndex] = damageTypes[lastIndex];
    ticksLeft[removeIndex] = ticksLeft[lastIndex];
    periodTicks[removeIndex] = periodTicks[lastIndex];
    periodTicksLeft[removeIndex] = periodTicksLeft[lastIndex];
    dps100[removeIndex] = dps100[lastIndex];

    damageTypes.removeLast();
    ticksLeft.removeLast();
    periodTicks.removeLast();
    periodTicksLeft.removeLast();
    dps100.removeLast();
  }
}
