import 'package:drift/drift.dart';

import '../../core/utils/dates.dart';
import '../db/app_database.dart';
import '../models/mood.dart';

/// One mood per calendar day.
class MoodRepository {
  MoodRepository(this._db);

  final AppDatabase _db;

  Stream<Mood?> watchMood(DateTime day) {
    final date = toIsoDate(day);
    return (_db.select(_db.moods)..where((m) => m.date.equals(date)))
        .watchSingleOrNull()
        .map((r) => Mood.tryParse(r?.mood));
  }

  /// Sets (or replaces) the mood for [day]; null clears it.
  Future<void> setMood(DateTime day, Mood? mood) {
    final date = toIsoDate(day);
    if (mood == null) {
      return (_db.delete(_db.moods)..where((m) => m.date.equals(date))).go();
    }
    return _db
        .into(_db.moods)
        .insertOnConflictUpdate(
          MoodsCompanion.insert(date: date, mood: mood.name),
        );
  }

  /// Moods from [from] to [to] inclusive.
  Future<Map<DateTime, Mood>> moodsBetween(DateTime from, DateTime to) async =>
      _toMap(await _between(from, to).get());

  /// One day's mood (one-off read).
  Future<Mood?> getMood(DateTime day) async {
    final row = await (_db.select(
      _db.moods,
    )..where((m) => m.date.equals(toIsoDate(day)))).getSingleOrNull();
    return Mood.tryParse(row?.mood);
  }

  /// Live version, for the Me calendar.
  Stream<Map<DateTime, Mood>> watchBetween(DateTime from, DateTime to) =>
      _between(from, to).watch().map(_toMap);

  SimpleSelectStatement<$MoodsTable, MoodRow> _between(
    DateTime from,
    DateTime to,
  ) =>
      _db.select(_db.moods)
        ..where((m) => m.date.isBetweenValues(toIsoDate(from), toIsoDate(to)));

  static Map<DateTime, Mood> _toMap(List<MoodRow> rows) => {
    for (final r in rows)
      // `?value` skips the entry when the stored mood is unrecognised.
      fromIsoDate(r.date): ?Mood.tryParse(r.mood),
  };
}
