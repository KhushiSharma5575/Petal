import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

/// The four tabs in the bottom navigation. The mic in the middle is an action,
/// not a tab, so it isn't listed here.
enum AppTab {
  today('Today', LucideIcons.house),
  tasks('Tasks', LucideIcons.squareCheckBig),
  money('Money', LucideIcons.wallet),
  me('Me', LucideIcons.userRound);

  const AppTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Which tab is showing. Other screens use this to jump between tabs, e.g.
/// tapping "Spent today" on Today calls `select(AppTab.money)`.
class NavNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.today;

  void select(AppTab tab) => state = tab;
}

final navProvider = NotifierProvider<NavNotifier, AppTab>(NavNotifier.new);
