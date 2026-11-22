import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/shell/app_shell.dart';
import 'core/theme/petal_theme.dart';
import 'core/theme/petal_tokens.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/clock.dart';
import 'features/me/state/me_providers.dart';
import 'features/tasks/state/reminder_sync.dart';
import 'features/today/logic/greeting.dart';
import 'features/today/state/home_widget_sync.dart';
import 'features/welcome/welcome_screen.dart';

/// Root widget. Rebuilds the theme when the user switches accent.
class PetalApp extends ConsumerStatefulWidget {
  const PetalApp({super.key});

  @override
  ConsumerState<PetalApp> createState() => _PetalAppState();
}

class _PetalAppState extends ConsumerState<PetalApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        // Coming back the next morning should show the new day...
        ref.read(todayProvider.notifier).refresh();
        ref.read(greetingProvider.notifier).refresh();
        // ...tidy reminders (clears tray notifications for tasks done
        // meanwhile)...
        ref.invalidate(reminderSyncRunnerProvider);
        // ...and count any "+ glass" taps made on the home-screen widget.
        mergeWidgetGlasses(ref);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => mergeWidgetGlasses(ref),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Background jobs that run for as long as the app is open: phone
    // notifications in line with tasks and settings, and the home-screen
    // widget in line with today's data.
    ref.watch(reminderSyncRunnerProvider);
    ref.watch(waterReminderRunnerProvider);
    ref.watch(homeWidgetSyncProvider);
    final accent = ref.watch(accentProvider);
    return MaterialApp(
      title: 'Petal',
      debugShowCheckedModeBanner: false,
      theme: buildPetalTheme(accent),
      // Petal is light-only for now; the pastel design has no dark variant.
      themeMode: ThemeMode.light,
      home: switch (ref.watch(welcomeSeenProvider).value) {
        true => const AppShell(),
        false => const WelcomeScreen(),
        // Loading (a few milliseconds): cream, like the splash.
        null => const ColoredBox(color: PetalColors.background),
      },
    );
  }
}
