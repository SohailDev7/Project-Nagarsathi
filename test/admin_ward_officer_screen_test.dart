import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/models/ward_officer.dart';
import 'package:projectnagarsathi/screens/admin/ward_officer_management_screen.dart';
import 'package:projectnagarsathi/services/admin_officer_service.dart';
import 'package:projectnagarsathi/theme/app_theme.dart';

class _FakeAdminOfficerService extends AdminOfficerService {
  _FakeAdminOfficerService({
    List<WardOfficer>? officers,
    List<OfficerAuditLog>? logs,
    this.loadError,
    this.createError,
  }) : officers = officers ?? [],
       logs = logs ?? [],
       super(adminId: 'admin_001');

  final List<WardOfficer> officers;
  final List<OfficerAuditLog> logs;
  final Object? loadError;
  final Object? createError;

  Completer<void>? suspendGate;
  Completer<void>? reasonGate;

  @override
  Future<List<WardOfficer>> getOfficers() async {
    if (loadError != null) throw loadError!;
    return List<WardOfficer>.unmodifiable(officers);
  }

  @override
  Future<List<OfficerAuditLog>> getAuditLogs({String? officerId}) async {
    if (loadError != null) throw loadError!;
    return logs
        .where((log) => officerId == null || log.targetOfficerId == officerId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Future<OfficerActionResult> createOfficer({
    required String fullName,
    required String email,
    required String phoneNumber,
    required int assignedWard,
    String reason = '',
  }) async {
    if (createError != null) throw createError!;
    throw StateError('Not used in this test.');
  }

  @override
  Future<OfficerActionResult> suspendOfficer(
    String officerId, {
    String reason = '',
  }) async {
    final gate = suspendGate;
    if (gate != null) await gate.future;

    final index = officers.indexWhere((officer) => officer.id == officerId);
    final existing = officers[index];
    final now = DateTime(2026, 11, 19, 10);
    final updated = existing.copyWith(status: OfficerStatus.suspended);
    officers[index] = updated;

    final log = OfficerAuditLog(
      id: 'audit_suspend_1',
      adminId: adminId,
      targetOfficerId: updated.id,
      targetOfficerName: updated.fullName,
      actionType: OfficerAuditAction.suspend,
      previousValue: existing.status.value,
      newValue: updated.status.value,
      reason: reason.trim().isEmpty ? 'Status toggled by admin' : reason,
      timestamp: now,
    );
    logs.add(log);

    return OfficerActionResult(
      officer: updated,
      auditLog: log,
      notification: OfficerNotification(
        recipientEmail: updated.email,
        subject: 'Suspended',
        body: 'Suspended',
        status: OfficerNotificationStatus.sent,
        dispatchedAt: now,
      ),
    );
  }

  @override
  Future<OfficerAuditLog> updateAuditLogReason(
    String auditLogId, {
    required String reason,
  }) async {
    final gate = reasonGate;
    if (gate != null) await gate.future;

    final index = logs.indexWhere((log) => log.id == auditLogId);
    final updated = logs[index].copyWith(reason: reason.trim());
    logs[index] = updated;
    return updated;
  }
}

WardOfficer _officer() {
  return WardOfficer(
    id: 'officer_1',
    fullName: 'Anita Sharma',
    email: 'anita@nagarsathi.gov',
    phoneNumber: '+977 9800000000',
    assignedWard: 12,
    status: OfficerStatus.active,
    createdAt: DateTime(2026, 11, 19, 9),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  AdminOfficerService service,
) async {
  tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(
    tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
  );
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: WardOfficerManagementScreen(service: service),
    ),
  );
}

void main() {
  testWidgets('shows loading, officer data and the admin fallback label', (
    tester,
  ) async {
    final service = _FakeAdminOfficerService(officers: [_officer()]);

    await _pumpScreen(tester, service);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Anita Sharma'), findsOneWidget);
    expect(find.text('App admin · admin_001'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('maps Firestore permission failures to a friendly SnackBar', (
    tester,
  ) async {
    final service = _FakeAdminOfficerService(
      loadError: FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: '[cloud_firestore/permission-denied] Missing permissions',
      ),
    );

    await _pumpScreen(tester, service);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('You do not have permission to manage ward officers'),
      findsOneWidget,
    );
  });

  testWidgets('shows a loading bar while suspending and then confirms', (
    tester,
  ) async {
    final service = _FakeAdminOfficerService(officers: [_officer()]);
    service.suspendGate = Completer<void>();

    await _pumpScreen(tester, service);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);

    service.suspendGate!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('is now suspended'), findsOneWidget);
  });

  testWidgets('shows a loading bar while updating an audit reason', (
    tester,
  ) async {
    final service = _FakeAdminOfficerService(officers: [_officer()]);
    service.reasonGate = Completer<void>();

    await _pumpScreen(tester, service);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add reason'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).last, 'Pending review');
    await tester.tap(find.text('Save reason'));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    service.reasonGate!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('Audit reason updated'), findsOneWidget);
  });

  testWidgets('add officer sheet surfaces service errors instead of closing', (
    tester,
  ) async {
    final service = _FakeAdminOfficerService(
      createError: const AdminOfficerException(
        'An officer with this email already exists.',
      ),
    );

    await _pumpScreen(tester, service);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add officer'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Anita Sharma');
    await tester.enterText(fields.at(1), 'anita@nagarsathi.gov');
    await tester.enterText(fields.at(2), '9800000000');
    await tester.ensureVisible(find.text('Create officer'));
    await tester.tap(find.text('Create officer'));
    await tester.pumpAndSettle();

    expect(find.text('Add ward officer'), findsOneWidget);
    expect(
      find.text('An officer with this email already exists.'),
      findsOneWidget,
    );
  });
}
