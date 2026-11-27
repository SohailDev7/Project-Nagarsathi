import 'dart:convert';
import 'dart:typed_data';

/// Generates machine-readable JSON, human-readable PDF 1.4, and ZIP archive
/// bytes for a user's personal data export package.
class DataExportGenerator {
  const DataExportGenerator._();

  /// Builds the structured export payload map shared by JSON and PDF outputs.
  static Map<String, dynamic> buildPayload({
    required String exportId,
    required Map<String, dynamic> profile,
    required List<Map<String, dynamic>> reports,
    required List<Map<String, dynamic>> comments,
    required DateTime requestedAt,
    required DateTime expiresAt,
  }) {
    return <String, dynamic>{
      'exportMetadata': <String, dynamic>{
        'exportId': exportId,
        'app': 'NagarSathi',
        'schemaVersion': '1.0',
        'generatedAt': requestedAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'formats': <String>['json', 'pdf'],
      },
      'profile': profile,
      'summary': <String, dynamic>{
        'totalReports': reports.length,
        'totalComments': comments.length,
      },
      'reports': reports,
      'comments': comments,
    };
  }

  /// Generates pretty-printed UTF-8 JSON for machine consumption.
  static String generateJson({
    required String exportId,
    required Map<String, dynamic> profile,
    required List<Map<String, dynamic>> reports,
    required List<Map<String, dynamic>> comments,
    required DateTime requestedAt,
    required DateTime expiresAt,
  }) {
    final payload = buildPayload(
      exportId: exportId,
      profile: profile,
      reports: reports,
      comments: comments,
      requestedAt: requestedAt,
      expiresAt: expiresAt,
    );
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Generates a valid multi-page PDF 1.4 document with profile, reports, and
  /// comments formatted for human reading.
  static Uint8List generatePdf({
    required String exportId,
    required Map<String, dynamic> profile,
    required List<Map<String, dynamic>> reports,
    required List<Map<String, dynamic>> comments,
    required DateTime requestedAt,
    required DateTime expiresAt,
  }) {
    final doc = buildPayload(
      exportId: exportId,
      profile: profile,
      reports: reports,
      comments: comments,
      requestedAt: requestedAt,
      expiresAt: expiresAt,
    );
    final meta = doc['exportMetadata'] as Map<String, dynamic>;

    final entries = <_PdfLine>[
      _PdfLine(_PdfKind.title, 'NagarSathi - Personal Data Export'),
      _PdfLine(_PdfKind.body, 'Export ID: ${meta['exportId']}'),
      _PdfLine(_PdfKind.body, 'Generated At: ${meta['generatedAt']}'),
      _PdfLine(_PdfKind.body, 'Link Expires At: ${meta['expiresAt']}'),
      _PdfLine(
        _PdfKind.body,
        'Summary: ${reports.length} report(s), ${comments.length} comment(s)',
      ),
      _PdfLine(_PdfKind.heading, '1. Profile & Account Information'),
      _PdfLine(_PdfKind.body, 'User ID: ${_fmt(profile['uid'])}'),
      _PdfLine(_PdfKind.body, 'Full Name: ${_fmt(profile['name'])}'),
      _PdfLine(_PdfKind.body, 'Email: ${_fmt(profile['email'])}'),
      _PdfLine(_PdfKind.body, 'Phone: ${_fmt(profile['phone'])}'),
      _PdfLine(_PdfKind.body, 'Role: ${_fmt(profile['role'])}'),
      _PdfLine(
        _PdfKind.body,
        'Preferred Language: ${_fmt(profile['preferredLanguage'])}',
      ),
      _PdfLine(_PdfKind.heading, '2. Submitted Reports (${reports.length})'),
    ];

    if (reports.isEmpty) {
      entries.add(
        const _PdfLine(
          _PdfKind.body,
          'No reports have been submitted on this account yet.',
        ),
      );
    } else {
      for (var i = 0; i < reports.length; i++) {
        final report = reports[i];
        final title = report['title'] ?? report['category'] ?? report['id'];
        entries.add(
          _PdfLine(_PdfKind.subheading, 'Report #${i + 1}: ${_fmt(title)}'),
        );
        entries.add(_PdfLine(_PdfKind.body, 'Report ID: ${_fmt(report['id'])}'));
        if (report['category'] != null) {
          entries.add(
            _PdfLine(_PdfKind.body, 'Category: ${_fmt(report['category'])}'),
          );
        }
        if (report['status'] != null) {
          entries.add(
            _PdfLine(_PdfKind.body, 'Status: ${_fmt(report['status'])}'),
          );
        }
        final body = report['description'] ?? report['details'] ?? report['body'];
        if (body != null) {
          for (final wrapped in _wrap('Description: ${_fmt(body)}')) {
            entries.add(_PdfLine(_PdfKind.body, wrapped));
          }
        }
      }
    }

    entries.add(
      _PdfLine(_PdfKind.heading, '3. Comments & Activity (${comments.length})'),
    );
    if (comments.isEmpty) {
      entries.add(
        const _PdfLine(
          _PdfKind.body,
          'No comments have been posted on this account yet.',
        ),
      );
    } else {
      for (var i = 0; i < comments.length; i++) {
        final comment = comments[i];
        entries.add(
          _PdfLine(
            _PdfKind.subheading,
            'Comment #${i + 1} (${_fmt(comment['id'])})',
          ),
        );
        if (comment['reportId'] != null) {
          entries.add(
            _PdfLine(_PdfKind.body, 'Report ID: ${_fmt(comment['reportId'])}'),
          );
        }
        final text = comment['text'] ?? comment['body'] ?? comment['content'];
        for (final wrapped in _wrap('Text: ${_fmt(text)}')) {
          entries.add(_PdfLine(_PdfKind.body, wrapped));
        }
      }
    }

    const pageWidth = 612;
    const pageHeight = 792;
    const marginX = 50;
    const startY = 742;
    const minY = 56;

    final pages = <List<String>>[];
    var ops = <String>[];
    var y = startY;

    for (final entry in entries) {
      final step = switch (entry.kind) {
        _PdfKind.title => 24,
        _PdfKind.heading => 18,
        _PdfKind.subheading => 16,
        _PdfKind.body => 14,
      };
      if (y - step < minY) {
        pages.add(ops);
        ops = <String>[];
        y = startY;
      }
      final font = switch (entry.kind) {
        _PdfKind.title => '/F2 17',
        _PdfKind.heading => '/F2 13',
        _PdfKind.subheading => '/F2 11',
        _PdfKind.body => '/F1 10',
      };
      ops.add(
        'BT $font Tf 0.12 0.18 0.16 rg $marginX $y Td (${_pdfSafe(entry.text)}) Tj ET',
      );
      y -= step;
    }
    if (ops.isNotEmpty || pages.isEmpty) {
      pages.add(ops);
    }

    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>',
    ];
    final pageIds = <int>[];
    for (var i = 0; i < pages.length; i++) {
      final pageId = objects.length + 1;
      final contentId = objects.length + 2;
      pageIds.add(pageId);
      final stream = [
        ...pages[i],
        'BT /F1 8.5 Tf 0.40 0.45 0.42 rg $marginX 32 Td '
            '(NagarSathi Data Export  |  Page ${i + 1} of ${pages.length}) Tj ET',
      ].join('\n');
      objects.add(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pageWidth $pageHeight] '
        '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents $contentId 0 R >>',
      );
      final streamBytes = utf8.encode(stream);
      objects.add(
        '<< /Length ${streamBytes.length} >>\nstream\n$stream\nendstream',
      );
    }
    objects[1] =
        '<< /Type /Pages /Kids [${pageIds.map((id) => '$id 0 R').join(' ')}] '
        '/Count ${pageIds.length} >>';

    final buffer = BytesBuilder(copy: false);
    buffer.add(utf8.encode('%PDF-1.4\n'));
    final offsets = <int>[0];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(buffer.length);
      buffer.add(utf8.encode('${i + 1} 0 obj\n${objects[i]}\nendobj\n'));
    }
    final xrefOffset = buffer.length;
    buffer.add(utf8.encode('xref\n0 ${objects.length + 1}\n'));
    buffer.add(utf8.encode('0000000000 65535 f \n'));
    for (var i = 1; i <= objects.length; i++) {
      final padded = offsets[i].toString().padLeft(10, '0');
      buffer.add(utf8.encode('$padded 00000 n \n'));
    }
    buffer.add(
      utf8.encode(
        'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
        'startxref\n$xrefOffset\n%%EOF\n',
      ),
    );
    return buffer.toBytes();
  }

  /// Packages the JSON and PDF outputs into a standard PKZIP archive.
  static Uint8List generateZip({
    required String exportId,
    required String jsonString,
    required Uint8List pdfBytes,
    required DateTime requestedAt,
    required DateTime expiresAt,
  }) {
    final readme = [
      'NagarSathi Personal Data Export',
      '===============================',
      'Export ID: $exportId',
      'Generated At: ${requestedAt.toUtc().toIso8601String()}',
      'Link Expires At: ${expiresAt.toUtc().toIso8601String()}',
      '',
      'Included files:',
      '- nagarsathi-data-export.json',
      '- nagarsathi-data-export.pdf',
    ].join('\n');

    return _buildZip(<(String, Uint8List)>[
      ('README.txt', Uint8List.fromList(utf8.encode(readme))),
      ('nagarsathi-data-export.json', Uint8List.fromList(utf8.encode(jsonString))),
      ('nagarsathi-data-export.pdf', pdfBytes),
    ]);
  }

  static String _fmt(Object? value) {
    if (value == null) return 'Not provided';
    final s = value.toString().trim();
    return s.isEmpty ? 'Not provided' : s;
  }

  static String _pdfSafe(String input) {
    final sb = StringBuffer();
    for (final rune in input.runes) {
      if (rune == 0x0A || rune == 0x0D) {
        sb.write(' ');
      } else if (rune == 0x5C) {
        sb.write(r'\\');
      } else if (rune == 0x28) {
        sb.write(r'\(');
      } else if (rune == 0x29) {
        sb.write(r'\)');
      } else if ((rune >= 0x20 && rune <= 0x7E) ||
          (rune >= 0xA0 && rune <= 0xFF)) {
        sb.writeCharCode(rune);
      } else {
        sb.write('?');
      }
    }
    return sb.toString();
  }

  static List<String> _wrap(String text, {int maxChars = 84}) {
    final words = text.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      if (word.isEmpty) continue;
      if (current.isEmpty) {
        current = word;
      } else if (current.length + 1 + word.length <= maxChars) {
        current = '$current $word';
      } else {
        lines.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.isEmpty ? <String>[''] : lines;
  }

  static final List<int> _crcTable = List<int>.generate(256, (i) {
    var c = i;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : (c >> 1);
    }
    return c & 0xFFFFFFFF;
  });

  static int _crc32(Uint8List data) {
    var crc = 0xFFFFFFFF;
    for (final b in data) {
      crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >> 8);
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static Uint8List _buildZip(List<(String, Uint8List)> files) {
    final localParts = <Uint8List>[];
    final centralParts = <Uint8List>[];
    var offset = 0;

    for (final (name, data) in files) {
      final nameBytes = Uint8List.fromList(utf8.encode(name));
      final sum = _crc32(data);

      final local = ByteData(30 + nameBytes.length);
      local.setUint32(0, 0x04034b50, Endian.little);
      local.setUint16(4, 20, Endian.little);
      local.setUint16(6, 0x0800, Endian.little);
      local.setUint16(8, 0, Endian.little);
      local.setUint32(14, sum, Endian.little);
      local.setUint32(18, data.length, Endian.little);
      local.setUint32(22, data.length, Endian.little);
      local.setUint16(26, nameBytes.length, Endian.little);
      final localBytes = local.buffer.asUint8List();
      localBytes.setRange(30, 30 + nameBytes.length, nameBytes);
      localParts.add(localBytes);
      localParts.add(data);

      final central = ByteData(46 + nameBytes.length);
      central.setUint32(0, 0x02014b50, Endian.little);
      central.setUint16(4, 20, Endian.little);
      central.setUint16(6, 20, Endian.little);
      central.setUint16(8, 0x0800, Endian.little);
      central.setUint32(16, sum, Endian.little);
      central.setUint32(20, data.length, Endian.little);
      central.setUint32(24, data.length, Endian.little);
      central.setUint16(28, nameBytes.length, Endian.little);
      central.setUint32(42, offset, Endian.little);
      final centralBytes = central.buffer.asUint8List();
      centralBytes.setRange(46, 46 + nameBytes.length, nameBytes);
      centralParts.add(centralBytes);

      offset += localBytes.length + data.length;
    }

    var centralSize = 0;
    for (final part in centralParts) {
      centralSize += part.length;
    }

    final end = ByteData(22);
    end.setUint32(0, 0x06054b50, Endian.little);
    end.setUint16(8, files.length, Endian.little);
    end.setUint16(10, files.length, Endian.little);
    end.setUint32(12, centralSize, Endian.little);
    end.setUint32(16, offset, Endian.little);

    final out = BytesBuilder(copy: false);
    for (final part in localParts) {
      out.add(part);
    }
    for (final part in centralParts) {
      out.add(part);
    }
    out.add(end.buffer.asUint8List());
    return out.toBytes();
  }
}

enum _PdfKind { title, heading, subheading, body }

class _PdfLine {
  const _PdfLine(this.kind, this.text);

  final _PdfKind kind;
  final String text;
}
