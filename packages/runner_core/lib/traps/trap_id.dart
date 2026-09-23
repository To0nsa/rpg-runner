/// Stable trap types; source keys are independent of Dart enum spelling.
enum TrapId {
  spike('spike'),
  swingingAxe('swinging_axe'),
  poisonDarts('poison_darts');

  const TrapId(this.sourceKey);
  final String sourceKey;

  static TrapId fromSourceKey(String value) => values.firstWhere(
    (id) => id.sourceKey == value,
    orElse: () => throw FormatException('Unknown trapId "$value".'),
  );
}
