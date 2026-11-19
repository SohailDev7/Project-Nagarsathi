import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ward_officer.dart';

/// Thrown when an officer operation cannot be completed.
class AdminOfficerException implements Exception {
  const AdminOfficerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Delivery state of a simulated officer notification email.
enum OfficerNotificationStatus {
  sent('sent'),
  failed('failed');

  const OfficerNotificationStatus(this.value);

  final String value;

  String get label =>
      this == OfficerNotificationStatus.sent ? 'Sent' : 'Failed';
}

/// A simulated email dispatched to an officer after an admin action.
///
/// The UI receives this payload immediately. A matching queued record is also
/// written to Firestore so a backend mail worker can dispatch the real email
/// once one is wired up.
class OfficerNotification {
  const OfficerNotification({
    required this.recipientEmail,
    required this.subject,
    required this.body,
    required this.status,
    required this.dispatchedAt,
  });

  final String recipientEmail;
  final String subject;
  final String body;
  final OfficerNotificationStatus status;
  final DateTime dispatchedAt;

  bool get isSent => status == OfficerNotificationStatus.sent;

  String get message => isSent
      ? 'Confirmation email sent to $recipientEmail.'
      : 'Could not send the confirmation email to $recipientEmail.';

  Map<String, dynamic> toJson() {
    return {
      'recipientEmail': recipientEmail,
      'subject': subject,
      'body': body,
      'status': status.value,
      'dispatchedAt': dispatchedAt.toIso8601String(),
    };
  }
}

/// Everything the UI needs after a create/suspend/reactivate/reassign action.
class OfficerActionResult {
  const OfficerActionResult({
    required this.officer,
    required this.auditLog,
    required this.notification,
  });

  final WardOfficer officer;
  final OfficerAuditLog auditLog;
  final OfficerNotification notification;
}

/// Manages ward officer records and their audit trail in Cloud Firestore.
///
/// The acting admin is resolved from the signed-in Firebase user on every
/// action. When no Firebase user is available (for example in local or widget
/// tests), the service falls back to [mockAdminId].
class AdminOfficerService {
  AdminOfficerService({String? adminId}) : _adminIdOverride = adminId;

  /// Placeholder admin identity used when Firebase Auth has no signed-in user.
  static const String mockAdminId = 'admin_001';

  static const String officersCollection = 'ward_officers';
  static const String auditLogsCollection = 'officer_audit_logs';
  static const String notificationsCollection = 'notifications';

  static final RegExp _emailPattern = RegExp(
    r'^[\w.\-+]+@[\w\-]+(\.[\w\-]+)+$',
  );

  /// Optional override used by tests and local previews. Production callers
  /// leave this null so the signed-in Firebase user is used.
  final String? _adminIdOverride;

  /// The admin recorded on every audit entry.
  ///
  /// Resolved from [FirebaseAuth] each time so a signed-in admin ID is used as
  /// soon as auth is available, without holding stale state.
  String get adminId {
    final override = _adminIdOverride?.trim();
    if (override != null && override.isNotEmpty) return override;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid.trim();
      if (uid != null && uid.isNotEmpty) return uid;
    } catch (_) {
      // Firebase Auth is not initialised (local/widget tests).
    }
    return mockAdminId;
  }

  FirebaseFirestore get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      throw const AdminOfficerException(
        'Firebase is not configured. Add Firebase to this build to manage '
        'ward officers.',
      );
    }
  }

  CollectionReference<Map<String, dynamic>> get _officers =>
      _firestore.collection(officersCollection);

  CollectionReference<Map<String, dynamic>> get _auditLogs =>
      _firestore.collection(auditLogsCollection);

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection(notificationsCollection);

  Future<List<WardOfficer>> getOfficers() {
    return _guard('Could not load ward officers.', () async {
      final snapshot = await _officers.get();
      final officers = snapshot.docs.map(_officerFromDoc).toList();
      officers.sort((a, b) {
        final byWard = a.assignedWard.compareTo(b.assignedWard);
        if (byWard != 0) return byWard;
        return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      });
      return officers;
    });
  }

  Future<WardOfficer?> getOfficerById(String officerId) {
    return _guard('Could not load the ward officer.', () async {
      final snapshot = await _officers.doc(officerId).get();
      if (!snapshot.exists) return null;
      return _officerFromDoc(snapshot);
    });
  }

  /// Returns audit entries newest-first, optionally filtered to one officer.
  Future<List<OfficerAuditLog>> getAuditLogs({String? officerId}) {
    return _guard('Could not load the audit trail.', () async {
      final Query<Map<String, dynamic>> query = officerId == null
          ? _auditLogs
          : _auditLogs.where('targetOfficerId', isEqualTo: officerId);
      final snapshot = await query.get();
      final logs = snapshot.docs.map(_auditLogFromDoc).toList();
      logs.sort((a, b) {
        final byTime = b.timestamp.compareTo(a.timestamp);
        if (byTime != 0) return byTime;
        return b.id.compareTo(a.id);
      });
      return logs;
    });
  }

  Future<OfficerActionResult> createOfficer({
    required String fullName,
    required String email,
    required String phoneNumber,
    required int assignedWard,
    String reason = '',
  }) {
    return _guard('Could not create the officer.', () async {
      final name = fullName.trim();
      final emailValue = email.trim();
      final phone = phoneNumber.trim();

      if (name.isEmpty) {
        throw const AdminOfficerException("Enter the officer's full name.");
      }
      if (!_emailPattern.hasMatch(emailValue)) {
        throw const AdminOfficerException('Enter a valid email address.');
      }
      final phoneDigits = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (phoneDigits.length < 7 || phoneDigits.length > 15) {
        throw const AdminOfficerException('Enter a valid phone number.');
      }
      _validateWard(assignedWard);

      // Case-insensitive uniqueness via the derived emailLower field.
      final duplicate = await _officers
          .where('emailLower', isEqualTo: emailValue.toLowerCase())
          .limit(1)
          .get();
      if (duplicate.docs.isNotEmpty) {
        throw const AdminOfficerException(
          'An officer with this email already exists.',
        );
      }

      final now = DateTime.now();
      final officer = WardOfficer(
        id: _newId('officer', now),
        fullName: name,
        email: emailValue,
        phoneNumber: phone,
        assignedWard: assignedWard,
        status: OfficerStatus.active,
        createdAt: now,
      );

      return _finishAction(
        officer: officer,
        action: OfficerAuditAction.create,
        previousValue: null,
        newValue: '${officer.wardLabel}, ${officer.status.value}',
        reason: reason,
        fallbackReason: 'Officer account created by admin.',
        now: now,
      );
    });
  }

  Future<OfficerActionResult> suspendOfficer(
    String officerId, {
    String reason = '',
  }) {
    return _guard('Could not suspend the officer.', () async {
      final existing = await _requireOfficer(officerId);

      if (!existing.isActive) {
        throw const AdminOfficerException('This officer is already suspended.');
      }

      final now = DateTime.now();
      final updated = existing.copyWith(status: OfficerStatus.suspended);

      return _finishAction(
        officer: updated,
        action: OfficerAuditAction.suspend,
        previousValue: existing.status.value,
        newValue: updated.status.value,
        reason: reason,
        fallbackReason: 'Account suspended by admin.',
        now: now,
      );
    });
  }

  Future<OfficerActionResult> reactivateOfficer(
    String officerId, {
    String reason = '',
  }) {
    return _guard('Could not reactivate the officer.', () async {
      final existing = await _requireOfficer(officerId);

      if (existing.isActive) {
        throw const AdminOfficerException('This officer is already active.');
      }

      final now = DateTime.now();
      final updated = existing.copyWith(status: OfficerStatus.active);

      return _finishAction(
        officer: updated,
        action: OfficerAuditAction.reactivate,
        previousValue: existing.status.value,
        newValue: updated.status.value,
        reason: reason,
        fallbackReason: 'Account reactivated by admin.',
        now: now,
      );
    });
  }

  Future<OfficerActionResult> reassignWard(
    String officerId, {
    required int newWard,
    String reason = '',
  }) {
    return _guard('Could not reassign the officer.', () async {
      _validateWard(newWard);

      final existing = await _requireOfficer(officerId);

      if (existing.assignedWard == newWard) {
        throw AdminOfficerException(
          'This officer is already assigned to ${existing.wardLabel}.',
        );
      }

      final now = DateTime.now();
      final updated = existing.copyWith(assignedWard: newWard);

      return _finishAction(
        officer: updated,
        action: OfficerAuditAction.reassign,
        previousValue: existing.wardLabel,
        newValue: updated.wardLabel,
        reason: reason,
        fallbackReason: 'Ward reassigned by admin.',
        now: now,
      );
    });
  }

  /// Replaces the reason of an existing audit entry.
  ///
  /// Used by the "Add reason" action after a quick one-click toggle.
  Future<OfficerAuditLog> updateAuditLogReason(
    String auditLogId, {
    required String reason,
  }) {
    return _guard('Could not update the audit reason.', () async {
      final trimmed = reason.trim();
      if (trimmed.isEmpty) {
        throw const AdminOfficerException('Enter a reason for this action.');
      }

      final doc = _auditLogs.doc(auditLogId);
      final snapshot = await doc.get();
      if (!snapshot.exists) {
        throw const AdminOfficerException('Audit entry not found.');
      }

      final updated = _auditLogFromDoc(snapshot).copyWith(reason: trimmed);
      await doc.update({'reason': trimmed});
      return updated;
    });
  }

  Future<WardOfficer> _requireOfficer(String officerId) async {
    final snapshot = await _officers.doc(officerId).get();
    if (!snapshot.exists) {
      throw const AdminOfficerException('Ward officer not found.');
    }
    return _officerFromDoc(snapshot);
  }

  Future<OfficerActionResult> _finishAction({
    required WardOfficer officer,
    required OfficerAuditAction action,
    required String? previousValue,
    required String newValue,
    required String reason,
    required String fallbackReason,
    required DateTime now,
  }) async {
    final trimmedReason = reason.trim();
    final auditLog = OfficerAuditLog(
      id: _newId('audit', now),
      adminId: adminId,
      targetOfficerId: officer.id,
      targetOfficerName: officer.fullName,
      actionType: action,
      previousValue: previousValue,
      newValue: newValue,
      reason: trimmedReason.isEmpty ? fallbackReason : trimmedReason,
      timestamp: now,
    );

    final notification = _dispatchNotification(
      officer: officer,
      action: action,
      previousValue: previousValue,
      newValue: newValue,
      reason: auditLog.reason,
      now: now,
    );

    // The officer record and audit entry commit together. The queued email
    // record is best-effort: a restricted notifications collection must not
    // prevent an admin from creating or updating an officer.
    final batch = _firestore.batch();
    batch.set(_officers.doc(officer.id), officer.toFirestore());
    batch.set(_auditLogs.doc(auditLog.id), auditLog.toFirestore());
    await batch.commit();

    try {
      await _notifications.doc('notification_${auditLog.id}').set(
        _notificationRecord(notification: notification, auditLog: auditLog),
      );
    } catch (_) {
      // The UI still reports the simulated email confirmation.
    }

    return OfficerActionResult(
      officer: officer,
      auditLog: auditLog,
      notification: notification,
    );
  }

  OfficerNotification _dispatchNotification({
    required WardOfficer officer,
    required OfficerAuditAction action,
    required String? previousValue,
    required String newValue,
    required String reason,
    required DateTime now,
  }) {
    final subject = switch (action) {
      OfficerAuditAction.create =>
        'Your NagarSathi ward officer account is ready',
      OfficerAuditAction.suspend =>
        'Your NagarSathi ward officer account has been suspended',
      OfficerAuditAction.reactivate =>
        'Your NagarSathi ward officer account has been reactivated',
      OfficerAuditAction.reassign =>
        'Your NagarSathi ward assignment has changed',
    };

    final body = switch (action) {
      OfficerAuditAction.create =>
        'Hello ${officer.fullName}, your ward officer account for '
            '${officer.wardLabel} has been created. '
            'Sign in with ${officer.email} to get started.',
      OfficerAuditAction.suspend =>
        'Hello ${officer.fullName}, your access to ${officer.wardLabel} has '
            'been suspended. Reason: $reason',
      OfficerAuditAction.reactivate =>
        'Hello ${officer.fullName}, your access to ${officer.wardLabel} has '
            'been reactivated. Reason: $reason',
      OfficerAuditAction.reassign =>
        'Hello ${officer.fullName}, you have been moved from '
            '${previousValue ?? 'your previous ward'} to $newValue. '
            'Reason: $reason',
    };

    return OfficerNotification(
      recipientEmail: officer.email,
      subject: subject,
      body: body,
      status: OfficerNotificationStatus.sent,
      dispatchedAt: now,
    );
  }

  /// Firestore record consumed by the backend email worker.
  ///
  /// The UI already reports the simulated send as successful, while the stored
  /// record stays queued until a real provider processes it.
  Map<String, dynamic> _notificationRecord({
    required OfficerNotification notification,
    required OfficerAuditLog auditLog,
  }) {
    return {
      'recipientEmail': notification.recipientEmail,
      'subject': notification.subject,
      'body': notification.body,
      'channel': 'email',
      'status': 'queued',
      'simulated': true,
      'officerId': auditLog.targetOfficerId,
      'officerName': auditLog.targetOfficerName,
      'auditLogId': auditLog.id,
      'adminId': auditLog.adminId,
      'actionType': auditLog.actionType.value,
      'createdAt': Timestamp.fromDate(notification.dispatchedAt),
    };
  }

  void _validateWard(int ward) {
    if (!WardOfficer.isValidWard(ward)) {
      throw const AdminOfficerException(
        'Assigned ward must be between '
        '${WardOfficer.minWard} and ${WardOfficer.maxWard}.',
      );
    }
  }

  String _newId(String prefix, DateTime now) {
    return '${prefix}_${now.microsecondsSinceEpoch}';
  }

  WardOfficer _officerFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return WardOfficer.fromFirestore({...data, 'id': doc.id});
  }

  OfficerAuditLog _auditLogFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return OfficerAuditLog.fromFirestore({...data, 'id': doc.id});
  }

  Future<T> _guard<T>(
    String failureMessage,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on AdminOfficerException {
      rethrow;
    } on FirebaseException catch (error) {
      final message = error.message?.trim();
      throw AdminOfficerException(
        message == null || message.isEmpty ? failureMessage : message,
      );
    } catch (_) {
      throw AdminOfficerException(failureMessage);
    }
  }
}
