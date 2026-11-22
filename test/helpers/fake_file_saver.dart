import 'dart:convert';

import 'package:petal/core/platform/file_saver.dart';

/// Records what would have been written to Downloads.
class FakeFileSaver implements FileSaver {
  String? savedName;
  List<int>? savedBytes;

  /// Set to simulate the user cancelling or a failure.
  bool cancel = false;
  String? failWith;

  /// What [pickFile] returns (null = user cancelled).
  List<int>? fileToPick;

  String get savedText => utf8.decode(savedBytes!.skip(3).toList());

  @override
  Future<List<int>?> pickFile() async {
    if (failWith != null) throw FileSaveException(failWith!);
    return fileToPick;
  }

  @override
  Future<String?> saveToDownloads({
    required String name,
    required String mimeType,
    required List<int> bytes,
  }) async {
    if (failWith != null) throw FileSaveException(failWith!);
    if (cancel) return null;
    savedName = name;
    savedBytes = bytes;
    return 'Downloads/$name';
  }
}
