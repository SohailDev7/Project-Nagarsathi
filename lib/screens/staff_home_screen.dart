import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
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
import '../widgets/ns_rotating_line.dart';
import '../widgets/ns_route.dart';
import '../widgets/ns_settings_sheet.dart';
import '../widgets/ns_user_avatar.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'staff_login_screen.dart';

/// Ward staff dashboard: the citizen home's layout and navigation, with ward
/// work instead of citizen reporting.
class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({
    super.key,
    required this.staffIdentifier,
    this.isPhone = false,
    this.showRememberMePrompt = false,
  });

  final String staffIdentifier;
  final bool isPhone;
  final bool showRememberMePrompt;

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  int _tab = 0;

  /// The officer's real ward, e.g. `LMC · Ward 5`, read from their own record.
  String? _wardLabel;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    ProfileService.instance.loadProfile();
    if (widget.showRememberMePrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybePromptRememberMe();
      });
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await const StaffAuthService().loadStaffProfile();
      if (!mounted || profile.wardLabel == null) return;
      setState(() => _wardLabel = profile.wardLabel);
    } catch (_) {
      // Keep the placeholder label when the record cannot be read.
    }
  }

  String _wardText(AppStrings strings) => _wardLabel ?? strings.staffWardLabel;

  Future<void> _maybePromptRememberMe() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final remembered = await showRememberMeNotification(
      context: context,
      isStaff: true,
      staffIdentifier: widget.staffIdentifier,
      isPhone: widget.isPhone,
    );
    if (!mounted || remembered != true) return;

    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await showAppLockOffer(context: context, isStaff: true);
  }

  void _selectTab(int index) {
    if (index == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = index);
  }

  void _comingSoon() {
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.comingSoon),
        duration: const Duration(milliseconds: 1600),
      ),
    );
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

  void _openSettings() {
    Navigator.of(context)
        .push(NsPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  void _openProfile() {
    Navigator.of(context).push(
      NsPageRoute<void>(
        builder: (_) => const ProfileScreen(showWardPreferences: false),
      ),
    );
  }

  Future<void> _showAccountSheet() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: NsColors.of(context).surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _StaffAccountSheet(
        identifier: widget.staffIdentifier,
        isPhone: widget.isPhone,
        onOpenProfile: () {
          Navigator.of(sheetContext).pop();
          _openProfile();
        },
        onOpenSettings: () {
          Navigator.of(sheetContext).pop();
          _openSettings();
        },
        onSignOut: () {
          Navigator.of(sheetContext).pop();
          _signOut();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _StaffNavBar(index: _tab, onSelected: _selectTab),
      body: NsBackground(
        staff: true,
        ambientGlow: true,
        child: SafeArea(
          bottom: false,
          child: NsEntrance(
            child: switch (_tab) {
              1 => _buildReports(context),
              2 => _buildProgress(context),
              3 => _buildProfile(context),
              _ => _buildHome(context),
            },
          ),
        ),
      ),
    );
  }

  Widget _page(List<Widget> children) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    return _page([
      _StaffTopBar(onProfile: _showAccountSheet),
      const SizedBox(height: 26),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.staffWorkspace,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: tokens.heading,
                    letterSpacing: -0.9,
                  ),
                ),
                const SizedBox(height: 5),
                NsRotatingLine(
                  lines: strings.staffTips,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: tokens.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? tokens.mint
                  : const Color(0xFF1E7B4B),
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : AppColors.primaryLight.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
            child: const NsMascot(
              size: 52,
              mood: NsMascotMood.excited,
              look: Offset(0, 0.4),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Align(
        alignment: Alignment.centerLeft,
        child: _WardPill(label: _wardText(strings)),
      ),
      const SizedBox(height: 20),
      _WardHeroCard(onOpenQueue: () => _selectTab(1)),
      const SizedBox(height: 26),
      _SectionTitle(strings.staffWardSnapshot),
      const SizedBox(height: 12),
      const _StatsRow(),
      const SizedBox(height: 26),
      _SectionTitle(strings.quickActions),
      const SizedBox(height: 12),
      _QuickActionRow(
        onReports: () => _selectTab(1),
        onProgress: () => _selectTab(2),
        onQueue: () => _selectTab(1),
        onSettings: _openSettings,
      ),
      const SizedBox(height: 26),
      _SectionTitle(
        strings.aroundYou,
        action: strings.seeAll,
        onAction: () => _selectTab(1),
      ),
      const SizedBox(height: 12),
      _ReportList(onTap: () => _selectTab(1)),
    ]);
  }

  Widget _buildReports(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    return _page([
      const _StaffTopBar(),
      const SizedBox(height: 24),
      _TabHeading(
        title: strings.staffWardReports,
        subtitle: strings.todaysQueue,
        icon: Icons.assignment_rounded,
      ),
      const SizedBox(height: 18),
      _FilterRow(onSelected: (_) => _comingSoon()),
      const SizedBox(height: 16),
      _ReportList(onTap: _comingSoon, showHeaders: true),
      const SizedBox(height: 20),
      NsOutlineButton(
        label: strings.staffUpdateQueue,
        icon: Icons.sync_rounded,
        onPressed: _comingSoon,
      ),
      const SizedBox(height: 10),
      Center(
        child: Text(
          strings.staffClearedBody,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: tokens.muted,
          ),
        ),
      ),
    ]);
  }

  Widget _buildProgress(BuildContext context) {
    final strings = context.l10n;

    return _page([
      const _StaffTopBar(),
      const SizedBox(height: 24),
      _TabHeading(
        title: strings.staffProgress,
        subtitle: strings.staffWardSnapshot,
        icon: Icons.trending_up_rounded,
      ),
      const SizedBox(height: 18),
      const _StatsRow(),
      const SizedBox(height: 18),
      const _ProgressCard(),
      const SizedBox(height: 18),
      _SectionTitle(strings.staffWardSnapshot),
      const SizedBox(height: 12),
      _ReportList(onTap: _comingSoon),
    ]);
  }

  Widget _buildProfile(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    return _page([
      const _StaffTopBar(),
      const SizedBox(height: 24),
      Text(
        strings.staffProfileTitle,
        style: TextStyle(
          fontSize: 26,
          height: 1.1,
          fontWeight: FontWeight.w900,
          color: tokens.heading,
          letterSpacing: -0.9,
        ),
      ),
      const SizedBox(height: 16),
      _WardHeroCard(onOpenQueue: () => _selectTab(1)),
      const SizedBox(height: 18),
      NsCard(
        padding: const EdgeInsets.all(16),
        radius: 22,
        depth: 4,
        child: Column(
          children: [
            _ProfileRow(
              icon: Icons.badge_rounded,
              label: strings.staffAccessLevel,
              value: strings.staffBadge,
            ),
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1.2, color: tokens.hairline),
            const SizedBox(height: 12),
            _ProfileRow(
              icon: Icons.location_on_rounded,
              label: strings.staffAssignedWard,
              value: _wardText(strings),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1.2, color: tokens.hairline),
            const SizedBox(height: 12),
            _ProfileRow(
              icon: widget.isPhone
                  ? Icons.phone_android_rounded
                  : Icons.alternate_email_rounded,
              label: strings.staffSignedInLabel,
              value: widget.staffIdentifier,
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      NsOutlineButton(
        key: const Key('staff-open-settings'),
        label: strings.settings,
        icon: Icons.tune_rounded,
        onPressed: _openSettings,
      ),
      const SizedBox(height: 12),
      NsOutlineButton(
        label: strings.signOutOfStaff,
        icon: Icons.logout_rounded,
        tone: NsOutlineTone.danger,
        onPressed: _signOut,
      ),
    ]);
  }
}

class _StaffTopBar extends StatelessWidget {
  const _StaffTopBar({this.onProfile});

  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
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
        _StaffAvatarButton(onTap: onProfile ?? () {}),
      ],
    );
  }
}

class _StaffAvatarButton extends StatelessWidget {
  const _StaffAvatarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<UserProfile?>(
      valueListenable: ProfileService.instance.notifier,
      builder: (context, profile, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: profile?.hasCustomAvatar == true
                ? NsUserAvatar(profile: profile, size: 40)
                : Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? tokens.mint : AppColors.forest,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.primary
                            : AppColors.primaryLight,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.badge_rounded,
                      size: 19,
                      color: isDark ? tokens.accentText : Colors.white,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _WardPill extends StatelessWidget {
  const _WardPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(7, 6, 12, 6),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: tokens.border.withValues(alpha: 0.85),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: tokens.mint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_rounded,
              size: 13.5,
              color: tokens.accentText,
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: tokens.heading,
              ),
            ),
          ),
          const SizedBox(width: 4),
          NsChip(label: context.l10n.staffBadgeShort, compact: true),
        ],
      ),
    );
  }
}

class _WardHeroCard extends StatelessWidget {
  const _WardHeroCard({required this.onOpenQueue});

  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const actionFill = Color(0xFF163B2B);
    final actionInk = isDark ? tokens.accentBright : const Color(0xFFA5F542);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6AD90E), AppColors.primary, Color(0xFF4BB800)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark
              ? AppColors.primaryLight.withValues(alpha: 0.35)
              : AppColors.primaryDark.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.42)
                : AppColors.primary.withValues(alpha: 0.28),
            offset: const Offset(0, 10),
            blurRadius: 22,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.engineering_rounded,
                    size: 13,
                    color: AppColors.forest,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    strings.staffSignedInLabel,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.forest,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            Text(
              strings.staffWelcomeTitle,
              style: const TextStyle(
                fontSize: 22.5,
                height: 1.12,
                fontWeight: FontWeight.w900,
                color: AppColors.forest,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              strings.staffClearedBody,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: AppColors.forest.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 16),
            NsPressable(
              onTap: onOpenQueue,
              color: actionFill,
              borderColor: isDark
                  ? tokens.border
                  : Colors.white.withValues(alpha: 0.6),
              shadowColor: isDark
                  ? Colors.black.withValues(alpha: 0.45)
                  : AppColors.forest.withValues(alpha: 0.16),
              radius: 15,
              depth: 0,
              child: SizedBox(
                height: 46,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.assignment_rounded,
                        size: 17,
                        color: actionInk,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          strings.staffUpdateQueue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: actionInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                        color: actionInk,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabHeading extends StatelessWidget {
  const _TabHeading({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Row(
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
                  fontSize: 23,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: tokens.heading,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label, {this.action, this.onAction});

  final String label;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: tokens.heading,
              letterSpacing: -0.4,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              action!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: tokens.accentText,
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterRow extends StatefulWidget {
  const _FilterRow({required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  State<_FilterRow> createState() => _FilterRowState();
}

class _FilterRowState extends State<_FilterRow> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final labels = [
      strings.allStatuses,
      strings.statusNew,
      strings.statusInProgress,
      strings.statResolved,
    ];

    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: _FilterPill(
              label: labels[index],
              selected: _selected == index,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selected = index);
                widget.onSelected(index);
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? tokens.mint : tokens.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : tokens.border,
              width: 1.4,
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  color: selected ? tokens.accentText : tokens.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    required this.onReports,
    required this.onProgress,
    required this.onQueue,
    required this.onSettings,
  });

  final VoidCallback onReports;
  final VoidCallback onProgress;
  final VoidCallback onQueue;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final actions = [
      (
        Icons.assignment_rounded,
        strings.staffWardReports,
        AppColors.primary,
        onReports,
      ),
      (
        Icons.trending_up_rounded,
        strings.staffProgress,
        AppColors.sun,
        onProgress,
      ),
      (Icons.schedule_rounded, strings.todaysQueue, AppColors.sky, onQueue),
      (Icons.tune_rounded, strings.settings, AppColors.sky, onSettings),
    ];

    return Row(
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(width: 9),
          Expanded(
            child: _QuickActionTile(
              key: index == 3
                  ? const Key('staff-open-settings')
                  : ValueKey<int>(index),
              icon: actions[index].$1,
              label: actions[index].$2,
              tint: actions[index].$3,
              onTap: actions[index].$4,
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              tint.withValues(alpha: isDark ? 0.12 : 0.28),
              tokens.surface,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: tint.withValues(alpha: isDark ? 0.42 : 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.045),
                offset: const Offset(0, 5),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: isDark ? 0.30 : 0.24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 19.5,
                  color: isDark ? tokens.heading : AppColors.forest,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: tokens.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '12',
            label: strings.statOpen,
            tone: NsChipTone.sun,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '8',
            label: strings.statResolved,
            tone: NsChipTone.green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '2.4h',
            label: strings.statAvgTime,
            tone: NsChipTone.sky,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.tone,
  });

  final String value;
  final String label;
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 26,
                height: 1,
                fontWeight: FontWeight.w900,
                color: tokens.heading,
                letterSpacing: -0.8,
              ),
            ),
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    final rows = <(String, double, Color)>[
      (strings.statResolved, 0.68, AppColors.primary),
      (strings.statusInProgress, 0.24, AppColors.sky),
      (strings.statOpen, 0.08, AppColors.sun),
    ];

    return NsCard(
      padding: const EdgeInsets.all(18),
      radius: 24,
      depth: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.staffProgress,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: tokens.heading,
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    rows[index].$1,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: tokens.ink,
                    ),
                  ),
                ),
                Text(
                  '${(rows[index].$2 * 100).round()}%',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: tokens.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: rows[index].$2,
                minHeight: 9,
                backgroundColor: tokens.surfaceSoft,
                valueColor: AlwaysStoppedAnimation<Color>(rows[index].$3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: tokens.accentText),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tokens.muted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: tokens.heading,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({required this.onTap, this.showHeaders = false});

  final VoidCallback onTap;
  final bool showHeaders;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final reports = [
      (
        Icons.construction_rounded,
        strings.queueRoadRepair,
        strings.queueRoadRepairMeta,
        strings.statusPriority,
        NsChipTone.sun,
      ),
      (
        Icons.lightbulb_outline_rounded,
        strings.queueStreetlight,
        strings.queueStreetlightMeta,
        strings.statusNew,
        NsChipTone.sky,
      ),
      (
        Icons.delete_outline_rounded,
        strings.queueWaste,
        strings.queueWasteMeta,
        strings.statusOpen,
        NsChipTone.green,
      ),
    ];

    return Column(
      children: [
        for (var index = 0; index < reports.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          _ReportRow(
            icon: reports[index].$1,
            title: reports[index].$2,
            subtitle: reports[index].$3,
            status: reports[index].$4,
            tone: reports[index].$5,
            onTap: onTap,
          ),
        ],
        if (showHeaders) ...[
          const SizedBox(height: 10),
          _ReportRow(
            icon: Icons.water_drop_outlined,
            title: strings.categoryWaterHero,
            subtitle: strings.queueWasteMeta,
            status: strings.statusInProgress,
            tone: NsChipTone.sky,
            onTap: onTap,
          ),
        ],
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final NsChipTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: tokens.border.withValues(alpha: 0.85),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.045),
                offset: const Offset(0, 5),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tokens.mint,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 20, color: tokens.accentText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: tokens.heading,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
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
              const SizedBox(width: 8),
              NsChip(label: status, tone: tone, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffNavBar extends StatelessWidget {
  const _StaffNavBar({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: tokens.border.withValues(alpha: 0.85),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.48 : 0.08),
                offset: const Offset(0, 8),
                blurRadius: 22,
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: strings.navHome,
                active: index == 0,
                onTap: () => onSelected(0),
              ),
              _NavItem(
                icon: Icons.assignment_outlined,
                activeIcon: Icons.assignment_rounded,
                label: strings.navReports,
                active: index == 1,
                onTap: () => onSelected(1),
              ),
              _NavItem(
                icon: Icons.trending_up_rounded,
                activeIcon: Icons.show_chart_rounded,
                label: strings.navProgress,
                active: index == 2,
                onTap: () => onSelected(2),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: strings.navProfile,
                active: index == 3,
                onTap: () => onSelected(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeIcon,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = active ? tokens.accentText : tokens.muted;

    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: active ? tokens.mint : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: active
                            ? AppColors.primary.withValues(
                                alpha: isDark ? 0.65 : 0.4,
                              )
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      active ? (activeIcon ?? icon) : icon,
                      size: 21,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                      color: color,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffAccountSheet extends StatelessWidget {
  const _StaffAccountSheet({
    required this.identifier,
    required this.isPhone,
    required this.onOpenProfile,
    required this.onOpenSettings,
    required this.onSignOut,
  });

  final String identifier;
  final bool isPhone;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
    final profile = ProfileService.instance.notifier.value;
    final displayTitle =
        (profile?.displayName.trim().isNotEmpty == true)
            ? profile!.displayName.trim()
            : strings.staffWorkspace;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                profile?.hasCustomAvatar == true
                    ? NsUserAvatar(profile: profile, size: 50)
                    : Container(
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tokens.mint,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: Icon(
                          isPhone
                              ? Icons.phone_android_rounded
                              : Icons.badge_rounded,
                          size: 23,
                          color: tokens.accentText,
                        ),
                      ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
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
                        identifier,
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
                NsChip(label: strings.staffBadge, compact: true),
              ],
            ),
            const SizedBox(height: 18),
            NsOutlineButton(
              label: 'Edit profile',
              icon: Icons.person_outline_rounded,
              onPressed: onOpenProfile,
            ),
            const SizedBox(height: 12),
            NsOutlineButton(
              label: strings.settings,
              icon: Icons.tune_rounded,
              onPressed: onOpenSettings,
            ),
            const SizedBox(height: 12),
            NsOutlineButton(
              label: strings.signOutOfStaff,
              icon: Icons.logout_rounded,
              tone: NsOutlineTone.danger,
              onPressed: onSignOut,
            ),
          ],
        ),
      ),
    );
  }
}
