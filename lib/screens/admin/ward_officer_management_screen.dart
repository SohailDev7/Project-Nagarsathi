import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/municipality.dart';
import '../../models/ward_officer.dart';
import '../../services/admin_officer_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/ns_back_button.dart';
import '../../widgets/ns_background.dart';
import '../../widgets/ns_primary_button.dart';
import '../../widgets/ns_segmented_control.dart';
import '../../widgets/ns_settings_sheet.dart';
import '../../widgets/ns_text_field.dart';

abstract final class _AdminColors {
  static const suspended = Color(0xFFB25E09);
  static const deleted = Color(0xFFB91C1C);
}

/// US-08 – App Admin ward officer management.
///
/// Lists officers, supports one-click suspend/reactivate, officer deletion,
/// officer creation and an audit trail of every admin action.
class WardOfficerManagementScreen extends StatefulWidget {
  const WardOfficerManagementScreen({
    super.key,
    this.service,
    this.initialTab = 0,
  });

  static const String routeName = '/admin/ward-officers';

  /// Optional injection point for US-08 tests and local previews.
  final AdminOfficerService? service;

  /// 0 opens the officer roster, 1 opens the audit trail. The super admin
  /// console deep-links into either one.
  final int initialTab;

  @override
  State<WardOfficerManagementScreen> createState() =>
      _WardOfficerManagementScreenState();
}

class _WardOfficerManagementScreenState
    extends State<WardOfficerManagementScreen> {
  late final AdminOfficerService _service;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _busyOfficerIds = <String>{};

  List<WardOfficer> _officers = const [];
  List<OfficerAuditLog> _auditLogs = const [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isUpdatingReason = false;
  final TextEditingController _auditSearchController = TextEditingController();
  late int _tabIndex;
  String _query = '';
  String _auditQuery = '';
  int? _wardFilter;
  OfficerStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AdminOfficerService();
    _tabIndex = widget.initialTab;
    _searchController.addListener(_handleSearchChanged);
    _auditSearchController.addListener(_handleAuditSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _auditSearchController
      ..removeListener(_handleAuditSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final query = _searchController.text;
    if (query == _query) return;
    setState(() => _query = query);
  }

  void _handleAuditSearchChanged() {
    final query = _auditSearchController.text;
    if (query == _auditQuery) return;
    setState(() => _auditQuery = query);
  }

  /// Audit entries matching the search box, newest first.
  List<OfficerAuditLog> get _filteredAuditLogs {
    final query = _auditQuery.trim().toLowerCase();
    if (query.isEmpty) return _auditLogs;
    return _auditLogs.where((log) {
      return log.targetOfficerName.toLowerCase().contains(query) ||
          log.actionType.value.toLowerCase().contains(query) ||
          log.reason.toLowerCase().contains(query) ||
          log.adminId.toLowerCase().contains(query) ||
          log.newValue.toLowerCase().contains(query) ||
          (log.previousValue ?? '').toLowerCase().contains(query);
    }).toList();
  }

  static String _csvCell(Object? value) {
    final text = '${value ?? ''}'.replaceAll('"', '""');
    return '"$text"';
  }

  /// Writes the visible audit rows to a CSV file and opens it, so the report
  /// can be shared or archived outside the app.
  Future<void> _exportAuditCsv() async {
    final logs = _filteredAuditLogs;
    final buffer = StringBuffer(
      'timestamp,action,officer,previous,new,reason,admin\n',
    );
    for (final log in logs) {
      buffer.writeln(
        [
          log.timestamp.toIso8601String(),
          log.actionType.value,
          log.targetOfficerName,
          log.previousValue ?? '',
          log.newValue,
          log.reason,
          log.adminId,
        ].map(_csvCell).join(','),
      );
    }

    try {
      final directory = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/nagarsathi_audit_$stamp.csv');
      await file.writeAsString(buffer.toString());
      await OpenFilex.open(file.path);
    } catch (_) {
      if (!mounted) return;
      _showToast(context.l10n.exportFailed);
    }
  }

  Future<void> _loadData() async {
    try {
      final officers = await _service.getOfficers();
      final logs = await _service.getAuditLogs();
      if (!mounted) return;
      setState(() {
        _officers = officers;
        _auditLogs = logs;
      });
    } catch (error) {
      if (!mounted) return;
      _showError(error, context.l10n.couldNotLoadOfficerData);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    if (mounted) setState(() => _isRefreshing = true);
    try {
      final officers = await _service.getOfficers();
      final logs = await _service.getAuditLogs();
      if (!mounted) return;
      setState(() {
        _officers = officers;
        _auditLogs = logs;
      });
    } catch (error) {
      if (!mounted) return;
      _showError(error, context.l10n.couldNotRefreshOfficerData);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  List<WardOfficer> get _filteredOfficers {
    final query = _query.trim().toLowerCase();
    return _officers.where((officer) {
      final matchesQuery =
          query.isEmpty ||
          officer.fullName.toLowerCase().contains(query) ||
          officer.email.toLowerCase().contains(query) ||
          officer.phoneNumber.toLowerCase().contains(query) ||
          officer.wardLabel.toLowerCase().contains(query);
      final matchesWard =
          _wardFilter == null || officer.assignedWard == _wardFilter;
      final matchesStatus =
          _statusFilter == null || officer.status == _statusFilter;
      return matchesQuery && matchesWard && matchesStatus;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _query.trim().isNotEmpty || _wardFilter != null || _statusFilter != null;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _wardFilter = null;
      _statusFilter = null;
    });
  }

  void _showToast(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: AppColors.primaryLight,
                onPressed: onAction ?? () {},
              ),
      ),
    );
  }

  void _showError(Object error, String fallback) {
    _showToast(_friendlyErrorMessage(error, fallback));
  }

  /// The Firebase admin's email when available, otherwise their UID.
  ///
  /// Falls back to the service's mock admin ID in local/widget tests where
  /// Firebase Auth is not initialised or no user is signed in.
  String get _adminLabel {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email?.trim();
      if (email != null && email.isNotEmpty) return email;
      final uid = user?.uid.trim();
      if (uid != null && uid.isNotEmpty) return uid;
    } catch (_) {
      // Firebase Auth is not available in local/widget tests.
    }
    return _service.adminId;
  }

  Future<void> _openAddOfficer() async {
    FocusScope.of(context).unfocus();
    final result = await showModalBottomSheet<OfficerActionResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _AddOfficerSheet(
        service: _service,
        existingEmails: _officers
            .map((officer) => officer.email.toLowerCase())
            .toSet(),
      ),
    );

    if (result == null || !mounted) return;
    await _refreshData();
    if (!mounted) return;

    final strings = context.l10n;
    final message = result.notification.isSent
        ? strings.officerAddedMessage(
            result.officer.fullName,
            result.officer.wardLabel,
            result.notification.message,
          )
        : '${result.officer.fullName} was added to ${result.officer.wardLabel}, '
              'but the invitation email could not be sent. '
              'Temporary password: ${result.officer.tempPassword ?? 'not available'}.';
    _showToast(
      message,
      actionLabel: strings.viewAudit,
      onAction: () => setState(() => _tabIndex = 1),
    );
  }

  Future<void> _toggleStatus(WardOfficer officer) async {
    if (_busyOfficerIds.contains(officer.id)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busyOfficerIds.add(officer.id));

    try {
      final result = officer.isActive
          ? await _service.suspendOfficer(
              officer.id,
              reason: 'Status toggled by admin',
            )
          : await _service.reactivateOfficer(
              officer.id,
              reason: 'Status toggled by admin',
            );
      await _refreshData();
      if (!mounted) return;

      final strings = context.l10n;
      _showToast(
        strings.officerStatusChangedMessage(
          result.officer.fullName,
          result.officer.status.value,
          result.notification.message,
        ),
        actionLabel: strings.addReasonAction,
        onAction: () => _promptAddReason(result.auditLog),
      );
    } catch (error) {
      if (mounted) {
        _showError(error, context.l10n.couldNotUpdateOfficerStatus);
      }
    } finally {
      if (mounted) setState(() => _busyOfficerIds.remove(officer.id));
    }
  }

  Future<void> _confirmDelete(WardOfficer officer) async {
    FocusScope.of(context).unfocus();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete officer?'),
        content: Text(
          'This will permanently remove ${officer.fullName} from Ward Officer '
          'Management and delete their account from the system.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _busyOfficerIds.add(officer.id));

    try {
      await _service.deleteOfficer(
        officer.id,
        reason: 'Officer account deleted by admin.',
      );
      await _refreshData();
      if (!mounted) return;

      _showToast(
        '${officer.fullName} has been permanently deleted.',
        actionLabel: 'View audit',
        onAction: () => setState(() => _tabIndex = 1),
      );
    } catch (error) {
      if (mounted) _showError(error, 'Could not delete the officer.');
    } finally {
      if (mounted) setState(() => _busyOfficerIds.remove(officer.id));
    }
  }

  Future<void> _promptAddReason(OfficerAuditLog log) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _ReasonSheet(log: log),
    );

    if (reason == null || !mounted) return;

    setState(() => _isUpdatingReason = true);
    try {
      await _service.updateAuditLogReason(log.id, reason: reason);
      await _refreshData();
      if (!mounted) return;
      _showToast(context.l10n.auditReasonUpdated(log.targetOfficerName));
    } catch (error) {
      if (mounted) _showError(error, context.l10n.couldNotUpdateAuditReason);
    } finally {
      if (mounted) setState(() => _isUpdatingReason = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NsBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: _buildHeader(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: NsSegmentedControl(
                  segments: [
                    context.l10n.officersTab,
                    context.l10n.auditTrailTab,
                  ],
                  selectedIndex: _tabIndex,
                  onChanged: (index) {
                    FocusScope.of(context).unfocus();
                    setState(() => _tabIndex = index);
                  },
                ),
              ),
              if (_busyOfficerIds.isNotEmpty ||
                  _isUpdatingReason ||
                  _isRefreshing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(minHeight: 3),
                  ),
                ),
              const SizedBox(height: 10),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: _tabIndex == 0
                              ? _buildOfficersTab()
                              : _buildAuditTab(),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
    return Row(
      children: [
        NsBackButton(onPressed: () => Navigator.of(context).maybePop()),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.wardOfficersTitle,
                style: TextStyle(
                  fontSize: 24,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: tokens.heading,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                strings.appAdminSubtitle(_adminLabel),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const NsSettingsButton(),
        const SizedBox(width: 8),
        _CircleAction(
          icon: Icons.person_add_alt_1_rounded,
          tooltip: strings.addOfficer,
          onPressed: _openAddOfficer,
        ),
      ],
    );
  }

  Widget _buildOfficersTab() {
    final officers = _filteredOfficers;
    final strings = context.l10n;
    final tokens = NsColors.of(context);

    return RefreshIndicator(
      color: tokens.primaryStrong,
      onRefresh: _refreshData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _StatsRow(officers: _officers),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: tokens.ink,
            ),
            decoration: InputDecoration(
              hintText: strings.searchOfficersHint,
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: tokens.muted,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: strings.clearFilters,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: tokens.muted,
                      ),
                      onPressed: _searchController.clear,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _WardFilter(
                  value: _wardFilter,
                  onChanged: (value) => setState(() => _wardFilter = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatusFilter(
                  value: _statusFilter,
                  onChanged: (value) => setState(() => _statusFilter = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                strings.officerCount(officers.length),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.ink,
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters)
                TextButton(
                  onPressed: _clearFilters,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    strings.clearFilters,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (officers.isEmpty)
            _EmptyState(
              title: _officers.isEmpty
                  ? strings.noWardOfficersTitle
                  : strings.noOfficersMatchTitle,
              message: _officers.isEmpty
                  ? strings.noWardOfficersBody
                  : strings.noOfficersMatchBody,
              actionLabel: _officers.isEmpty
                  ? strings.addOfficer
                  : strings.clearFilters,
              onAction: _officers.isEmpty ? _openAddOfficer : _clearFilters,
            )
          else
            for (final officer in officers) ...[
              _OfficerCard(
                officer: officer,
                isBusy: _busyOfficerIds.contains(officer.id),
                onToggle: () => _toggleStatus(officer),
                onDelete: () => _confirmDelete(officer),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _buildAuditTab() {
    final strings = context.l10n;
    final tokens = NsColors.of(context);

    return RefreshIndicator(
      color: tokens.primaryStrong,
      onRefresh: _refreshData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.mint,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 20,
                  color: tokens.accentText,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.auditInfo,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: tokens.ink.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('audit-search'),
            controller: _auditSearchController,
            textInputAction: TextInputAction.search,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: tokens.ink,
            ),
            decoration: InputDecoration(
              hintText: strings.auditSearchHint,
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: tokens.muted,
              ),
              suffixIcon: _auditQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: strings.clearFilters,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: tokens.muted,
                      ),
                      onPressed: _auditSearchController.clear,
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                strings.recentActivity,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: tokens.ink,
                ),
              ),
              const Spacer(),
              Text(
                strings.auditEntryCount(_filteredAuditLogs.length),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
          if (_auditLogs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('audit-export'),
                onPressed: _filteredAuditLogs.isEmpty ? null : _exportAuditCsv,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(strings.exportCsv),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_auditLogs.isEmpty)
            const _EmptyState(
              title: 'No audit entries yet',
              message:
                  'Create, suspend, reactivate or delete an officer and '
                  'the action will appear here.',
            )
          else if (_filteredAuditLogs.isEmpty)
            _EmptyState(
              title: strings.noOfficersMatchTitle,
              message: strings.noOfficersMatchBody,
              actionLabel: strings.clearFilters,
              onAction: _auditSearchController.clear,
            )
          else
            for (final log in _filteredAuditLogs) ...[
              _AuditLogCard(log: log),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: tokens.primaryStrong,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 21, color: Colors.white),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.officers});

  final List<WardOfficer> officers;

  @override
  Widget build(BuildContext context) {
    final active = officers.where((officer) => officer.isActive).length;
    final suspended = officers.length - active;
    final strings = context.l10n;
    final tokens = NsColors.of(context);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: strings.totalLabel,
            value: officers.length,
            color: tokens.accentText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: strings.activeLabel,
            value: active,
            color: tokens.accentText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: strings.suspendedLabel,
            value: suspended,
            color: Theme.of(context).brightness == Brightness.dark
                ? tokens.errorBorder
                : _AdminColors.suspended,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: tokens.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _WardFilter extends StatelessWidget {
  const _WardFilter({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value == null ? tokens.border : tokens.accentText,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 17, color: tokens.muted),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(16),
                hint: Text(strings.allWards),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: tokens.muted,
                ),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                ),
                dropdownColor: tokens.surface,
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(strings.allWards),
                  ),
                  for (
                    var ward = WardOfficer.minWard;
                    ward <= WardOfficer.maxWard;
                    ward++
                  )
                    DropdownMenuItem<int?>(
                      value: ward,
                      child: Text(strings.wardLabel('$ward')),
                    ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.value, required this.onChanged});

  final OfficerStatus? value;
  final ValueChanged<OfficerStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value == null ? tokens.border : tokens.accentText,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt_outlined, size: 17, color: tokens.muted),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<OfficerStatus?>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(16),
                hint: Text(strings.allStatuses),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: tokens.muted,
                ),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                ),
                dropdownColor: tokens.surface,
                items: [
                  DropdownMenuItem<OfficerStatus?>(
                    value: null,
                    child: Text(strings.allStatuses),
                  ),
                  DropdownMenuItem<OfficerStatus?>(
                    value: OfficerStatus.active,
                    child: Text(strings.activeLabel),
                  ),
                  DropdownMenuItem<OfficerStatus?>(
                    value: OfficerStatus.suspended,
                    child: Text(strings.suspendedLabel),
                  ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficerCard extends StatelessWidget {
  const _OfficerCard({
    required this.officer,
    required this.isBusy,
    required this.onToggle,
    required this.onDelete,
  });

  final WardOfficer officer;
  final bool isBusy;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = officer.isActive
        ? tokens.accentText
        : (isDark ? tokens.errorBorder : _AdminColors.suspended);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.border),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tokens.mint,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initialsFor(officer.fullName),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tokens.accentText,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            officer.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: tokens.ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Pill(label: officer.status.label, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _ContactLine(
                      icon: Icons.mail_outline_rounded,
                      text: officer.email,
                    ),
                    const SizedBox(height: 2),
                    _ContactLine(
                      icon: Icons.phone_outlined,
                      text: officer.phoneNumber,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.mint,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: tokens.accentText,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          officer.wardLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: tokens.accentText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (isBusy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: isBusy ? null : onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                    color: isBusy
                        ? AppColors.border
                        : AppColors.error.withValues(alpha: 0.45),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: tokens.hairline),
          ),
          Row(
            children: [
              Icon(
                officer.isActive
                    ? Icons.check_circle_outline_rounded
                    : Icons.pause_circle_outline_rounded,
                size: 18,
                color: statusColor,
              ),
              const SizedBox(width: 7),
              Text(
                officer.isActive
                    ? strings.accountActive
                    : strings.accountSuspended,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
              const Spacer(),
              Semantics(
                label: officer.isActive
                    ? 'Suspend ${officer.fullName}'
                    : 'Reactivate ${officer.fullName}',
                child: Switch.adaptive(
                  value: officer.isActive,
                  onChanged: isBusy ? null : (_) => onToggle(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    return Row(
      children: [
        Icon(icon, size: 13, color: tokens.muted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: tokens.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({required this.log});

  final OfficerAuditLog log;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
    final actionColor = switch (log.actionType) {
      OfficerAuditAction.create => AppColors.primary,
      OfficerAuditAction.suspend => AppColors.error,
      OfficerAuditAction.reactivate => AppColors.primary,
      OfficerAuditAction.reassign => AppColors.muted,
      OfficerAuditAction.delete => _AdminColors.deleted,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Pill(label: log.actionType.value, color: actionColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  log.targetOfficerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _formatTimestamp(log.timestamp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: tokens.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MetaChip(
                icon: Icons.admin_panel_settings_outlined,
                label: log.adminId,
              ),
              Text(
                log.previousValue ?? '—',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.muted,
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 14, color: tokens.muted),
              Text(
                log.newValue,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tokens.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: tokens.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${strings.reasonLabel}: ${log.reason}',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: tokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.mint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tokens.accentText),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: tokens.accentText,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: tokens.mint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.groups_outlined,
              size: 26,
              color: tokens.accentText,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: tokens.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w400,
              color: tokens.muted,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddOfficerSheet extends StatefulWidget {
  const _AddOfficerSheet({required this.service, required this.existingEmails});

  final AdminOfficerService service;
  final Set<String> existingEmails;

  @override
  State<_AddOfficerSheet> createState() => _AddOfficerSheetState();
}

class _AddOfficerSheetState extends State<_AddOfficerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  Municipality _municipality = Municipality.kmc;
  int _ward = WardOfficer.minWard;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final base = Validators.email(value);
    if (base != null) return base;
    final email = value!.trim().toLowerCase();
    if (widget.existingEmails.contains(email)) {
      return context.l10n.officerEmailExists;
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await widget.service.createOfficer(
        fullName: _nameController.text,
        email: _emailController.text,
        phoneNumber: _phoneController.text,
        assignedWard: _ward,
        municipality: _municipality,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = _friendlyErrorMessage(
          error,
          'Could not create the officer. Please try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SheetGrabber(),
                const SizedBox(height: 14),
                _SheetHeader(
                  title: strings.addWardOfficerTitle,
                  subtitle: strings.addWardOfficerSubtitle,
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 20),
                NsTextField(
                  controller: _nameController,
                  label: strings.fullName,
                  hint: strings.fullNameExample,
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: Validators.name,
                ),
                const SizedBox(height: 16),
                NsTextField(
                  controller: _emailController,
                  label: strings.emailAddressLabel,
                  hint: strings.emailExample,
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                  autocorrect: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                ),
                const SizedBox(height: 16),
                NsTextField(
                  controller: _phoneController,
                  label: strings.phoneNumberLabel,
                  hint: strings.phoneExample,
                  icon: Icons.phone_iphone_rounded,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  validator: Validators.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                  ],
                ),
                const SizedBox(height: 16),
                _MunicipalityField(
                  label: strings.municipalityLabel,
                  value: _municipality,
                  onChanged: (municipality) => setState(() {
                    _municipality = municipality;
                    if (!municipality.hasWard(_ward)) {
                      _ward = municipality.wardCount;
                    }
                  }),
                ),
                const SizedBox(height: 16),
                _WardField(
                  label: strings.assignedWardLabel,
                  value: _ward,
                  municipality: _municipality,
                  onChanged: (ward) => setState(() => _ward = ward),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 20),
                NsPrimaryButton(
                  label: strings.createOfficerLabel,
                  icon: Icons.person_add_alt_1_rounded,
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasonSheet extends StatefulWidget {
  const _ReasonSheet({required this.log});

  final OfficerAuditLog log;

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = context.l10n.reasonRequiredForAction);
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SheetGrabber(),
                const SizedBox(height: 14),
                _SheetHeader(
                  title: strings.addReasonTitle,
                  subtitle: strings.addReasonSubtitle(
                    widget.log.targetOfficerName,
                  ),
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Pill(
                      label: widget.log.actionType.value,
                      color: tokens.accentText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.log.previousValue ?? '—'} → '
                        '${widget.log.newValue}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                NsTextField(
                  controller: _reasonController,
                  label: strings.reasonLabel,
                  hint: strings.reasonHint,
                  icon: Icons.notes_rounded,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return strings.reasonRequiredForAction;
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 20),
                NsPrimaryButton(
                  label: strings.saveReasonLabel,
                  icon: Icons.save_outlined,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MunicipalityField extends StatelessWidget {
  const _MunicipalityField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Municipality value;
  final ValueChanged<Municipality> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.ink.withValues(alpha: 0.8),
              letterSpacing: -0.1,
            ),
          ),
        ),
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_rounded,
                size: 20,
                color: tokens.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Municipality>(
                    value: value,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(16),
                    dropdownColor: tokens.surface,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: tokens.muted,
                    ),
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      color: tokens.ink,
                    ),
                    items: [
                      for (final municipality in Municipality.values)
                        DropdownMenuItem<Municipality>(
                          value: municipality,
                          child: Text(municipality.label),
                        ),
                    ],
                    onChanged: (municipality) {
                      if (municipality != null) onChanged(municipality);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WardField extends StatelessWidget {
  const _WardField({
    required this.label,
    required this.value,
    required this.municipality,
    required this.onChanged,
  });

  final String label;
  final int value;
  final Municipality municipality;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.ink.withValues(alpha: 0.8),
              letterSpacing: -0.1,
            ),
          ),
        ),
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined, size: 20, color: tokens.muted),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: value,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(16),
                    dropdownColor: tokens.surface,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: tokens.muted,
                    ),
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      color: tokens.ink,
                    ),
                    items: [
                      for (
                        var ward = WardOfficer.minWard;
                        ward <= municipality.wardCount;
                        ward++
                      )
                        DropdownMenuItem<int>(
                          value: ward,
                          child: Text(strings.wardLabel('$ward')),
                        ),
                    ],
                    onChanged: (ward) {
                      if (ward != null) onChanged(ward);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 21,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: tokens.heading,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: tokens.surfaceSoft,
            shape: BoxShape.circle,
            border: Border.all(color: tokens.border),
          ),
          child: IconButton(
            onPressed: onClose,
            tooltip: context.l10n.close,
            icon: Icon(Icons.close_rounded, size: 19, color: tokens.ink),
          ),
        ),
      ],
    );
  }
}

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: NsColors.of(context).border,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final errorColor = Theme.of(context).brightness == Brightness.dark
        ? tokens.errorBorder
        : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: errorColor.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 17, color: errorColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: errorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _friendlyErrorMessage(Object error, String fallback) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'You do not have permission to manage ward officers. '
            'Contact a super admin.',
      'unauthenticated' =>
        'Your admin session expired. Sign in again to continue.',
      'unavailable' =>
        'The server is taking too long to respond. Check your connection '
            'and try again.',
      'deadline-exceeded' =>
        'The request timed out. Check your connection and try again.',
      'not-found' => 'That record no longer exists. Refresh and try again.',
      'resource-exhausted' =>
        'Too many requests right now. Wait a moment and try again.',
      _ => fallback,
    };
  }

  if (error is AdminOfficerException) {
    final message = error.message.trim();
    if (message.isEmpty) return fallback;

    final lower = message.toLowerCase();
    if (lower.contains('permission-denied') ||
        lower.contains('insufficient permissions') ||
        lower.contains('missing or insufficient')) {
      return 'You do not have permission to manage ward officers. '
          'Contact a super admin.';
    }
    if (lower.contains('unauthenticated') || lower.contains('not signed in')) {
      return 'Your admin session expired. Sign in again to continue.';
    }
    if (lower.contains('unavailable') || lower.contains('network')) {
      return 'No connection. Check your internet and try again.';
    }
    if (lower.contains('firebase is not configured')) {
      return 'Firebase is not configured for this build.';
    }
    if (message.startsWith('[')) return fallback;
    return message;
  }

  return fallback;
}

String _initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final value = parts.first;
    return value.length >= 2
        ? value.substring(0, 2).toUpperCase()
        : value.toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String _formatTimestamp(DateTime timestamp) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = timestamp.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day} ${months[local.month - 1]} ${local.year} · '
      '$hour:$minute $period';
}
