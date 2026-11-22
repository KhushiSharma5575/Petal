import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/me/ui/me_screen.dart';
import '../../features/money/ui/money_screen.dart';
import '../../features/tasks/ui/tasks_screen.dart';
import '../../features/today/ui/today_screen.dart';
import '../../features/voice/ui/voice_sheet.dart';
import 'nav_state.dart';
import 'petal_nav_bar.dart';

/// The root screen: the four tabs plus the bottom nav bar.
///
/// An [IndexedStack] keeps every tab alive, so scroll positions and anything
/// typed are kept when switching tabs.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(navProvider);
    final nav = ref.read(navProvider.notifier);

    return PopScope(
      // Android back on another tab goes to Today first. Back on Today exits.
      canPop: tab == AppTab.today,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) nav.select(AppTab.today);
      },
      child: Scaffold(
        // Let content scroll behind the nav bar (needed for the raised mic).
        extendBody: true,
        body: IndexedStack(
          index: tab.index,
          children: const [
            TodayScreen(),
            TasksScreen(),
            MoneyScreen(),
            MeScreen(),
          ],
        ),
        bottomNavigationBar: PetalNavBar(
          current: tab,
          onSelect: nav.select,
          onMic: () => showVoiceSheet(context),
        ),
      ),
    );
  }
}
