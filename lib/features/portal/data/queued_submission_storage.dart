import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

abstract class QueuedSubmissionStorage {
  Future<String> persistAudioBytes({
    required String submissionId,
    required String fileName,
    required Uint8List bytes,
  });

  Future<void> deleteIfExists(String path);
}

class FileQueuedSubmissionStorage implements QueuedSubmissionStorage {
  const FileQueuedSubmissionStorage();

  @override
  Future<void> deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<String> persistAudioBytes({
    required String submissionId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final supportDir = await getApplicationSupportDirectory();
    final targetDir = Directory('${supportDir.path}/queued_submissions');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final extension = _safeExtension(fileName);
    final targetPath =
        '${targetDir.path}/$submissionId${extension.isEmpty ? '.m4a' : extension}';
    final file = File(targetPath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  String _safeExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex);
  }
}

final queuedSubmissionStorageProvider = Provider<QueuedSubmissionStorage>((
  ref,
) {
  return const FileQueuedSubmissionStorage();
});
