import '../../../combat/status/status.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

class ResourceOverTimeDef {
  const ResourceOverTimeDef({
    required this.resourceType,
    required this.ticksLeft,
    required this.totalTicks,
    required this.totalAmount100,
    required this.amountBp,
    this.accumulatorNumerator = 0,
  });

  final StatusResourceType resourceType;
  final int ticksLeft;

  /// Authored total duration for this channel in ticks.
  final int totalTicks;

  /// Total fixed-point resource restored across the full channel duration.
  final int totalAmount100;

  /// Authored total restore percentage (`100 = 1%`).
  final int amountBp;

  /// Fractional carry for deterministic per-tick distribution.
  ///
  /// Units are "resource * ticks"; per tick we add [totalAmount100], divide by
  /// [totalTicks], and carry the remainder here.
  final int accumulatorNumerator;
}

/// Active continuous resource restoration keyed by target entity.
///
/// A target can host multiple channels at once as long as they use different
/// resource types (health/mana/stamina).
class ResourceOverTimeStore extends SparseSet {
  final List<List<StatusResourceType>> resourceTypes =
      <List<StatusResourceType>>[];
  final List<List<int>> ticksLeft = <List<int>>[];
  final List<List<int>> totalTicks = <List<int>>[];
  final List<List<int>> totalAmount100 = <List<int>>[];
  final List<List<int>> amountBp = <List<int>>[];
  final List<List<int>> accumulatorNumerator = <List<int>>[];

  void add(EntityId entity, ResourceOverTimeDef def) {
    final entityIndex = addEntity(entity);
    final channelIndex = _channelIndexFor(entityIndex, def.resourceType);
    if (channelIndex == null) {
      _addChannel(entityIndex, def);
      return;
    }
    _setChannel(entityIndex, channelIndex, def);
  }

  int? channelIndexFor(EntityId entity, StatusResourceType resourceType) {
    final entityIndex = tryIndexOf(entity);
    if (entityIndex == null) return null;
    return _channelIndexFor(entityIndex, resourceType);
  }

  int? channelIndexForEntityIndex(
    int entityIndex,
    StatusResourceType resourceType,
  ) {
    return _channelIndexFor(entityIndex, resourceType);
  }

  void addChannel(EntityId entity, ResourceOverTimeDef def) {
    final entityIndex = addEntity(entity);
    _addChannel(entityIndex, def);
  }

  void setChannel(EntityId entity, int channelIndex, ResourceOverTimeDef def) {
    final entityIndex = indexOf(entity);
    _setChannel(entityIndex, channelIndex, def);
  }

  void removeChannelAtEntityIndex(int entityIndex, int channelIndex) {
    _removeChannelAt(entityIndex, channelIndex);
  }

  bool hasNoChannelsEntityIndex(int entityIndex) {
    return resourceTypes[entityIndex].isEmpty;
  }

  int? _channelIndexFor(int entityIndex, StatusResourceType resourceType) {
    final channels = resourceTypes[entityIndex];
    for (var i = 0; i < channels.length; i += 1) {
      if (channels[i] == resourceType) return i;
    }
    return null;
  }

  void _addChannel(int entityIndex, ResourceOverTimeDef def) {
    resourceTypes[entityIndex].add(def.resourceType);
    ticksLeft[entityIndex].add(def.ticksLeft);
    totalTicks[entityIndex].add(def.totalTicks);
    totalAmount100[entityIndex].add(def.totalAmount100);
    amountBp[entityIndex].add(def.amountBp);
    accumulatorNumerator[entityIndex].add(def.accumulatorNumerator);
  }

  void _setChannel(int entityIndex, int channelIndex, ResourceOverTimeDef def) {
    resourceTypes[entityIndex][channelIndex] = def.resourceType;
    ticksLeft[entityIndex][channelIndex] = def.ticksLeft;
    totalTicks[entityIndex][channelIndex] = def.totalTicks;
    totalAmount100[entityIndex][channelIndex] = def.totalAmount100;
    amountBp[entityIndex][channelIndex] = def.amountBp;
    accumulatorNumerator[entityIndex][channelIndex] = def.accumulatorNumerator;
  }

  void _removeChannelAt(int entityIndex, int channelIndex) {
    resourceTypes[entityIndex].removeAt(channelIndex);
    ticksLeft[entityIndex].removeAt(channelIndex);
    totalTicks[entityIndex].removeAt(channelIndex);
    totalAmount100[entityIndex].removeAt(channelIndex);
    amountBp[entityIndex].removeAt(channelIndex);
    accumulatorNumerator[entityIndex].removeAt(channelIndex);
  }

  @override
  void onDenseAdded(int denseIndex) {
    resourceTypes.add(<StatusResourceType>[]);
    ticksLeft.add(<int>[]);
    totalTicks.add(<int>[]);
    totalAmount100.add(<int>[]);
    amountBp.add(<int>[]);
    accumulatorNumerator.add(<int>[]);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    resourceTypes[removeIndex] = resourceTypes[lastIndex];
    ticksLeft[removeIndex] = ticksLeft[lastIndex];
    totalTicks[removeIndex] = totalTicks[lastIndex];
    totalAmount100[removeIndex] = totalAmount100[lastIndex];
    amountBp[removeIndex] = amountBp[lastIndex];
    accumulatorNumerator[removeIndex] = accumulatorNumerator[lastIndex];

    resourceTypes.removeLast();
    ticksLeft.removeLast();
    totalTicks.removeLast();
    totalAmount100.removeLast();
    amountBp.removeLast();
    accumulatorNumerator.removeLast();
  }
}
