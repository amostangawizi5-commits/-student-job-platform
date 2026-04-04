import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const MethodChannel _downloadsChannel = MethodChannel('student_app/downloads');

Future<String> saveExportFile({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) async {
  if (Platform.isAndroid) {
    final tempDirectory = await getTemporaryDirectory();
    final tempFile = File('${tempDirectory.path}/$fileName');
    await tempFile.writeAsBytes(bytes, flush: true);

    try {
      final savedPath = await _downloadsChannel.invokeMethod<String>(
        'copyFileToDownloads',
        {
          'sourcePath': tempFile.path,
          'fileName': fileName,
          'mimeType': mimeType,
        },
      );

      if (savedPath == null || savedPath.trim().isEmpty) {
        throw const FileSystemException('Could not save file to Downloads.');
      }

      return savedPath;
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  final directory = await _ensureExportDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<Directory> _ensureExportDirectory() async {
  final exportDirectory = await _preferredFilesystemDirectory();
  if (!await exportDirectory.exists()) {
    await exportDirectory.create(recursive: true);
  }
  return exportDirectory;
}

Future<Directory> _preferredFilesystemDirectory() async {
  if (Platform.isAndroid) {
    final commonDownloadDirs = [
      Directory('/storage/emulated/0/Download'),
      Directory('/sdcard/Download'),
    ];

    for (final directory in commonDownloadDirs) {
      if (await directory.exists()) {
        return directory;
      }
    }

    final externalDirectories = await getExternalStorageDirectories(
      type: StorageDirectory.downloads,
    );
    if (externalDirectories != null && externalDirectories.isNotEmpty) {
      return externalDirectories.first;
    }
  }

  final downloadsDirectory = await getDownloadsDirectory();
  if (downloadsDirectory != null) {
    return Directory('${downloadsDirectory.path}/admin_exports');
  }

  final baseDirectory = await getApplicationDocumentsDirectory();
  return Directory('${baseDirectory.path}/admin_exports');
}
