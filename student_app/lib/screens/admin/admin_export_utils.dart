import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

enum AdminExportFormat { pdf, excel, csv }

class AdminExportUtils {
  static const MethodChannel _downloadsChannel = MethodChannel(
    'student_app/downloads',
  );

  static Future<void> showExportDialog(
    BuildContext context, {
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    String filePrefix = 'admin_export',
  }) async {
    final format = await showDialog<AdminExportFormat>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Export $title'),
        content: const Text('Choose the file format to download.'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(AdminExportFormat.pdf),
            child: const Text('PDF'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(AdminExportFormat.excel),
            child: const Text('Excel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(AdminExportFormat.csv),
            child: const Text('CSV'),
          ),
        ],
      ),
    );

    if (format == null || !context.mounted) return;

    try {
      final path = await exportRecords(
        title: title,
        headers: headers,
        rows: rows,
        format: format,
        filePrefix: filePrefix,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export saved to $path')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<String> exportRecords({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    required AdminExportFormat format,
    String filePrefix = 'admin_export',
  }) async {
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final baseName = '${_slugify(filePrefix)}_$timestamp';

    switch (format) {
      case AdminExportFormat.csv:
        final fileName = '$baseName.csv';
        final bytes = Uint8List.fromList(
          utf8.encode(_buildCsv(headers, rows)),
        );
        return _saveExportFile(
          fileName: fileName,
          bytes: bytes,
          mimeType: 'text/csv',
        );
      case AdminExportFormat.excel:
        final fileName = '$baseName.xls';
        final bytes = Uint8List.fromList(
          utf8.encode(_buildExcelHtml(title, headers, rows)),
        );
        return _saveExportFile(
          fileName: fileName,
          bytes: bytes,
          mimeType: 'application/vnd.ms-excel',
        );
      case AdminExportFormat.pdf:
        final fileName = '$baseName.pdf';
        final lines = <String>[
          headers.join(' | '),
          for (final row in rows) row.join(' | '),
        ];
        return _saveExportFile(
          fileName: fileName,
          bytes: _buildSimplePdf(title, lines),
          mimeType: 'application/pdf',
        );
    }
  }

  static Future<String> _saveExportFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (Platform.isAndroid) {
      try {
        final savedPath = await _downloadsChannel.invokeMethod<String>(
          'saveToDownloads',
          {
            'fileName': fileName,
            'mimeType': mimeType,
            'bytes': bytes,
          },
        );

        if (savedPath != null && savedPath.isNotEmpty) {
          return savedPath;
        }
      } on PlatformException {
        // Fall back to filesystem storage below.
      }
    }

    final directory = await _ensureExportDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<Directory> _ensureExportDirectory() async {
    final exportDirectory = await _preferredFilesystemDirectory();
    if (!await exportDirectory.exists()) {
      await exportDirectory.create(recursive: true);
    }
    return exportDirectory;
  }

  static Future<Directory> _preferredFilesystemDirectory() async {
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

  static String _buildCsv(List<String> headers, List<List<String>> rows) {
    final buffer = StringBuffer()
      ..writeln(headers.map(_escapeCsvCell).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_escapeCsvCell).join(','));
    }
    return buffer.toString();
  }

  static String _escapeCsvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  static String _buildExcelHtml(
    String title,
    List<String> headers,
    List<List<String>> rows,
  ) {
    final headerMarkup = headers
        .map((header) => '<th>${htmlEscape.convert(header)}</th>')
        .join();
    final rowMarkup = rows
        .map(
          (row) =>
              '<tr>${row.map((cell) => '<td>${htmlEscape.convert(cell)}</td>').join()}</tr>',
        )
        .join();

    return '''
<html>
  <head>
    <meta charset="utf-8">
    <style>
      body { font-family: Arial, sans-serif; padding: 24px; }
      table { border-collapse: collapse; width: 100%; }
      th, td { border: 1px solid #d1d5db; padding: 10px; text-align: left; }
      th { background: #eff6ff; }
    </style>
  </head>
  <body>
    <h2>${htmlEscape.convert(title)}</h2>
    <table>
      <thead><tr>$headerMarkup</tr></thead>
      <tbody>$rowMarkup</tbody>
    </table>
  </body>
</html>
''';
  }

  static Uint8List _buildSimplePdf(String title, List<String> lines) {
    final sanitizedLines = <String>[
      _sanitizePdfText(title),
      '',
      ...lines.map(_sanitizePdfText),
    ];

    final content = StringBuffer()
      ..writeln('BT')
      ..writeln('/F1 12 Tf')
      ..writeln('14 TL')
      ..writeln('50 790 Td');

    for (var i = 0; i < sanitizedLines.length; i++) {
      final line = sanitizedLines[i];
      if (i == 0) {
        content.writeln('(${_escapePdf(line)}) Tj');
      } else {
        content.writeln('T* (${_escapePdf(line)}) Tj');
      }
    }
    content.writeln('ET');

    final objects = <String>[
      '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj',
      '2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj',
      '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >> endobj',
      '4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj',
      '5 0 obj << /Length ${latin1.encode(content.toString()).length} >> stream\n$content\nendstream\nendobj',
    ];

    final buffer = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    for (final object in objects) {
      offsets.add(latin1.encode(buffer.toString()).length);
      buffer.writeln(object);
    }

    final xrefStart = latin1.encode(buffer.toString()).length;
    buffer.writeln('xref');
    buffer.writeln('0 ${objects.length + 1}');
    buffer.writeln('0000000000 65535 f ');
    for (var i = 1; i < offsets.length; i++) {
      buffer.writeln('${offsets[i].toString().padLeft(10, '0')} 00000 n ');
    }
    buffer.writeln('trailer << /Size ${objects.length + 1} /Root 1 0 R >>');
    buffer.writeln('startxref');
    buffer.writeln(xrefStart);
    buffer.writeln('%%EOF');

    return Uint8List.fromList(latin1.encode(buffer.toString()));
  }

  static String _sanitizePdfText(String value) {
    return value.replaceAll(RegExp(r'[^\x20-\x7E]'), '?');
  }

  static String _escapePdf(String value) {
    return value
        .replaceAll('\\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }

  static String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
