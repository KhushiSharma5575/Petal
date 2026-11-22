import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/dates.dart';

/// What the home-screen widget shows.
class HomeWidgetData {
  const HomeWidgetData({
    required this.date,
    required this.tasks,
    required this.openCount,
    required this.water,
    required this.waterGoal,
  });

  final DateTime date;

  /// Titles of up to 3 open tasks for today (overdue first).
  final List<String> tasks;

  /// All open tasks for today, including those not listed.
  final int openCount;
  final int water;
  final int waterGoal;

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetData &&
      other.date == date &&
      other.openCount == openCount &&
      other.water == water &&
      other.waterGoal == waterGoal &&
      other.tasks.join('\u0000') == tasks.join('\u0000');

  @override
  int get hashCode =>
      Object.hash(date, openCount, water, waterGoal, tasks.join('\u0000'));
}

/// Talks to the native widget (PetalWidget.kt). Tests use a fake.
abstract class HomeWidgetBridge {
  Future<void> update(HomeWidgetData data);

  /// Glasses tapped on the widget that the app hasn't counted yet, one
  /// entry per day they were tapped on (so a tap at 23:55 still counts for
  /// that day). Clears them. Empty when there are none.
  Future<List<({DateTime day, int glasses})>> takePendingGlasses();
}

class AndroidHomeWidgetBridge implements HomeWidgetBridge {
  static const _channel = MethodChannel('petal/widget');

  @override
  Future<void> update(HomeWidgetData d) async {
    try {
      await _channel.invokeMethod<void>('update', {
        'date': toIsoDate(d.date),
        'tasks': d.tasks,
        'openCount': d.openCount,
        'water': d.water,
        'waterGoal': d.waterGoal,
      });
    } on MissingPluginException {
      // Not running on Android (e.g. tests): nothing to update.
    }
  }

  @override
  Future<List<({DateTime day, int glasses})>> takePendingGlasses() async {
    try {
      final r = await _channel.invokeListMethod<Object?>('takePendingGlasses');
      return [
        for (final e in r ?? const <Object?>[])
          if (e is Map &&
              e['date'] is String &&
              e['count'] is int &&
              (e['count'] as int) > 0)
            (day: fromIsoDate(e['date'] as String), glasses: e['count'] as int),
      ];
    } on MissingPluginException {
      return const [];
    } on FormatException {
      return const []; // a broken date string: skip rather than crash
    }
  }
}

final homeWidgetBridgeProvider = Provider<HomeWidgetBridge>(
  (ref) => AndroidHomeWidgetBridge(),
);
