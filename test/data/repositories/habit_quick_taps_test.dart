import 'package:flutter_test/flutter_test.dart';
import 'package:petal/data/models/habit.dart';
import 'package:petal/data/repositories/habit_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  final today = DateTime(2026, 11, 13);

  test('two quick "+30" taps both count, capped at a day', () async {
    final db = newTestDatabase();
    addTearDown(db.close);
    final repo = HabitRepository(db);
    final study = (await repo.getHabits(today))
        .firstWhere((h) => h.habit.key == HabitKeys.study)
        .habit;
    await Future.wait([
      repo.addValue(study.id, today, 30),
      repo.addValue(study.id, today, 30),
    ]);
    expect(await repo.getValue(study.id, today), 60);
    await repo.addValue(study.id, today, 5000);
    expect(await repo.getValue(study.id, today), 1440);
  });
}
