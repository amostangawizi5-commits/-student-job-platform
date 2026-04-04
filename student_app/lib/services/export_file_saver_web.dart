// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<String> saveExportFile({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final blob = html.Blob(<dynamic>[bytes], mimeType);
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);

  try {
    final body = html.document.body;
    if (body == null) {
      throw StateError('Browser document body is not available.');
    }

    final anchor = html.AnchorElement(href: objectUrl)
      ..download = fileName
      ..style.display = 'none';
    anchor.setAttribute('rel', 'noopener noreferrer');

    body.children.add(anchor);
    anchor.click();
    anchor.remove();

    unawaited(
      Future<void>.delayed(
        const Duration(minutes: 1),
        () => html.Url.revokeObjectUrl(objectUrl),
      ),
    );

    return 'browser downloads';
  } catch (_) {
    html.Url.revokeObjectUrl(objectUrl);
    rethrow;
  }
}
