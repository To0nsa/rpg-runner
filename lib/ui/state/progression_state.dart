class ProgressionState {
  const ProgressionState({required this.gold});

  final int gold;

  static const ProgressionState initial = ProgressionState(gold: 0);

  ProgressionState copyWith({int? gold}) {
    return ProgressionState(gold: gold ?? this.gold);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'gold': gold};
  }

  factory ProgressionState.fromJson(Map<String, dynamic> json) {
    final goldRaw = json['gold'];
    final gold = goldRaw is int
        ? goldRaw
        : (goldRaw is num ? goldRaw.toInt() : 0);
    return ProgressionState(gold: gold < 0 ? 0 : gold);
  }
}
