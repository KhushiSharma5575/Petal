import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/settings_repository.dart';
import 'petal_palette.dart';

/// The saved accent theme, live from the `settings` table.
final _savedAccentProvider = StreamProvider<PetalAccent>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.themeAccent)
      .map(
        (name) => PetalAccent.values.firstWhere(
          (a) => a.name == name,
          orElse: () => PetalAccent.lavender,
        ),
      );
});

/// The accent theme in use (Lavender until the saved one has loaded).
final accentProvider = Provider<PetalAccent>((ref) {
  return ref.watch(_savedAccentProvider).value ?? PetalAccent.lavender;
});

/// Saves a new accent theme; the whole app re-themes immediately.
Future<void> setAccent(WidgetRef ref, PetalAccent accent) => ref
    .read(settingsRepositoryProvider)
    .set(SettingKeys.themeAccent, accent.name);
