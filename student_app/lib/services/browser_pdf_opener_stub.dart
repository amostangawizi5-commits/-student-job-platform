import 'dart:typed_data';

Future<bool> openPdfBytesInBrowser(
  Uint8List bytes, {
  String fileName = 'document.pdf',
}) async {
  throw UnsupportedError('Browser PDF opening is only supported on web.');
}
