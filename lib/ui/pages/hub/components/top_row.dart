import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

class TopRow extends StatefulWidget {
  const TopRow({
    super.key,
    required this.displayName,
    required this.profileId,
    required this.gold,
  });

  final String displayName;
  final String profileId;
  final int gold;

  @override
  State<TopRow> createState() => _TopRowState();
}

class _TopRowState extends State<TopRow> {
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.unknown;
  late Timer _timer;
  DateTime _now = DateTime.now();
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  @override
  void initState() {
    super.initState();
    _initBattery();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  Future<void> _initBattery() async {
    _batteryStateSubscription = _battery.onBatteryStateChanged.listen((state) {
      if (mounted) setState(() => _batteryState = state);
    });

    try {
      final level = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = level);
    } catch (_) {
      // Ignore battery level errors
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _batteryStateSubscription?.cancel();
    super.dispose();
  }

  IconData get _batteryIcon {
    if (_batteryState == BatteryState.charging) {
      return Icons.battery_charging_full;
    }
    if (_batteryLevel >= 90) return Icons.battery_full;
    if (_batteryLevel >= 60) return Icons.battery_6_bar;
    if (_batteryLevel >= 50) return Icons.battery_5_bar;
    if (_batteryLevel >= 30) return Icons.battery_3_bar;
    if (_batteryLevel >= 20) return Icons.battery_2_bar;
    return Icons.battery_alert; // Alert?
  }

  Color get _batteryColor {
    if (_batteryState == BatteryState.charging) return Colors.greenAccent;
    if (_batteryLevel <= 20) return Colors.redAccent;
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // Gold
          Text(
            widget.gold.toString(),
            style: const TextStyle(
              color: Color(0xFFFFF59D),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 16),
          const SizedBox(width: 16),
          Container(width: 1, height: 24, color: Colors.white),
          const SizedBox(width: 6),
          // Battery
          Icon(_batteryIcon, color: _batteryColor, size: 16),
          const SizedBox(width: 4),
          Text(
            '$_batteryLevel%',
            style: TextStyle(
              color: _batteryColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          // Time
          const Icon(Icons.access_time, color: Colors.white54, size: 16),
          const SizedBox(width: 4),
          Text(
            timeStr,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
