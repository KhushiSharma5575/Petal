import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:petal/core/utils/dates.dart';
import 'package:petal/data/models/habit.dart';
import 'package:petal/data/models/mood.dart';
import 'package:petal/data/models/task.dart';
import 'package:petal/data/repositories/expense_repository.dart';
import 'package:petal/data/repositories/habit_repository.dart';
import 'package:petal/data/repositories/mood_repository.dart';
import 'package:petal/data/repositories/task_repository.dart';
import 'package:petal/features/voice/state/speech_service.dart';

import '../../../helpers/test_app.dart';

final today = dateOnly(testNow);

/// While listening, bars animate forever: step time instead of settling.
Future<void> step(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<TestApp> openMic(WidgetTester tester, {TestApp? app}) async {
  final a = app ?? await pumpPetal(tester);
  await tester.tap(find.bySemanticsLabel('Add by voice'));
  await step(tester);
  return a;
}

void main() {
  testWidgets('say a task -> confirmation card -> Save creates it', (
    tester,
  ) async {
    final app = await openMic(tester);
    expect(find.text('Listening…'), findsOneWidget);

    app.speech.say('add call the plumber tomorrow at 10 am high priority');
    await tester.pumpAndSettle();
    expect(find.text('I\'ll save:'), findsOneWidget);
    expect(
      find.text(
        'Task: "Call the plumber" · Tomorrow, 10 am · High priority · Personal',
      ),
      findsOneWidget,
    );
    // Nothing saved until Save is tapped.
    expect(await TaskRepository(app.db).getAll(), isEmpty);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = (await TaskRepository(app.db).getAll()).single;
    expect(saved.title, 'Call the plumber');
    expect(saved.priority, TaskPriority.high);
    expect(find.textContaining('Saved.'), findsOneWidget);
  });

  testWidgets('Undo after saving removes the task', (tester) async {
    final app = await openMic(tester);
    app.speech.say('add buy milk');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(await TaskRepository(app.db).getAll(), hasLength(1));

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await TaskRepository(app.db).getAll(), isEmpty);
  });

  testWidgets('a spend, a habit and a mood each save correctly', (
    tester,
  ) async {
    final app = await openMic(tester);
    app.speech.say('spent 250 on lunch');
    await tester.pumpAndSettle();
    expect(find.text('Spend: ₹250 · Food · "Lunch" · Today'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await ExpenseRepository(app.db).getAll()).single.amount, 25000);

    await openMic(tester, app: app);
    app.speech.say('drank 2 glasses of water');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final water = (await HabitRepository(app.db).getHabits(today))
        .firstWhere((h) => h.habit.key == HabitKeys.water);
    expect(water.valueOn(today), 2);
    expect(find.text('2/8'), findsOneWidget); // Today's water card updated

    await openMic(tester, app: app);
    app.speech.say('feeling great');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(await MoodRepository(app.db).getMood(today), Mood.great);
    expect(find.text('Feeling great'), findsOneWidget);
  });

  testWidgets('three spends in one sentence save together, Undo removes all', (
    tester,
  ) async {
    final app = await openMic(tester);
    app.speech.say('spent 100 on food 200 on travel and 50 on coffee');
    await tester.pumpAndSettle();
    expect(find.textContaining('3 spends, ₹350 in total'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = await ExpenseRepository(app.db).getAll();
    expect(saved.map((e) => e.amount).toSet(), {10000, 20000, 5000});

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await ExpenseRepository(app.db).getAll(), isEmpty);
  });

  testWidgets('the Undo bar goes away by itself', (tester) async {
    final app = await openMic(tester);
    app.speech.say('add buy milk');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsNothing);
    expect(await TaskRepository(app.db).getAll(), hasLength(1));
  });

  testWidgets('Edit lets you fix the words before saving', (tester) async {
    final app = await openMic(tester);
    app.speech.say('add call the plumber tomorrow');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'add call the electrician on monday',
    );
    await tester.pump();
    expect(
      find.text('Task: "Call the electrician" · Monday · Personal'),
      findsOneWidget,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = (await TaskRepository(app.db).getAll()).single;
    expect(saved.title, 'Call the electrician');
    expect(saved.dueDate, DateTime(2026, 11, 16));
  });

  testWidgets('not understood: no Save button, offers Try again / Type it', (
    tester,
  ) async {
    final app = await openMic(tester);
    app.speech.say('um');
    await tester.pumpAndSettle();
    expect(find.textContaining('Sorry, I didn\'t catch that'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Type it'), findsOneWidget);
  });

  testWidgets('missing offline pack explains, and typing still works', (
    tester,
  ) async {
    final app = await pumpPetal(tester);
    app.speech.initProblem = SpeechProblem.offlinePackMissing;
    await openMic(tester, app: app);
    await tester.pumpAndSettle();
    expect(find.text('Offline speech isn\'t set up'), findsOneWidget);
    expect(find.textContaining('never leaves the phone'), findsOneWidget);

    await tester.tap(find.text('Type instead'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'uber 180');
    await tester.pumpAndSettle(); // let the sheet finish resizing
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await ExpenseRepository(app.db).getAll()).single.amount, 18000);
  });

  testWidgets('mic permission refused', (tester) async {
    final app = await pumpPetal(tester);
    app.speech.initProblem = SpeechProblem.noPermission;
    await openMic(tester, app: app);
    await tester.pumpAndSettle();
    expect(find.text('Microphone is off'), findsOneWidget);
  });

  testWidgets('silence while listening says nothing was heard', (tester) async {
    final app = await openMic(tester);
    app.speech.fail(SpeechProblem.noMatch);
    await tester.pumpAndSettle();
    expect(find.text('I didn\'t hear anything'), findsOneWidget);
  });

  testWidgets('closing the sheet while listening stops the mic', (
    tester,
  ) async {
    final app = await openMic(tester);
    await tester.binding.handlePopRoute();
    await step(tester);
    expect(app.speech.cancels, 1);
  });

  testWidgets('asking a question: answer on screen and out loud', (
    tester,
  ) async {
    final app = await openMic(tester);
    app.speech.say('how much water today');
    await tester.pumpAndSettle();
    expect(find.text('You asked'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(app.device.spoken.single, startsWith("You've had 0 of 8 glasses"));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('You asked'), findsNothing);
  });
}
