import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

import '../../../theme/ui_tokens.dart';

class HubTopRow extends StatefulWidget {
  const HubTopRow({
    super.key,
    required this.displayName,
    required this.profileId,
    required this.gold,
  });

  final String displayName;
  final String profileId;
  final int gold;

  @override
  State<HubTopRow> createState() => _HubTopRowState();
}

class _HubTopRowState extends State<HubTopRow> {
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
    final ui = context.ui;
    if (_batteryState == BatteryState.charging) return ui.colors.success;
    if (_batteryLevel <= 20) return ui.colors.danger;
    return ui.colors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final timeStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.displayName,
              style: ui.text.headline,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: ui.space.sm),
          // Gold
          Text(
            widget.gold.toString(),
            style: ui.text.headline.copyWith(color: ui.colors.accent),
          ),
          SizedBox(width: ui.space.xs),
          Icon(
            Icons.monetization_on,
            color: ui.colors.accentStrong,
            size: ui.sizes.iconSize.sm,
          ),
          SizedBox(width: ui.space.md),
          Container(
            width: ui.sizes.dividerThickness,
            height: ui.space.lg,
            color: ui.colors.textPrimary,
          ),
          SizedBox(width: ui.space.xs),
          // Battery
          Icon(_batteryIcon, color: _batteryColor, size: ui.sizes.iconSize.sm),
          SizedBox(width: ui.space.xxs),
          Text(
            '$_batteryLevel%',
            style: ui.text.caption.copyWith(color: _batteryColor),
          ),
          SizedBox(width: ui.space.md),
          // Time
          Icon(
            Icons.access_time,
            color: ui.colors.outlineStrong,
            size: ui.sizes.iconSize.sm,
          ),
          SizedBox(width: ui.space.xxs),
          Text(
            timeStr,
            style: ui.text.caption.copyWith(color: ui.colors.textPrimary),
          ),
        ],
      ),
    );
  }
}
