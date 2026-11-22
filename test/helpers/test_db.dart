import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:petal/data/db/app_database.dart';

/// A fresh in-memory database for each test.
///
/// `closeStreamsSynchronously` stops drift leaving timers pending when a
/// widget test ends.
AppDatabase newTestDatabase() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);
