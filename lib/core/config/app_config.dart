import 'package:flutter/foundation.dart';

/// Build-time switches.
abstract final class AppConfig {
  /// Whether to seed the database with fake sample data.
  ///
  /// Only possible in debug builds: `kDebugMode` is a compile-time constant, so
  /// in release builds this is `false` and the sample-data code is removed
  /// from the APK entirely. Release builds always start empty.
  ///
  /// It is on by default in debug. Turn it off with:
  ///   flutter run --dart-define=PETAL_SAMPLE_DATA=false
  static const bool useSampleData =
      kDebugMode &&
      bool.fromEnvironment('PETAL_SAMPLE_DATA', defaultValue: true);
}
