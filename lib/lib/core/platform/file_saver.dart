import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Saves files to Downloads and lets the user pick a file to open.
abstract class FileSaver {
  /// Returns where it was saved (e.g. "Downloads/x.csv"), or null if the
  /// user cancelled the save screen. Throws [FileSaveException] on failure.
  Future<String?> saveToDownloads({
    required String name,
    required String mimeType,
    required List<int> bytes,
  });

  /// Shows the system file picker and returns the chosen file's bytes, or
  /// null if cancelled. Throws [FileSaveException] if it can't be read.
  Future<List<int>?> pickFile();
}

class FileSaveException implements Exception {
  FileSaveException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Uses Petal's own small Android code (MainActivity.kt), no plugin.
class AndroidFileSaver implements FileSaver {
  static const _channel = MethodChannel('petal/files');

  @override
  Future<String?> saveToDownloads({
    required String name,
    required String mimeType,
    required List<int> bytes,
  }) async {
    try {
      return await _channel.invokeMethod<String>('saveToDownloads', {
        'name': name,
        'mime': mimeType,
        'bytes': Uint8List.fromList(bytes),
      });
    } on PlatformException catch (e) {
      throw FileSaveException(e.message ?? 'Couldn\'t save the file');
    }
  }

  @override
  Future<List<int>?> pickFile() async {
    try {
      return await _channel.invokeMethod<Uint8List>('openDocument');
    } on PlatformException catch (e) {
      throw FileSaveException(e.message ?? 'Couldn\'t open the file');
    }
  }
}

final fileSaverProvider = Provider<FileSaver>((ref) => AndroidFileSaver());
