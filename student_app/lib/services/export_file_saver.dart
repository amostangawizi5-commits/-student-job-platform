import 'dart:typed_data';

import 'export_file_saver_stub.dart'
    if (dart.library.io) 'export_file_saver_io.dart'
    if (dart.library.html) 'export_file_saver_web.dart'
    as impl;

Future<String> saveExportFile({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) {
  return impl.saveExportFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
  );
}
