import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import '../models/data_export_request.dart';
import '../utils/data_export_generator.dart';

/// TEMPORARY DEMO ONLY.
///
/// Builds a real JSON + PDF export package from local sample data so the
/// "Download My Data" flow can be demonstrated end to end without the
/// production backend, email delivery, or encrypted link service.
class DataExportDemoResult {
  const DataExportDemoResult({
    required this.request,
    required this.jsonPath,
    required this.pdfPath,
    required this.secureLink,
    required this.jsonBytes,
    required this.pdfBytes,
    required this.deliveredAfter,
  });

  final DataExportRequest request;
  final String jsonPath;
  final String pdfPath;
  final String secureLink;
  final int jsonBytes;
  final int pdfBytes;

  /// Simulated time between the request and the "email sent" step.
  final Duration deliveredAfter;
}

class DataExportDemoService {
  const DataExportDemoService();

  static const Duration _simulatedDelivery = Duration(seconds: 2);
  static const String _fallbackEmail = 'demo.citizen@nagarsathi.app';

  Future<DataExportDemoResult> run({String? email, String locale = 'en'}) async {
    final requestedAt = DateTime.now();
    final deliveredAt = requestedAt.add(_simulatedDelivery);
    final expiresAt = requestedAt.add(DataExportRequest.linkValidity);
    final exportId = 'exp_demo_${requestedAt.millisecondsSinceEpoch}';
    final address = (email != null && email.contains('@'))
        ? email.trim()
        : _fallbackEmail;

    final profile = <String, dynamic>{
      'uid': 'demo-uid-4f8a21',
      'name': 'Demo Citizen',
      'email': address,
      'phone': '+977 98XXXXXXXX',
      'role': 'citizen',
      'preferredLanguage': locale,
      'ward': 'Ward 3 - Jhamsikhel',
      'createdAt': requestedAt
          .subtract(const Duration(days: 220))
          .toUtc()
          .toIso8601String(),
    };

    final reports = <Map<String, dynamic>>[
      {
        'id': 'rep_demo_1001',
        'title': 'Pothole near Jhamsikhel chowk',
        'category': 'Roads',
        'status': 'in_progress',
        'description':
            'Deep pothole on the main road, risky for motorbikes during rain.',
        'createdAt': requestedAt
            .subtract(const Duration(days: 12))
            .toUtc()
            .toIso8601String(),
      },
      {
        'id': 'rep_demo_1002',
        'title': 'Street light not working',
        'category': 'Electricity',
        'status': 'resolved',
        'description':
            'The street light outside the community hall stayed off for a week.',
        'createdAt': requestedAt
            .subtract(const Duration(days: 31))
            .toUtc()
            .toIso8601String(),
      },
      {
        'id': 'rep_demo_1003',
        'title': 'Garbage collection missed',
        'category': 'Sanitation',
        'status': 'open',
        'description':
            'Waste was not collected on the scheduled morning for this ward.',
        'createdAt': requestedAt
            .subtract(const Duration(days: 4))
            .toUtc()
            .toIso8601String(),
      },
    ];

    final comments = <Map<String, dynamic>>[
      {
        'id': 'cmt_demo_2001',
        'reportId': 'rep_demo_1001',
        'text': 'Crew visited today and marked the spot for repair.',
        'createdAt': requestedAt
            .subtract(const Duration(days: 9))
            .toUtc()
            .toIso8601String(),
      },
      {
        'id': 'cmt_demo_2002',
        'reportId': 'rep_demo_1002',
        'text': 'Thank you, the light is working again in the evening.',
        'createdAt': requestedAt
            .subtract(const Duration(days: 27))
            .toUtc()
            .toIso8601String(),
      },
    ];

    final jsonString = DataExportGenerator.generateJson(
      exportId: exportId,
      profile: profile,
      reports: reports,
      comments: comments,
      requestedAt: requestedAt,
      expiresAt: expiresAt,
    );
    final pdfBytes = DataExportGenerator.generatePdf(
      exportId: exportId,
      profile: profile,
      reports: reports,
      comments: comments,
      requestedAt: requestedAt,
      expiresAt: expiresAt,
    );

    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}${Platform.pathSeparator}nagarsathi_demo_export');
    await dir.create(recursive: true);

    final jsonFile = File(
      '${dir.path}${Platform.pathSeparator}nagarsathi-data-export.json',
    );
    await jsonFile.writeAsString(jsonString, flush: true);
    final pdfFile = File(
      '${dir.path}${Platform.pathSeparator}nagarsathi-data-export.pdf',
    );
    await pdfFile.writeAsBytes(pdfBytes, flush: true);

    return DataExportDemoResult(
      request: DataExportRequest(
        exportId: exportId,
        userId: 'demo-uid-4f8a21',
        email: address,
        status: DataExportStatus.sent,
        requestedAt: requestedAt,
        expiresAt: expiresAt,
        deliveredAt: deliveredAt,
        reportCount: reports.length,
        commentCount: comments.length,
      ),
      jsonPath: jsonFile.path,
      pdfPath: pdfFile.path,
      secureLink: 'https://nagarsathi.app/download/$exportId?token=${_token(32)}',
      jsonBytes: jsonString.length,
      pdfBytes: pdfBytes.length,
      deliveredAfter: _simulatedDelivery,
    );
  }

  static String _token(int length) {
    const alphabet = 'abcdef0123456789';
    final random = Random.secure();
    return List<String>.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
