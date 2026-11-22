import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/theme/petal_tokens.dart';
import 'data/providers.dart';
import 'data/sample/sample_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicences();

  // Draw edge to edge, with dark status bar icons on the cream background and
  // a white system nav bar that matches our bottom bar.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: PetalColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final container = ProviderContainer();

  // Debug builds only (no-op in release): add example data on first run.
  final now = DateTime.now();
  await seedSampleDataIfNeeded(
    tasks: container.read(taskRepositoryProvider),
    settings: container.read(settingsRepositoryProvider),
    today: now,
  );
  await seedSampleHabitsIfNeeded(
    habits: container.read(habitRepositoryProvider),
    moods: container.read(moodRepositoryProvider),
    settings: container.read(settingsRepositoryProvider),
    today: now,
  );
  await seedSampleMoneyIfNeeded(
    money: container.read(expenseRepositoryProvider),
    settings: container.read(settingsRepositoryProvider),
    today: now,
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const PetalApp()),
  );
}

/// The bundled fonts are OFL licensed; the licence asks us to ship the licence
/// text. Registering it makes it appear in Flutter's licence page.
void _registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final (name, file) in const [
      ('Nunito', 'assets/fonts/OFL-Nunito.txt'),
      ('Pacifico', 'assets/fonts/OFL-Pacifico.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString(file));
    }
  });
}
