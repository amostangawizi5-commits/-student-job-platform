// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> openPdfBytesInBrowser(
  Uint8List bytes, {
  String fileName = 'document.pdf',
}) async {
  final blob = html.Blob(<dynamic>[bytes], 'application/pdf');
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);

  try {
    final body = html.document.body;
    if (body == null) {
      return false;
    }

    final anchor = html.AnchorElement(href: objectUrl)
      ..target = '_blank'
      ..style.display = 'none';
    anchor.setAttribute('rel', 'noopener noreferrer');
    anchor.setAttribute('data-file-name', fileName);

    body.children.add(anchor);
    anchor.click();
    anchor.remove();

    unawaited(
      Future<void>.delayed(
        const Duration(minutes: 1),
        () => html.Url.revokeObjectUrl(objectUrl),
      ),
    );

    return true;
  } catch (_) {
    html.Url.revokeObjectUrl(objectUrl);
    rethrow;
  }
}
