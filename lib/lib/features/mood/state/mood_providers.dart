import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock.dart';
import '../../../data/models/mood.dart';
import '../../../data/providers.dart';

/// Today's mood, or null if not checked in yet.
final todayMoodProvider = StreamProvider<Mood?>((ref) {
  final today = ref.watch(todayProvider);
  return ref.watch(moodRepositoryProvider).watchMood(today);
});

class MoodController {
  MoodController(this._ref);
  final Ref _ref;

  Future<void> setToday(Mood mood) =>
      _ref.read(moodRepositoryProvider).setMood(_ref.read(todayProvider), mood);
}

final moodControllerProvider = Provider<MoodController>(MoodController.new);
