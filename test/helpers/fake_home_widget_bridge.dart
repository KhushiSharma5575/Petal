import 'package:petal/core/platform/home_widget_bridge.dart';

/// Records widget updates and hands out pretend "+ glass" taps.
class FakeHomeWidgetBridge implements HomeWidgetBridge {
  final updates = <HomeWidgetData>[];
  int pendingGlasses = 0;

  HomeWidgetData? get last => updates.isEmpty ? null : updates.last;

  @override
  Future<void> update(HomeWidgetData data) async => updates.add(data);

  /// The day the pretend taps were made on (null: the test's today).
  DateTime? pendingDay;

  /// Taps from earlier days, handed out together with [pendingGlasses].
  final olderGlasses = <({DateTime day, int glasses})>[];

  @override
  Future<List<({DateTime day, int glasses})>> takePendingGlasses() async {
    final n = pendingGlasses;
    pendingGlasses = 0;
    final all = [
      ...olderGlasses,
      if (n > 0) (day: pendingDay ?? DateTime(2026, 11, 13), glasses: n),
    ];
    olderGlasses.clear();
    return all;
  }
}
