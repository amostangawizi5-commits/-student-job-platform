import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class LocalFileService {
  static const MethodChannel _downloadsChannel = MethodChannel(
    'student_app/downloads',
  );

  static Future<String> copyFileToDownloads(
    String sourcePath, {
    required String fileName,
    String mimeType = 'application/pdf',
  }) async {
    if (!Platform.isAndroid) {
      return sourcePath;
    }

    final savedPath = await _downloadsChannel.invokeMethod<String>(
      'copyFileToDownloads',
      {'sourcePath': sourcePath, 'fileName': fileName, 'mimeType': mimeType},
    );

    if (savedPath == null || savedPath.trim().isEmpty) {
      throw const FileSystemException('Could not save file to Downloads.');
    }

    return savedPath;
  }

  static Future<bool> openFile(
    String filePath, {
    String mimeType = 'application/pdf',
  }) async {
    if (Platform.isAndroid) {
      final opened = await _downloadsChannel.invokeMethod<bool>('openFile', {
        'filePath': filePath,
        'mimeType': mimeType,
      });
      return opened ?? false;
    }

    final uri = Uri.file(filePath);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
