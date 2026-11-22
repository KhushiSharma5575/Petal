import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:petal/app.dart';
import 'package:petal/core/platform/device_bridge.dart';
import 'package:petal/core/platform/file_saver.dart';
import 'package:petal/core/platform/home_widget_bridge.dart';
import 'package:petal/core/utils/clock.dart';
import 'package:petal/data/db/app_database.dart';
import 'package:petal/data/providers.dart';
import 'package:petal/data/repositories/settings_repository.dart';
import 'package:petal/features/tasks/state/reminder_sync.dart';
import 'package:petal/features/voice/state/speech_service.dart';

import 'fake_device_bridge.dart';
import 'fake_file_saver.dart';
import 'fake_home_widget_bridge.dart';
import 'fake_reminder_platform.dart';
import 'fake_speech_service.dart';
import 'test_db.dart';

/// Friday 13 November 2026, 10:00. Every widget test runs at this moment.
final testNow = DateTime(2026, 11, 13, 10, 0);

class TestApp {
  TestApp(
    this.db,
    this.reminders,
    this.files,
    this.speech,
    this.widget,
    this.device,
  );
  final AppDatabase db;
  final FakeReminderPlatform reminders;
  final FakeFileSaver files;
  final FakeSpeechService speech;
  final FakeHomeWidgetBridge widget;
  final FakeDeviceBridge device;
}

/// Pumps the whole app with an in-memory database, a frozen clock, fake
/// notifications, a fake Downloads folder and a fake microphone. [setup] can
/// add data before the first frame.
///
/// The screen defaults to a typical phone (412 x 915 dp).
Future<TestApp> pumpPetal(
  WidgetTester tester, {
  Future<void> Function(AppDatabase db)? setup,
  Size screen = const Size(412, 915),
  int widgetGlasses = 0,
  DateTime? widgetGlassesDay,
  List<({DateTime day, int glasses})> widgetOlderGlasses = const [],
  bool showWelcome = false,
  DateTime Function()? clock,
}) async {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = screen * 2.625;
  addTearDown(tester.view.reset);

  final db = newTestDatabase();
  final reminders = FakeReminderPlatform();
  final files = FakeFileSaver();
  final speech = FakeSpeechService();
  final device = FakeDeviceBridge();
  final widget = FakeHomeWidgetBridge()
    ..pendingGlasses = widgetGlasses
    ..pendingDay = widgetGlassesDay
    ..olderGlasses.addAll(widgetOlderGlasses);
  // Most tests start on Today, past the first-launch welcome.
  if (!showWelcome) {
    await SettingsRepository(db).setFlag(SettingKeys.welcomeSeen, true);
  }
  if (setup != null) await setup(db);
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock ?? () => testNow),
        reminderPlatformProvider.overrideWithValue(reminders),
        fileSaverProvider.overrideWithValue(files),
        speechServiceProvider.overrideWithValue(speech),
        homeWidgetBridgeProvider.overrideWithValue(widget),
        deviceBridgeProvider.overrideWithValue(device),
      ],
      child: const PetalApp(),
    ),
  );
  await tester.pumpAndSettle();
  return TestApp(db, reminders, files, speech, widget, device);
}
