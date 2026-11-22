import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:petal/data/repositories/settings_repository.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('first launch: slides, name, then Today', (tester) async {
    final app = await pumpPetal(tester, showWelcome: true);
    expect(find.text('Just say it'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Private by design'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('What should I call you?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Khushi');
    await tester.tap(find.text("Let's go"));
    await tester.pumpAndSettle();
    expect(find.text('Good morning!'), findsOneWidget);
    expect(
      await SettingsRepository(app.db).get(SettingKeys.userName),
      'Khushi',
    );
    expect(
      await SettingsRepository(app.db).getFlag(SettingKeys.welcomeSeen),
      isTrue,
    );
  });
}
