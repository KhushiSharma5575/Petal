import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) => pumpPetal(tester);

  testWidgets('starts on Today with all nav items labelled', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);

    expect(find.textContaining('Good '), findsOneWidget); // greeting
    for (final label in ['Today tab', 'Tasks tab', 'Money tab', 'Me tab']) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Add by voice'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('tapping tabs switches screens', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.bySemanticsLabel('Tasks tab'));
    await tester.pumpAndSettle();
    expect(find.text('My tasks'), findsOneWidget);

    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();
    expect(find.text('No spends yet'), findsOneWidget);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(find.text('Your week so far'), findsOneWidget);
  });

  testWidgets('mic opens the voice sheet', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.bySemanticsLabel('Add by voice'));
    // The listening bars animate forever, so step time instead of settling.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Listening…'), findsOneWidget);

    await tester.binding.handlePopRoute(); // Back closes it
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Listening…'), findsNothing);
  });

  testWidgets('back on another tab returns to Today', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.textContaining('Good '), findsOneWidget);
  });

  testWidgets('no overflow at 2x system font size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    expect(tester.takeException(), isNull);
  });
}
