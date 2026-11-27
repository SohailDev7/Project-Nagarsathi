import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/ward_officer.dart';
import '../services/admin_officer_service.dart';
import '../services/session_service.dart';
import '../services/staff_auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ns_app_lock_prompt.dart';
import '../widgets/ns_background.dart';
import '../widgets/ns_card.dart';
import '../widgets/ns_chip.dart';
import '../widgets/ns_entrance.dart';
import '../widgets/ns_logo.dart';
import '../widgets/ns_mascot.dart';
import '../widgets/ns_outline_button.dart';
import '../widgets/ns_pressable.dart';
import '../widgets/ns_remember_me_notification.dart';
import '../widgets/ns_route.dart';
import '../widgets/ns_settings_sheet.dart';
import 'admin/ward_officer_management_screen.dart';
import 'settings_screen.dart';
import 'staff_login_screen.dart';

/// Super admin console.
///
/// Deliberately not the ward workspace: a super admin only creates and manages
/// ward officer accounts and reviews the audit trail.
class SuperAdminHomeScreen extends StatefulWidget {
  const SuperAdminHomeScreen({
    super.key,
    required this.staffIdentifier,
    this.showRememberMePrompt = false,
    this.service,
  });

  final String staffIdentifier;
  final bool showRememberMePrompt;

  /// Injection point for previews and tests.
  final AdminOfficerService? service;

  @override
  State<SuperAdminHomeScreen> createState() => _SuperAdminHomeScreenState();
}

class _SuperAdminHomeScreenState extends State<SuperAdminHomeScreen> {
  late final AdminOfficerService _service;

  List<WardOfficer> _officers = const [];
  List<OfficerAuditLog> _logs = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AdminOfficerService();
    _loadOverview();
    if (widget.showRememberMePrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybePromptRememberMe();
      });
    }
  }

  Future<void> _loadOverview() async {
    try {
      final results = await Future.wait<Object>([
        _service.getOfficers(),
        _service.getAuditLogs(),
      ]);
      if (!mounted) return;
      setState(() {
        _officers = results[0] as List<WardOfficer>;
        _logs = results[1] as List<OfficerAuditLog>;
      });
    } catch (_) {
      // The console still opens; the roster screen surfaces any real error.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _maybePromptRememberMe() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final remembered = await showRememberMeNotification(
      context: context,
      isStaff: true,
      staffIdentifier: widget.staffIdentifier,
      isSuperAdmin: true,
    );
    if (!mounted || remembered != true) return;

    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await showAppLockOffer(context: context, isStaff: true);
  }

  void _openOfficers({int tab = 0}) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      NsPageRoute<void>(
        builder: (_) => WardOfficerManagementScreen(initialTab: tab),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context)
        .push(NsPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  Future<void> _signOut() async {
    await StaffAuthService.signOut();
    await const SessionService().clearStaffSession();
    await const SessionService().saveRememberMe(false);
    await const SessionService().saveAppLock(false);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      NsPageRoute<void>(
        style: NsTransitionStyle.fade,
        builder: (_) => const StaffLoginScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _showAccountSheet() async {
    HapticFeedback.selectionClick();
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tokens.mint,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 24,
                      color: tokens.accentText,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.superAdminConsole,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: tokens.heading,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.staffIdentifier,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  NsChip(label: strings.superAdminBadge, compact: true),
                ],
              ),
              const SizedBox(height: 18),
              NsOutlineButton(
                label: strings.wardOfficerManagement,
                icon: Icons.manage_accounts_rounded,
                tone: NsOutlineTone.green,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _openOfficers();
                },
              ),
              const SizedBox(height: 12),
              NsOutlineButton(
                label: strings.settings,
                icon: Icons.tune_rounded,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _openSettings();
                },
              ),
              const SizedBox(height: 12),
              NsOutlineButton(
                label: strings.signOutOfStaff,
                icon: Icons.logout_rounded,
                tone: NsOutlineTone.danger,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    final active = _officers.where((officer) => officer.isActive).length;
    final suspended = _officers.length - active;
    final recentLogs = _logs.take(3).toList();

    return Scaffold(
      body: NsBackground(
        staff: true,
        ambientGlow: true,
        child: SafeArea(
          bottom: false,
          child: NsEntrance(
            child: RefreshIndicator(
              onRefresh: _loadOverview,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTopBar(context),
                        const SizedBox(height: 22),
                        _ConsoleHeader(
                          identifier: widget.staffIdentifier,
                          onOpenOfficers: _openOfficers,
                        ),
                        const SizedBox(height: 22),
                        Text(
                          strings.staffWardSnapshot,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: tokens.heading,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _ConsoleStat(
                                value: _loading ? '—' : '${_officers.length}',
                                label: strings.officersLabel,
                                icon: Icons.groups_rounded,
                                tone: NsChipTone.green,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ConsoleStat(
                                value: _loading ? '—' : '$active',
                                label: strings.activeLabel,
                                icon: Icons.verified_user_rounded,
                                tone: NsChipTone.sky,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ConsoleStat(
                                value: _loading ? '—' : '$suspended',
                                label: strings.suspendedLabel,
                                icon: Icons.pause_circle_outline_rounded,
                                tone: NsChipTone.sun,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          strings.quickActions,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: tokens.heading,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ConsoleAction(
                          icon: Icons.person_add_alt_1_rounded,
                          title: strings.createWardOfficer,
                          body: strings.wardOfficerManagementDesc,
                          onTap: _openOfficers,
                        ),
                        const SizedBox(height: 10),
                        _ConsoleAction(
                          icon: Icons.receipt_long_rounded,
                          title: strings.openAuditTrail,
                          body: strings.auditInfo,
                          onTap: () => _openOfficers(tab: 1),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                strings.recentActivity,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: tokens.heading,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            if (_logs.isNotEmpty)
                              NsChip(
                                label: strings.auditEntryCount(_logs.length),
                                compact: true,
                                tone: NsChipTone.muted,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        NsCard(
                          padding: const EdgeInsets.all(16),
                          radius: 22,
                          depth: 4,
                          child: recentLogs.isEmpty
                              ? _EmptyAudit(loading: _loading)
                              : Column(
                                  children: [
                                    for (
                                      var index = 0;
                                      index < recentLogs.length;
                                      index++
                                    ) ...[
                                      if (index > 0) ...[
                                        const SizedBox(height: 12),
                                        Divider(
                                          height: 1,
                                          thickness: 1.2,
                                          color: tokens.hairline,
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      _AuditRow(entry: recentLogs[index]),
                                    ],
                                  ],
                                ),
                        ),
                        const SizedBox(height: 20),
                        NsOutlineButton(
                          label: strings.settings,
                          icon: Icons.tune_rounded,
                          onPressed: _openSettings,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final tokens = NsColors.of(context);

    return Row(
      children: [
        const NsLogo(size: 32, depth: 0),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'NagarSathi',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16.5,
              height: 1.05,
              fontWeight: FontWeight.w900,
              color: tokens.heading,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const NsSettingsButton(),
        const SizedBox(width: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showAccountSheet,
            customBorder: const CircleBorder(),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.mint,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: Icon(
                Icons.admin_panel_settings_rounded,
                size: 20,
                color: tokens.accentText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConsoleHeader extends StatelessWidget {
  const _ConsoleHeader({
    required this.identifier,
    required this.onOpenOfficers,
  });

  final String identifier;
  final VoidCallback onOpenOfficers;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? tokens.surface : AppColors.forest,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.forestSoft, width: 2),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : AppColors.forest.withValues(alpha: 0.28),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            bottom: -26,
            child: IgnorePointer(
              child: Opacity(
                opacity: isDark ? 0.22 : 0.18,
                child: const NsMascot(
                  size: 132,
                  mood: NsMascotMood.curious,
                  look: Offset(-0.5, 0.2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.55),
                      width: 1.4,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        size: 12,
                        color: isDark
                            ? tokens.accentText
                            : AppColors.primaryLight,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        strings.superAdminBadge,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: isDark
                              ? tokens.accentText
                              : AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 13),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 230),
                  child: Text(
                    strings.superAdminConsole,
                    style: TextStyle(
                      fontSize: 25,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: isDark ? tokens.heading : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 250),
                  child: Text(
                    strings.superAdminSubtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: isDark ? tokens.muted : const Color(0xFFC3D4C8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? tokens.surfaceSoft
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? tokens.border
                          : Colors.white.withValues(alpha: 0.14),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.alternate_email_rounded,
                        size: 16,
                        color: isDark
                            ? tokens.accentText
                            : AppColors.primaryLight,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          identifier,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? tokens.ink : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                NsPressable(
                  onTap: onOpenOfficers,
                  color: isDark ? tokens.mint : AppColors.primary,
                  borderColor: isDark
                      ? AppColors.primary.withValues(alpha: 0.6)
                      : AppColors.primaryLight,
                  shadowColor: isDark
                      ? Colors.black.withValues(alpha: 0.4)
                      : AppColors.primaryDark,
                  depth: 0,
                  radius: 14,
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.manage_accounts_rounded,
                            size: 17,
                            color: isDark ? tokens.accentText : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            strings.wardOfficerManagement,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: isDark ? tokens.accentText : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsoleStat extends StatelessWidget {
  const _ConsoleStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String value;
  final String label;
  final IconData icon;
  final NsChipTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return NsCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      radius: 20,
      depth: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: tokens.accentText),
              const SizedBox(width: 5),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: tokens.heading,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: NsChip(label: label, tone: tone, compact: true),
          ),
        ],
      ),
    );
  }
}

class _ConsoleAction extends StatelessWidget {
  const _ConsoleAction({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return NsCard(
      padding: EdgeInsets.zero,
      radius: 22,
      depth: 5,
      child: NsPressable(
        onTap: onTap,
        color: Colors.transparent,
        borderColor: Colors.transparent,
        shadowColor: Colors.transparent,
        borderWidth: 0,
        depth: 0,
        radius: 20,
        padding: const EdgeInsets.all(14),
        semanticLabel: title,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: tokens.mint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1.4,
                ),
              ),
              child: Icon(icon, size: 23, color: tokens.accentText),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: tokens.heading,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: tokens.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: tokens.accentText,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final OfficerAuditLog entry;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tokens.mint,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            Icons.history_rounded,
            size: 17,
            color: tokens.accentText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${entry.actionType.label} · ${entry.targetOfficerName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: tokens.heading,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.newValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyAudit extends StatelessWidget {
  const _EmptyAudit({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Row(
      children: [
        Icon(
          loading ? Icons.hourglass_empty_rounded : Icons.history_rounded,
          size: 18,
          color: tokens.muted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            context.l10n.noAuditEntriesTitle,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: tokens.muted,
            ),
          ),
        ),
      ],
    );
  }
}
