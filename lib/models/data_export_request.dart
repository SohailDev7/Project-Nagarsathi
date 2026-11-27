import 'dart:convert';

/// Lifecycle status of a user data export package request.
enum DataExportStatus {
  requested,
  processing,
  sent,
  expired,
  failed;

  static DataExportStatus fromWire(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'processing':
        return DataExportStatus.processing;
      case 'sent':
      case 'ready':
        return DataExportStatus.sent;
      case 'expired':
        return DataExportStatus.expired;
      case 'failed':
        return DataExportStatus.failed;
      default:
        return DataExportStatus.requested;
    }
  }
}

/// Thrown when initiating or loading a data export fails.
class DataExportFailure implements Exception {
  const DataExportFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Metadata for a user's personal data export package request.
class DataExportRequest {
  const DataExportRequest({
    required this.exportId,
    required this.userId,
    required this.email,
    required this.status,
    required this.requestedAt,
    required this.expiresAt,
    this.deliveredAt,
    this.formats = const ['json', 'pdf'],
    this.reportCount = 0,
    this.commentCount = 0,
    this.deliverySlaMinutes = 15,
  });

  static const Duration linkValidity = Duration(hours: 48);

  final String exportId;
  final String userId;
  final String email;
  final DataExportStatus status;
  final DateTime requestedAt;
  final DateTime expiresAt;
  final DateTime? deliveredAt;
  final List<String> formats;
  final int reportCount;
  final int commentCount;
  final int deliverySlaMinutes;

  bool isExpiredAt([DateTime? now]) {
    final clock = now ?? DateTime.now();
    return status == DataExportStatus.expired || !clock.isBefore(expiresAt);
  }

  Duration remainingAt([DateTime? now]) {
    final clock = now ?? DateTime.now();
    final diff = expiresAt.difference(clock);
    return diff.isNegative ? Duration.zero : diff;
  }

  DataExportRequest copyWith({DataExportStatus? status}) {
    return DataExportRequest(
      exportId: exportId,
      userId: userId,
      email: email,
      status: status ?? this.status,
      requestedAt: requestedAt,
      expiresAt: expiresAt,
      deliveredAt: deliveredAt,
      formats: formats,
      reportCount: reportCount,
      commentCount: commentCount,
      deliverySlaMinutes: deliverySlaMinutes,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'exportId': exportId,
      'userId': userId,
      'email': email,
      'status': status.name,
      'formats': formats,
      'requestedAt': requestedAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      if (deliveredAt != null)
        'deliveredAt': deliveredAt!.millisecondsSinceEpoch,
      'reportCount': reportCount,
      'commentCount': commentCount,
      'deliverySlaMinutes': deliverySlaMinutes,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory DataExportRequest.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Invalid DataExportRequest JSON');
    }
    return DataExportRequest.fromMap(Map<String, dynamic>.from(decoded));
  }

  factory DataExportRequest.fromMap(Map<String, dynamic> map) {
    final requestedMs = _asInt(map['requestedAt']) ?? 0;
    final requestedAt = DateTime.fromMillisecondsSinceEpoch(requestedMs);
    final expiresMs = _asInt(map['expiresAt']);
    final expiresAt = expiresMs != null
        ? DateTime.fromMillisecondsSinceEpoch(expiresMs)
        : requestedAt.add(linkValidity);
    final deliveredMs = _asInt(map['deliveredAt']);
    final rawFormats = map['formats'];
    final formats = rawFormats is List
        ? rawFormats.map((e) => e.toString()).toList(growable: false)
        : const <String>['json', 'pdf'];

    final status = DataExportStatus.fromWire(map['status']?.toString());
    final resolvedStatus = !DateTime.now().isBefore(expiresAt)
        ? DataExportStatus.expired
        : status;

    return DataExportRequest(
      exportId: (map['exportId'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      status: resolvedStatus,
      requestedAt: requestedAt,
      expiresAt: expiresAt,
      deliveredAt: deliveredMs != null
          ? DateTime.fromMillisecondsSinceEpoch(deliveredMs)
          : null,
      formats: formats.isEmpty ? const ['json', 'pdf'] : formats,
      reportCount: _asInt(map['reportCount']) ?? 0,
      commentCount: _asInt(map['commentCount']) ?? 0,
      deliverySlaMinutes: _asInt(map['deliverySlaMinutes']) ?? 15,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
