import 'dart:typed_data';

import 'browser_pdf_opener_stub.dart'
    if (dart.library.html) 'browser_pdf_opener_web.dart' as impl;

Future<bool> openPdfBytesInBrowser(
  Uint8List bytes, {
  String fileName = 'document.pdf',
}) {
  return impl.openPdfBytesInBrowser(bytes, fileName: fileName);
}
