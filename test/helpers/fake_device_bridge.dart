import 'dart:async';

import 'package:petal/core/platform/device_bridge.dart';

/// Pretend voice and sensors: tests push step totals and face-down changes.
class FakeDeviceBridge implements DeviceBridge {
  final spoken = <String>[];
  bool stepCounter = true;
  bool activityAllowed = true;
  final stepsController = StreamController<int>.broadcast();
  final faceDownController = StreamController<bool>.broadcast();

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stopSpeaking() async {}

  @override
  Future<bool> hasStepCounter() async => stepCounter;

  @override
  Future<bool> requestActivityPermission() async => activityAllowed;

  @override
  Stream<int> steps() => stepsController.stream;

  @override
  Stream<bool> faceDown() => faceDownController.stream;

  bool screenKeptOn = false;

  @override
  Future<void> keepScreenOn(bool on) async => screenKeptOn = on;
}
