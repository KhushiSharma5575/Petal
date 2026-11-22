import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The phone's voice and sensors (MainActivity.kt / PetalSensors.kt).
/// Sensors are only listened to while a session screen is open. Tests use
/// a fake.
abstract class DeviceBridge {
  /// Says [text] out loud with the phone's offline voice.
  Future<void> speak(String text);
  Future<void> stopSpeaking();

  Future<bool> hasStepCounter();

  /// Asks for "Physical activity" (needed for steps on Android 10+).
  Future<bool> requestActivityPermission();

  /// The phone's running step total. Errors if there is no step counter.
  Stream<int> steps();

  /// True while the phone lies screen-down.
  Stream<bool> faceDown();

  /// Keeps the screen from turning off (during the focus timer only).
  Future<void> keepScreenOn(bool on);
}

class AndroidDeviceBridge implements DeviceBridge {
  static const _device = MethodChannel('petal/device');
  static const _steps = EventChannel('petal/steps');
  static const _faceDown = EventChannel('petal/facedown');

  @override
  Future<void> speak(String text) async {
    try {
      await _device.invokeMethod<void>('speak', {'text': text});
    } on MissingPluginException {
      // Not on Android.
    } on PlatformException {
      // No voice installed: the answer is still on screen.
    }
  }

  @override
  Future<void> stopSpeaking() async {
    try {
      await _device.invokeMethod<void>('stopSpeaking');
    } on MissingPluginException {
      // Not on Android.
    }
  }

  @override
  Future<bool> hasStepCounter() async {
    try {
      return await _device.invokeMethod<bool>('hasStepCounter') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> requestActivityPermission() async {
    try {
      return await _device.invokeMethod<bool>('requestActivityPermission') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Stream<int> steps() =>
      _steps.receiveBroadcastStream().map((v) => (v as num).toInt());

  @override
  Future<void> keepScreenOn(bool on) async {
    try {
      await _device.invokeMethod<void>('keepScreenOn', {'on': on});
    } on MissingPluginException {
      // Not on Android.
    }
  }

  @override
  Stream<bool> faceDown() =>
      _faceDown.receiveBroadcastStream().map((v) => v == true);
}

final deviceBridgeProvider = Provider<DeviceBridge>(
  (ref) => AndroidDeviceBridge(),
);
