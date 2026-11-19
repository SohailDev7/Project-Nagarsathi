import 'package:cloud_firestore/cloud_firestore.dart';

/// Employment status of a ward officer account.
enum OfficerStatus {
  active('active'),
  suspended('suspended');

  const OfficerStatus(this.value);

  /// Stable value used for persistence and audit entries.
  final String value;

  static OfficerStatus fromValue(Object? value) {
    final normalized = value is String ? value.trim().toLowerCase() : '';
    return OfficerStatus.values.firstWhere(
      (status) => status.value == normalized,
      orElse: () => OfficerStatus.active,
    );
  }

  String get label => this == OfficerStatus.active ? 'Active' : 'Suspended';
}

/// A ward officer account managed by an app admin.
class WardOfficer {
  const WardOfficer({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.assignedWard,
    required this.status,
    required this.createdAt,
  });

  /// Lowest ward number accepted by the app.
  static const int minWard = 1;

  /// Highest ward number accepted by the app.
  static const int maxWard = 32;

  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;

  /// Ward assigned to the officer, between [minWard] and [maxWard].
  final int assignedWard;

  final OfficerStatus status;
  final DateTime createdAt;

  bool get isActive => status == OfficerStatus.active;

  String get wardLabel => 'Ward $assignedWard';

  static bool isValidWard(int ward) => ward >= minWard && ward <= maxWard;

  WardOfficer copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phoneNumber,
    int? assignedWard,
    OfficerStatus? status,
    DateTime? createdAt,
  }) {
    return WardOfficer(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      assignedWard: assignedWard ?? this.assignedWard,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'assignedWard': assignedWard,
      'status': status.value,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WardOfficer.fromJson(Map<String, dynamic> json) {
    return WardOfficer(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      assignedWard: (json['assignedWard'] as num?)?.toInt() ?? minWard,
      status: OfficerStatus.fromValue(json['status']),
      createdAt: _parseDate(json['createdAt']),
    );
  }

  /// Firestore document payload. Timestamps are stored as native
  /// [Timestamp] values so they remain queryable server-side.
  ///
  /// [emailLower] is a derived field used for case-insensitive unique-email
  /// queries in Firestore; it is not part of the model's public state.
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'emailLower': email.trim().toLowerCase(),
      'phoneNumber': phoneNumber,
      'assignedWard': assignedWard,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Reads either a Firestore document or a local/test JSON map.
  factory WardOfficer.fromFirestore(Map<String, dynamic> data) {
    return WardOfficer.fromJson(data);
  }

  @override
  String toString() => 'WardOfficer($id, $fullName, $wardLabel)';
}

/// Administrative actions recorded in the officer audit trail.
enum OfficerAuditAction {
  create('CREATE'),
  suspend('SUSPEND'),
  reactivate('REACTIVATE'),
  reassign('REASSIGN');

  const OfficerAuditAction(this.value);

  /// Stable value used for persistence.
  final String value;

  static OfficerAuditAction fromValue(Object? value) {
    final normalized = value is String ? value.trim().toUpperCase() : '';
    return OfficerAuditAction.values.firstWhere(
      (action) => action.value == normalized,
      orElse: () => OfficerAuditAction.create,
    );
  }

  String get label => switch (this) {
    OfficerAuditAction.create => 'Created',
    OfficerAuditAction.suspend => 'Suspended',
    OfficerAuditAction.reactivate => 'Reactivated',
    OfficerAuditAction.reassign => 'Reassigned',
  };
}

/// An immutable record of an administrative action on a ward officer.
class OfficerAuditLog {
  const OfficerAuditLog({
    required this.id,
    required this.adminId,
    required this.targetOfficerId,
    required this.targetOfficerName,
    required this.actionType,
    required this.previousValue,
    required this.newValue,
    required this.reason,
    required this.timestamp,
  });

  final String id;
  final String adminId;
  final String targetOfficerId;
  final String targetOfficerName;
  final OfficerAuditAction actionType;

  /// Human-readable value before the action, or null for a new officer.
  final String? previousValue;

  /// Human-readable value after the action.
  final String newValue;

  final String reason;
  final DateTime timestamp;

  OfficerAuditLog copyWith({
    String? id,
    String? adminId,
    String? targetOfficerId,
    String? targetOfficerName,
    OfficerAuditAction? actionType,
    String? previousValue,
    String? newValue,
    String? reason,
    DateTime? timestamp,
  }) {
    return OfficerAuditLog(
      id: id ?? this.id,
      adminId: adminId ?? this.adminId,
      targetOfficerId: targetOfficerId ?? this.targetOfficerId,
      targetOfficerName: targetOfficerName ?? this.targetOfficerName,
      actionType: actionType ?? this.actionType,
      previousValue: previousValue ?? this.previousValue,
      newValue: newValue ?? this.newValue,
      reason: reason ?? this.reason,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'adminId': adminId,
      'targetOfficerId': targetOfficerId,
      'targetOfficerName': targetOfficerName,
      'actionType': actionType.value,
      'previousValue': previousValue,
      'newValue': newValue,
      'reason': reason,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory OfficerAuditLog.fromJson(Map<String, dynamic> json) {
    return OfficerAuditLog(
      id: json['id'] as String? ?? '',
      adminId: json['adminId'] as String? ?? '',
      targetOfficerId: json['targetOfficerId'] as String? ?? '',
      targetOfficerName: json['targetOfficerName'] as String? ?? '',
      actionType: OfficerAuditAction.fromValue(json['actionType']),
      previousValue: json['previousValue'] as String?,
      newValue: json['newValue'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      timestamp: _parseDate(json['timestamp']),
    );
  }

  /// Firestore document payload with a native [Timestamp].
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'adminId': adminId,
      'targetOfficerId': targetOfficerId,
      'targetOfficerName': targetOfficerName,
      'actionType': actionType.value,
      'previousValue': previousValue,
      'newValue': newValue,
      'reason': reason,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  /// Reads either a Firestore document or a local/test JSON map.
  factory OfficerAuditLog.fromFirestore(Map<String, dynamic> data) {
    return OfficerAuditLog.fromJson(data);
  }

  @override
  String toString() =>
      'OfficerAuditLog($id, ${actionType.value}, $targetOfficerName)';
}

DateTime _parseDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}
