/// Broad classification tags shared across enemies and player variants.
enum CreatureTag {
  humanoid,
  demon,
  flying,
  undead,
}

/// Bitmask constants for [CreatureTag].
class CreatureTagMask {
  const CreatureTagMask._();

  static const int humanoid = 1 << 0;
  static const int demon = 1 << 1;
  static const int flying = 1 << 2;
  static const int undead = 1 << 3;

  static int forTag(CreatureTag tag) {
    switch (tag) {
      case CreatureTag.humanoid:
        return humanoid;
      case CreatureTag.demon:
        return demon;
      case CreatureTag.flying:
        return flying;
      case CreatureTag.undead:
        return undead;
    }
  }
}

